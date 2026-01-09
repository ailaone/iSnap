import AppKit
import SwiftUI

// Window Controller for the selection overlay
class SelectionOverlayWindowController: NSWindowController {
    
    // Callback when a selection is made
    var onSelectionComplete: ((CGRect, CGImage?) -> Void)?
    
    // The view handling the drawing of the selection rect
    private var selectionView: SelectionView?

    convenience init() {
        // Create a borderless, transparent window covering the entire screen
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let window = iSnapWindow( /// Use iSnapWindow to capture Esc
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.level = .screenSaver // Very high level
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true // V1.5: Ensure we get mouse moved events for cursor update
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.init(window: window)
        
        window.onEsc = { [weak self] in
            self?.cancelSelection()
        }
        
        selectionView = SelectionView(frame: screen.frame)
        selectionView?.delegate = self
        window.contentView = selectionView
    }
    
    func selectionView(_ view: SelectionView, didSelectRect rect: CGRect, withImage image: CGImage?) {
        window?.orderOut(nil)
        onSelectionComplete?(rect, image)
    }
    
    func cancelSelection() {
        window?.orderOut(nil)
        onSelectionComplete?(CGRect.zero, nil) // Return nil signal to reset state
    }
    
    func startSelection() {
        // Update frame to match current screen just in case
        if let screen = NSScreen.main {
            window?.setFrame(screen.frame, display: true)
            selectionView?.frame = screen.frame
        }
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.invalidateCursorRects(for: selectionView!)
    }
    
    func endSelection() {
        NSCursor.pop()
        window?.orderOut(nil)
    }
}

protocol SelectionViewDelegate: AnyObject {
    func didSelectRect(_ rect: CGRect)
}

extension SelectionOverlayWindowController: SelectionViewDelegate {
    func didSelectRect(_ rect: CGRect) {
        endSelection()
        
        // Convert window coordinates to screen coordinates if needed
        // The window matches the screen frame, so window coords ~= screen coords (with y-flip processing if using CG)
        
        // Cocoa (AppKit) uses bottom-left origin. Quartz (CG) uses top-left origin usually, but CGWindowListCreateImage expects CGRect in generic coordinates.
        // Usually need to flip Y for CGWindowListCreateImage derived from NSEvent locations?
        // Actually, NSScreen coords are global (x,y) from bottom-left of primary screen.
        // We pass the rect in screen coordinates.
        
        // Capture! Using Async method to support ScreenCaptureKit
        ScreenCaptureManager.shared.captureRegion(rect) { [weak self] image in
            self?.onSelectionComplete?(rect, image)
        }
    }
}

class SelectionView: NSView {
    weak var delegate: SelectionViewDelegate?
    
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var dragLayer: CALayer = CALayer()
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        
        dragLayer.borderWidth = 1
        dragLayer.borderColor = NSColor.systemGray.cgColor
        dragLayer.backgroundColor = NSColor.systemGray.withAlphaComponent(0.2).cgColor
        layer?.addSublayer(dragLayer)
        dragLayer.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // V2.0: Custom Larger Crosshair Cursor
    private lazy var customCursor: NSCursor = {
        let size = NSSize(width: 24, height: 24) // Approx 25% larger than standard (16-18pt)
        let image = NSImage(size: size)
        image.lockFocus()
        
        let path = NSBezierPath()
        path.lineWidth = 2.0 // Slightly thicker for larger size
        
        // Vertical line
        path.move(to: CGPoint(x: 12, y: 4))
        path.line(to: CGPoint(x: 12, y: 20))
        
        // Horizontal line
        path.move(to: CGPoint(x: 4, y: 12))
        path.line(to: CGPoint(x: 20, y: 12))
        
        // Draw white with black shadow/outline for visibility
        // Outline
        NSColor.black.setStroke()
        path.lineWidth = 3.0
        path.stroke()
        
        // White Inner
        NSColor.white.setStroke()
        path.lineWidth = 1.5
        path.stroke()
        
        image.unlockFocus()
        
        return NSCursor(image: image, hotSpot: NSPoint(x: 12, y: 12))
    }()
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Ensure tracking area is properly setup for cursor updates
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: customCursor)
    }
    
    // V1.5: Force cursor update
    override func cursorUpdate(with event: NSEvent) {
        customCursor.set()
    }
    
    // Explicitly set cursor on mouse moved to handle race conditions
    override func mouseMoved(with event: NSEvent) {
        customCursor.set()
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        currentPoint = startPoint
        updateLayerFrame()
        dragLayer.isHidden = false
    }
    
    override func mouseDragged(with event: NSEvent) {
        currentPoint = event.locationInWindow
        updateLayerFrame()
    }
    
    override func mouseUp(with event: NSEvent) {
        dragLayer.isHidden = true
        
        guard let start = startPoint, let end = currentPoint else { return }
        
        // Normalize rect
        let x = min(start.x, end.x)
        let y = min(start.y, end.y)
        let w = abs(start.x - end.x)
        let h = abs(start.y - end.y)
        
        // Convert to Screen Coordinates
        // This view covers the screen, so event.locationInWindow IS the screen coordinate relative to THIS screen's origin (if window is at 0,0 of screen).
        // However, if we are on a secondary monitor, we need to account for the window's frame origin in global space.
        
        if let windowFrame = window?.frame {
            let globalRect = CGRect(
                x: windowFrame.minX + x,
                y: windowFrame.minY + y,
                width: w,
                height: h
            )
            
            // To be safe, we should use CGWindowListCreateImage with the rect.
            // But we need to flip the Y coordinate because AppKit (bottom-left) -> CoreGraphics (top-left).
            // Main screen height is needed to flip.
            
            let primaryScreenHeight = NSScreen.screens[0].frame.height
            let flippedY = primaryScreenHeight - (globalRect.origin.y + globalRect.height)
            
            let cgRect = CGRect(x: globalRect.origin.x, y: flippedY, width: globalRect.width, height: globalRect.height)
            
            // Hide the overlay window BEFORE capturing to prevent it from being included in the screenshot
            self.window?.orderOut(nil)
            
            // Ensure the window is fully removed from screen before capturing
            // Use a small delay to let the window removal complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.delegate?.didSelectRect(cgRect)
            }
        }
    }
    
    private func updateLayerFrame() {
        guard let start = startPoint, let current = currentPoint else { return }
        let x = min(start.x, current.x)
        let y = min(start.y, current.y) // In view coords (bottom-left based usually in AppKit, but let's check isFlipped)
        let w = abs(start.x - current.x)
        let h = abs(start.y - current.y)
        
        // CATransaction to disable implicit animation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dragLayer.frame = CGRect(x: x, y: y, width: w, height: h)
        CATransaction.commit()
    }
    
    override var isFlipped: Bool {
        return false // Standard AppKit coordinate system (0,0 at bottom-left)
    }
}

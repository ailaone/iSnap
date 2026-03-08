import AppKit
import SwiftUI

// Window Controller for the selection overlay
class SelectionOverlayWindowController: NSWindowController {
    
    // Callback when a selection is made
    var onSelectionComplete: ((CGRect, CGImage?) -> Void)?
    
    // The view handling the drawing of the selection rect
    private var selectionView: SelectionView?
    private let targetScreen: NSScreen
    private let frozenImage: CGImage

    init(screen: NSScreen, frozenImage: CGImage) {
        self.targetScreen = screen
        self.frozenImage = frozenImage

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
        window.animationBehavior = .none
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true // V1.5: Ensure we get mouse moved events for cursor update
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        
        super.init(window: window)
        
        window.onEsc = { [weak self] in
            self?.cancelSelection()
        }
        
        selectionView = SelectionView(frame: screen.frame, frozenImage: frozenImage)
        selectionView?.delegate = self
        window.contentView = selectionView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func selectionView(_ view: SelectionView, didSelectRect rect: CGRect, withImage image: CGImage?) {
        window?.orderOut(nil)
        onSelectionComplete?(rect, image)
    }
    
    func cancelSelection() {
        selectionView?.endSelection()
        window?.orderOut(nil)
        onSelectionComplete?(CGRect.zero, nil) // Return nil signal to reset state
    }
    
    func startSelection() {
        // Update frame to match current screen just in case
        window?.setFrame(targetScreen.frame, display: true)
        selectionView?.frame = targetScreen.frame

        selectionView?.prepareForSelection()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
        window?.invalidateCursorRects(for: selectionView!)
        DispatchQueue.main.async { [weak self] in
            self?.selectionView?.applyInitialCursor()
        }
    }
    
    func endSelection() {
        selectionView?.endSelection()
        window?.orderOut(nil)
    }
}

protocol SelectionViewDelegate: AnyObject {
    func didSelectRect(_ rect: CGRect)
}

extension SelectionOverlayWindowController: SelectionViewDelegate {
    func didSelectRect(_ rect: CGRect) {
        endSelection()

        let croppedImage = cropFrozenImage(to: rect)
        onSelectionComplete?(rect, croppedImage)
    }

    private func cropFrozenImage(to cgRect: CGRect) -> CGImage? {
        let primaryScreenHeight = NSScreen.screens[0].frame.height
        let screenFrame = targetScreen.frame
        let screenCGFrame = CGRect(
            x: screenFrame.origin.x,
            y: primaryScreenHeight - (screenFrame.origin.y + screenFrame.height),
            width: screenFrame.width,
            height: screenFrame.height
        )

        let localRect = CGRect(
            x: cgRect.origin.x - screenCGFrame.origin.x,
            y: cgRect.origin.y - screenCGFrame.origin.y,
            width: cgRect.width,
            height: cgRect.height
        )

        let scaleX = CGFloat(frozenImage.width) / targetScreen.frame.width
        let scaleY = CGFloat(frozenImage.height) / targetScreen.frame.height

        let cropRect = CGRect(
            x: localRect.origin.x * scaleX,
            y: localRect.origin.y * scaleY,
            width: localRect.width * scaleX,
            height: localRect.height * scaleY
        ).integral

        return frozenImage.cropping(to: cropRect)
    }
}

class SelectionView: NSView {
    weak var delegate: SelectionViewDelegate?
    
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var dragLayer: CALayer = CALayer()
    private let frozenImage: CGImage
    
    init(frame: NSRect, frozenImage: CGImage) {
        self.frozenImage = frozenImage
        super.init(frame: frame)
        wantsLayer = true
        _ = customCursor

        dragLayer.borderWidth = 1
        dragLayer.borderColor = NSColor.systemGray.cgColor
        dragLayer.backgroundColor = NSColor.systemGray.withAlphaComponent(0.2).cgColor
        layer?.addSublayer(dragLayer)
        dragLayer.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    private lazy var customCursor: NSCursor = {
        let size = NSSize(width: 22, height: 22)
        let center = CGFloat(11)
        let lineInset = CGFloat(2)
        let image = NSImage(size: size)

        image.lockFocus()

        let outlinePath = NSBezierPath()
        outlinePath.lineCapStyle = .round
        outlinePath.lineWidth = 2.5
        outlinePath.move(to: CGPoint(x: center, y: lineInset))
        outlinePath.line(to: CGPoint(x: center, y: size.height - lineInset))
        outlinePath.move(to: CGPoint(x: lineInset, y: center))
        outlinePath.line(to: CGPoint(x: size.width - lineInset, y: center))
        NSColor.black.setStroke()
        outlinePath.stroke()

        let innerPath = NSBezierPath()
        innerPath.lineCapStyle = .round
        innerPath.lineWidth = 1.25
        innerPath.move(to: CGPoint(x: center, y: lineInset))
        innerPath.line(to: CGPoint(x: center, y: size.height - lineInset))
        innerPath.move(to: CGPoint(x: lineInset, y: center))
        innerPath.line(to: CGPoint(x: size.width - lineInset, y: center))
        NSColor.white.setStroke()
        innerPath.stroke()

        image.unlockFocus()
        return NSCursor(image: image, hotSpot: NSPoint(x: center, y: center))
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

    func prepareForSelection() {
        startPoint = nil
        currentPoint = nil
        dragLayer.isHidden = true
        discardCursorRects()
        window?.invalidateCursorRects(for: self)
        customCursor.push()
        customCursor.set()
    }

    func applyInitialCursor() {
        discardCursorRects()
        window?.invalidateCursorRects(for: self)
        customCursor.set()
    }

    func endSelection() {
        NSCursor.pop()
    }
    
    override func mouseMoved(with event: NSEvent) {
        customCursor.set()
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        currentPoint = startPoint
        customCursor.set()
        updateLayerFrame()
        dragLayer.isHidden = false
    }
    
    override func mouseDragged(with event: NSEvent) {
        currentPoint = event.locationInWindow
        customCursor.set()
        updateLayerFrame()
    }
    
    override func mouseUp(with event: NSEvent) {
        customCursor.set()
        dragLayer.isHidden = true
        
        guard let start = startPoint, let end = currentPoint else { return }
        
        // Normalize rect
        let x = min(start.x, end.x)
        let y = min(start.y, end.y)
        let w = abs(start.x - end.x)
        let h = abs(start.y - end.y)
        
        // V2.1: One-click Check
        // If drag is very small (< 5 points), consider it a click.
        let isClick = w < 5 && h < 5
        
        if isClick {
            // Check settings
            if SettingsManager.shared.oneClickFullscreen {
                // Capture entire screen
                if let screenFrame = window?.frame {
                    let fullRect = NSRect(origin: .zero, size: screenFrame.size)
                    processSelection(rect: fullRect, inWindow: screenFrame)
                }
            } else {
                startPoint = nil
                currentPoint = nil
                return
            }
        } else {
            // Normal Selection
             if let windowFrame = window?.frame {
                let selectionRect = CGRect(x: x, y: y, width: w, height: h)
                processSelection(rect: selectionRect, inWindow: windowFrame)
             }
        }
    }
    
    private func processSelection(rect: CGRect, inWindow windowFrame: CGRect) {
            let globalRect = CGRect(
                x: windowFrame.minX + rect.minX,
                y: windowFrame.minY + rect.minY,
                width: rect.width,
                height: rect.height
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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.interpolationQuality = .none
        context.draw(frozenImage, in: bounds)
    }
    
    override var isFlipped: Bool {
        return false // Standard AppKit coordinate system (0,0 at bottom-left)
    }
}

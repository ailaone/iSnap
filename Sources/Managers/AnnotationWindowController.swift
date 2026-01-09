import AppKit
import SwiftUI

class AnnotationWindowController: NSWindowController {
    
    convenience init(image: CGImage) {
        let screen = NSScreen.main
        let scale = screen?.backingScaleFactor ?? 2.0
        
        // V7.3: Account for View Padding (Horizontal: 10, Vertical: 95)
        // This ensures the window opens large enough for the image at 1.0 scale + Toolbar.
        let imageWidthPoints = CGFloat(image.width) / scale
        let imageHeightPoints = CGFloat(image.height) / scale
        
        let windowWidthPoints = imageWidthPoints + 10
        let windowHeightPoints = imageHeightPoints + 95
        
        // V12: SCK already provides sRGB images. No further conversion needed.
        // Simply wrap the CGImage with the correct point size (content size, NOT window size).
        let finalImage = NSImage(cgImage: image, size: NSSize(width: imageWidthPoints, height: imageHeightPoints))
        
        // Create the window
        let window = iSnapWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidthPoints, height: windowHeightPoints),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        
        // Window setup
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        
        // Match window to sRGB
        window.colorSpace = .sRGB
        
        window.center()
        
        // V7.2: Lower min size to allow fitting small screenshots without upscaling.
        // Toolbar width (approx 450) is the limiting factor.
        window.minSize = NSSize(width: 450, height: 300)
        
        self.init(window: window)
        
        let contentView = AnnotationView(image: finalImage, window: window)
        window.contentView = NSHostingView(rootView: contentView)
        
        window.onEsc = { [weak window] in
            NotificationCenter.default.post(name: Notification.Name("iSnapEscPressed"), object: window)
        }
    }
}

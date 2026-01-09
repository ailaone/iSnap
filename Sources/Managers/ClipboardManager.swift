import AppKit

class ClipboardManager {
    static let shared = ClipboardManager()
    
    func copyToClipboard(_ image: CGImage) {
        let nsImage = NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
        copyToClipboard(nsImage)
    }
    
    func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
}

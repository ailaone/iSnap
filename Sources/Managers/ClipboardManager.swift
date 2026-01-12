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
        
        // V18: Force PNG Format
        // Convert NSImage to PNG Data
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            // Fallback if conversion fails
             pasteboard.writeObjects([image])
             return
        }
        
        // Write PNG data directly
        pasteboard.setData(pngData, forType: .png)
    }
}

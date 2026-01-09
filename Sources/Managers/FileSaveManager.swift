import Foundation
import AppKit

class FileSaveManager {
    static let shared = FileSaveManager()
    
    // Default folder: ~/Pictures/iSnap/
    private var defaultSaveURL: URL {
        let savedPath = UserDefaults.standard.string(forKey: "saveLocation")
        if let savedPath = savedPath, !savedPath.isEmpty {
            let url = URL(fileURLWithPath: savedPath)
            // Create if needed
             if !FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
            return url
        }
        
        // Fallback
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let saveDir = pictures.appendingPathComponent("iSnap", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: saveDir.path) {
            try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        }
        
        return saveDir
    }
    
    func saveBaseScreenshot(_ image: CGImage) -> URL? {
        let filename = "Screenshot_\(dateString()).png"
        let url = defaultSaveURL.appendingPathComponent(filename)
        return saveAppleStyle(image, to: url)
    }
    
    func saveAnnotatedScreenshot(_ image: NSImage) -> URL? {
        let filename = "Screenshot_\(dateString())_annotated.png"
        let url = defaultSaveURL.appendingPathComponent(filename)
        
        // Convert NSImage to CGImage to use our ImageIO pipeline
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            return nil
        }
        
        return saveAppleStyle(cgImage, to: url)
    }
    
    func saveImage(_ image: CGImage, to url: URL, scale: CGFloat = 2.0) -> Bool {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        
        // V14: Fix DPI.
        // CGImage is pure pixels. NSBitmapImageRep defaults to 72 DPI (Scale 1.0).
        // To indicate 144 DPI (Scale 2.0), we must set the .size property (logical size)
        // to be half the pixel dimensions.
        // Logical Size = Pixel Size / Scale
        bitmapRep.size = NSSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("❌ Failed to create PNG data")
            return false
        }
        
        do {
            try pngData.write(to: url)
            print("✅ Saved PNG: \(url.lastPathComponent) @ Scale \(scale)")
            return true
        } catch {
            print("❌ Failed to write file: \(error)")
            return false
        }
    }
    
    // V12: SCK provides sRGB images. Just save directly.
    private func saveAppleStyle(_ image: CGImage, to url: URL) -> URL? {
        if saveImage(image, to: url) {
            return url
        }
        return nil
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
}

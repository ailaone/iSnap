import Cocoa

guard CommandLine.arguments.count == 4 else {
    print("Usage: render_svg <input.svg> <output.png> <size>")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
guard let size = Double(CommandLine.arguments[3]) else {
    print("Invalid size")
    exit(1)
}

let inputURL = URL(fileURLWithPath: inputPath)
let outputURL = URL(fileURLWithPath: outputPath)

// Check if file exists
guard FileManager.default.fileExists(atPath: inputPath) else {
    print("Input file not found")
    exit(1)
}

// Load SVG as NSImage
guard let image = NSImage(contentsOf: inputURL) else {
    print("Failed to load SVG")
    exit(1)
}

// Create destination rect
let targetSize = NSSize(width: size, height: size)
let rect = NSRect(origin: .zero, size: targetSize)

// Create a transparent bitmap context
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: NSColorSpaceName.deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    print("Failed to create bitmap rep")
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
let context = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current = context

// Clear main context (optional, but good practice)
NSColor.clear.set()
rect.fill()

// Draw SVG
image.draw(in: rect)

NSGraphicsContext.restoreGraphicsState()

// Save to PNG
if let data = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
    do {
        try data.write(to: outputURL)
        print("Successfully converted to \(outputPath)")
    } catch {
        print("Failed to write PNG: \(error)")
        exit(1)
    }
} else {
    print("Failed to create PNG data")
    exit(1)
}

import Foundation
import ScreenCaptureKit
import CoreGraphics
import AppKit

class ScreenCaptureManager: NSObject, @unchecked Sendable {
    static let shared = ScreenCaptureManager()

    // Legacy synchronous capture (fallback for macOS < 14)
    func captureRegionSync(_ rect: CGRect) -> CGImage? {
        return CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )
    }

    // Primary capture method. Uses ScreenCaptureKit on macOS 14+.
    func captureRegion(_ rect: CGRect, completion: @escaping (CGImage?) -> Void) {
        if #available(macOS 14.0, *) {
            Task {
                do {
                    let image = try await captureWithSCK(rect: rect)
                    print("iSnap: SCK capture succeeded")
                    DispatchQueue.main.async {
                        completion(image)
                    }
                } catch {
                    print("iSnap: SCK capture failed: \(error)")
                    // Fallback to legacy API
                    let fallback = self.captureRegionSync(rect)
                    print("iSnap: CGWindowListCreateImage fallback returned \(fallback != nil ? "image" : "nil")")
                    DispatchQueue.main.async {
                        completion(fallback)
                    }
                }
            }
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                let image = self.captureRegionSync(rect)
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
    }

    @available(macOS 14.0, *)
    private func captureWithSCK(rect: CGRect) async throws -> CGImage {
        print("iSnap: SCK requesting shareable content...")
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        print("iSnap: SCK got \(content.displays.count) displays, \(content.windows.count) windows")

        guard let display = content.displays.first(where: { $0.frame.intersects(rect) }) else {
            // If no display intersects, try the main display
            guard let display = content.displays.first else {
                throw NSError(domain: "ScreenCaptureManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No displays found"])
            }
            print("iSnap: No display intersects rect \(rect), using main display \(display.frame)")
            return try await performSCKCapture(display: display, rect: rect, content: content)
        }

        print("iSnap: Using display \(display.frame) for rect \(rect)")
        return try await performSCKCapture(display: display, rect: rect, content: content)
    }

    @available(macOS 14.0, *)
    private func performSCKCapture(display: SCDisplay, rect: CGRect, content: SCShareableContent) async throws -> CGImage {
        // Convert global CG rect to display-local coordinates
        let localRect = CGRect(
            x: rect.origin.x - display.frame.origin.x,
            y: rect.origin.y - display.frame.origin.y,
            width: rect.width,
            height: rect.height
        )

        // Exclude iSnap's own windows from capture
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let currentApp = content.applications.first { $0.processID == currentPID }

        let filter: SCContentFilter
        if let app = currentApp {
            filter = SCContentFilter(display: display, excludingApplications: [app], exceptingWindows: [])
        } else {
            filter = SCContentFilter(display: display, excludingWindows: [])
        }

        let scaleFactor = filter.pointPixelScale
        print("iSnap: SCK localRect=\(localRect), scale=\(scaleFactor)")

        let config = SCStreamConfiguration()
        config.sourceRect = localRect
        config.width = Int(localRect.width * CGFloat(scaleFactor))
        config.height = Int(localRect.height * CGFloat(scaleFactor))
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return image
    }
}

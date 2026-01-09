import Foundation
import ScreenCaptureKit
import CoreGraphics
import AppKit

class ScreenCaptureManager: NSObject, @unchecked Sendable {
    static let shared = ScreenCaptureManager()
    
    // Check for screen recording permission
    func hasScreenRecordingPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }
    
    // Request permission (this usually just triggers the prompt if not already given)
    func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }
    
    // Legacy synchronous capture (kept for fallback)
    func captureRegionSync(_ rect: CGRect) -> CGImage? {
        return CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )
    }
    
    // Async capture using ScreenCaptureKit (macOS 14+) for proper color handling
    // The rect passed here is expected to be in CG coordinates (top-left origin, global)
    func captureRegion(_ rect: CGRect, completion: @escaping (CGImage?) -> Void) {
        if #available(macOS 14.0, *) {
            Task {
                do {
                    let image = try await captureWithSCK(rect: rect)
                    DispatchQueue.main.async {
                        completion(image)
                    }
                } catch {
                    print("SCK capture failed: \(error). Falling back to CGWindowListCreateImage.")
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        completion(self.captureRegionSync(rect))
                    }
                }
            }
        } else {
            // Fallback for older macOS
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
        let content = try await SCShareableContent.current
        
        // Find the screen containing the rect (in CG coords, so we need to find by checking display frame)
        // CG coords have origin at top-left of primary display. SCDisplay.frame should also be in similar space.
        guard let display = content.displays.first(where: { $0.frame.intersects(rect) }) else {
            throw NSError(domain: "ScreenCaptureManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display found for rect"])
        }
        
        // Convert global CG rect to display-local coordinates
        // SCK sourceRect is relative to the display's origin
        let localRect = CGRect(
            x: rect.origin.x - display.frame.origin.x,
            y: rect.origin.y - display.frame.origin.y,
            width: rect.width,
            height: rect.height
        )
        
        // Find our app to exclude from capture
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let currentApp = content.applications.first { $0.processID == currentPID }
        
        let filter: SCContentFilter
        if let app = currentApp {
            filter = SCContentFilter(display: display, excludingApplications: [app], exceptingWindows: [])
        } else {
            filter = SCContentFilter(display: display, excludingWindows: [])
        }
        
        // Get proper scale factor
        let scaleFactor = filter.pointPixelScale
        
        let config = SCStreamConfiguration()
        config.sourceRect = localRect
        config.width = Int(localRect.width * CGFloat(scaleFactor))
        config.height = Int(localRect.height * CGFloat(scaleFactor))
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false
        
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return image
    }
    
    // Helper to get screen containing the mouse or a specific point
    func screen(containing point: CGPoint) -> NSScreen? {
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }
}


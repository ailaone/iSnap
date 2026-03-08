import Foundation
import AppKit
import SwiftUI

class CaptureFlowManager: ObservableObject {
    static let shared = CaptureFlowManager()
    
    private var selectionController: SelectionOverlayWindowController?
    private var annotationController: AnnotationWindowController?
    private var previouslyFrontmostApp: NSRunningApplication?
    
    private var isCapturing = false
    
    func startCapture() {
        guard !isCapturing else {
            print("Already capturing")
            return
        }
        
        // 1. Check permissions first
        if !ScreenCaptureManager.shared.hasScreenRecordingPermission() {
            ScreenCaptureManager.shared.requestScreenRecordingPermission()
            
            // Show Alert
            // V12.3: Remove custom alert to avoid double-prompting (System Prompt + App Alert).
            // Users will see the System Prompt. If they deny, future attempts will fail silently or we can handle that separately.
            /*
             DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Screen Recording Permission Required"
                alert.informativeText = "Please enable Screen Recording permissions for iSnap in System Settings > Privacy & Security."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    // Open URL
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            */
            return
        }

        previouslyFrontmostApp = NSWorkspace.shared.frontmostApplication
        
        guard let screen = currentCaptureScreen(),
              let frozenImage = ScreenCaptureManager.shared.captureDisplaySync(screen) else {
            print("Failed to capture frozen screen snapshot")
            return
        }

        // 2. Start selection over the frozen snapshot.
        isCapturing = true
        selectionController = SelectionOverlayWindowController(screen: screen, frozenImage: frozenImage)
        selectionController?.onSelectionComplete = { [weak self] rect, image in
            self?.isCapturing = false
            guard let self = self else { return }
            guard let image = image else {
                self.restorePreviouslyFrontmostAppIfNeeded()
                return
            }
            
            // V1.3: Immediate Save & Clipboard
            _ = FileSaveManager.shared.saveBaseScreenshot(image)
            ClipboardManager.shared.copyToClipboard(image)
            
            self.startAnnotation(with: image)
        }
        selectionController?.startSelection()
    }
    
    func startAnnotation(with image: CGImage) {
        // 3. Auto-save base version (Task for FileSaveManager, to be implemented)
        // FileSaveManager.shared.saveBaseScreenshot(image)
        
        // 4. Auto-copy base version (Task for ClipboardManager)
        // ClipboardManager.shared.copyToClipboard(image)
        
        // 5. Open Annotation Window
        DispatchQueue.main.async {
            self.annotationController = AnnotationWindowController(image: image)
            self.annotationController?.showWindow(nil)
        }
    }

    private func currentCaptureScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return ScreenCaptureManager.shared.screen(containing: mouseLocation) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func restorePreviouslyFrontmostAppIfNeeded() {
        defer { previouslyFrontmostApp = nil }

        guard let app = previouslyFrontmostApp else { return }
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { return }
        app.activate(options: [.activateIgnoringOtherApps])
    }
}

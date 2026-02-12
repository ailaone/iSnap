import Foundation
import AppKit
import SwiftUI

class CaptureFlowManager: ObservableObject {
    static let shared = CaptureFlowManager()

    private var selectionController: SelectionOverlayWindowController?
    private var annotationController: AnnotationWindowController?

    private var isCapturing = false

    func startCapture() {
        guard !isCapturing else {
            print("Already capturing")
            return
        }

        if !CGPreflightScreenCaptureAccess() {
            // Permission not granted. Show alert directing user to System Settings.
            // CGRequestScreenCaptureAccess() doesn't reliably show a prompt on macOS 15,
            // so we open System Settings directly.
            print("iSnap: Screen recording permission not granted, showing settings alert.")
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = "iSnap needs Screen Recording access to capture screenshots.\n\n1. Click \"Open Settings\" below\n2. Enable iSnap in the list\n3. Restart iSnap and try again"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        print("iSnap: Permission granted, starting capture.")
        isCapturing = true
        selectionController = SelectionOverlayWindowController()
        selectionController?.onSelectionComplete = { [weak self] rect, image in
            self?.isCapturing = false
            guard let self = self, let image = image else { return }

            _ = FileSaveManager.shared.saveBaseScreenshot(image)
            ClipboardManager.shared.copyToClipboard(image)
            self.startAnnotation(with: image)
        }
        selectionController?.startSelection()
    }

    func startAnnotation(with image: CGImage) {
        DispatchQueue.main.async {
            self.annotationController = AnnotationWindowController(image: image)
            self.annotationController?.showWindow(nil)
        }
    }
}

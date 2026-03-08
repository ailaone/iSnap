import AppKit
import SwiftUI

final class PreferencesWindowManager {
    static let shared = PreferencesWindowManager()

    private var preferencesWindow: NSWindow?

    private init() {}

    func openPreferences() {
        if preferencesWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 280),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Preferences"
            window.center()
            window.isReleasedWhenClosed = false
            window.level = .floating + 1
            window.contentView = NSHostingView(rootView: PreferencesView())
            preferencesWindow = window
        }

        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

import SwiftUI
import AppKit

@main
struct iSnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // Hiding default settings window
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app doesn't show in the dock (Info.plist LSUIElement should handle this too, but for safety)
        NSApp.setActivationPolicy(.accessory)
        
        menuBarManager = MenuBarManager()
        HotkeyManager.shared.registerDefaultHotkey()
    }
}

import AppKit
import SwiftUI

class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem
    private var menu: NSMenu

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        
        super.init()
        
        setupMenu()
        setupStatusItem()
    }

    private func setupStatusItem() {
        if let button = statusItem.button {
            // Load SVG from Bundle
            if let resourcePath = Bundle.main.resourcePath {
                let iconPath = resourcePath + "/icons/iSnap-menubar-logo.svg"
                if let image = NSImage(contentsOfFile: iconPath) {
                    image.size = NSSize(width: 18, height: 18) // Standard menu bar size
                    image.isTemplate = true // Adapt to dark/light mode
                    button.image = image
                } else {
                    // Fallback
                    button.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "iSnap")
                }
            }
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
        }
    }

    private func setupMenu() {
        let captureItem = NSMenuItem(title: "Capture Screenshot", action: #selector(captureScreenshot), keyEquivalent: "2")
        captureItem.keyEquivalentModifierMask = [.command, .option]
        captureItem.target = self
        menu.addItem(captureItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // specific hack to allow primary click interaction if we want it later, but standard menu behavior is fine for now
    }

    @objc func captureScreenshot() {
        print("Capture Triggered")
        CaptureFlowManager.shared.startCapture()
    }

    private var preferencesWindow: NSWindow?

    @objc func openPreferences() {
        print("Open Preferences")
        if preferencesWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 250),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Preferences"
            window.center()
            window.isReleasedWhenClosed = false
            window.level = .floating + 1 // V12.2: Ensure above annotation window
            window.contentView = NSHostingView(rootView: PreferencesView())
            preferencesWindow = window
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

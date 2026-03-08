import Foundation
import SwiftUI
import ServiceManagement

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // keys
    private let keyOneClickFullscreen = "oneClickFullscreen"
    private let keyEscActionSave = "escActionSave"
    private let keyEscActionCopy = "escActionCopy"
    private let keyOpenAfterCapture = "openAfterCapture"
    private let keySaveLocation = "saveLocation"
    private let keyOpenOnLogin = "openOnLogin"
    
    // Properties backed by UserDefaults
    @Published var oneClickFullscreen: Bool {
        didSet { UserDefaults.standard.set(oneClickFullscreen, forKey: keyOneClickFullscreen) }
    }
    
    @Published var escActionSave: Bool {
        didSet { UserDefaults.standard.set(escActionSave, forKey: keyEscActionSave) }
    }
    
    @Published var escActionCopy: Bool {
        didSet { UserDefaults.standard.set(escActionCopy, forKey: keyEscActionCopy) }
    }
    
    @Published var openAfterCapture: Bool {
        didSet { UserDefaults.standard.set(openAfterCapture, forKey: keyOpenAfterCapture) }
    }
    
    @Published var saveLocation: String {
        didSet { UserDefaults.standard.set(saveLocation, forKey: keySaveLocation) }
    }
    
    @Published var openOnLogin: Bool {
        didSet {
            UserDefaults.standard.set(openOnLogin, forKey: keyOpenOnLogin)
            setLoginItemEnabled(openOnLogin)
        }
    }
    
    private init() {
        // Load defaults
        self.oneClickFullscreen = UserDefaults.standard.object(forKey: keyOneClickFullscreen) as? Bool ?? true
        self.escActionSave = UserDefaults.standard.bool(forKey: keyEscActionSave)
        self.escActionCopy = UserDefaults.standard.bool(forKey: keyEscActionCopy)
        self.openAfterCapture = UserDefaults.standard.object(forKey: keyOpenAfterCapture) as? Bool ?? true
        self.saveLocation = UserDefaults.standard.string(forKey: keySaveLocation) ?? "~/Pictures/iSnap/"
        self.openOnLogin = UserDefaults.standard.bool(forKey: keyOpenOnLogin)

        applyStoredLoginItemPreference()
    }

    private func applyStoredLoginItemPreference() {
        setLoginItemEnabled(openOnLogin)
    }

    private func setLoginItemEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }

        if enabled && !Bundle.main.bundleURL.path.hasPrefix("/Applications/") {
            print("Open at Login requires iSnap to be installed in /Applications.")
            return
        }

        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") login item: \(error)")
        }
    }
}

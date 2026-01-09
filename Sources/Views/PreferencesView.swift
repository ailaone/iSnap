import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    Text("General").font(.headline)
                    Divider()
                    
                    HStack {
                        Text("Save location:")
                        TextField("", text: $settings.saveLocation)
                            .disabled(true) // Read-only text field
                        Button("Choose...") {
                            selectFolder()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section {
                VStack(alignment: .leading) {
                    Text("Functionality").font(.headline)
                    Divider()
                    
                    Text("\"Esc\" Key Action")
                        .padding(.top, 4)
                    
                    Toggle("Save screenshot", isOn: $settings.escActionSave)
                    Toggle("Copy to clipboard", isOn: $settings.escActionCopy)
                }
            }
            
            Section {
                VStack(alignment: .leading) {
                    Text("Behavior").font(.headline)
                    Divider()
                    
                    Toggle("One-click fullscreen screenshot", isOn: $settings.oneClickFullscreen)
                    // Toggle("Show icon in Dock", isOn: .constant(false)) // Removed as per request
                    Toggle("Open application on login", isOn: $settings.openOnLogin)
                }
            }
        }
        .padding()
        .frame(width: 500)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                settings.saveLocation = url.path
            }
        }
    }
}

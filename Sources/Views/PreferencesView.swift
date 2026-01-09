import SwiftUI

struct PreferencesView: View {
    @AppStorage("saveLocation") private var saveLocation: String = "~/Pictures/iSnap/"
    @AppStorage("openAfterCapture") private var openAfterCapture: Bool = true
    
    var body: some View {
        Form {
            Section(header: Text("General")) {
                Toggle("Open markup window after capture", isOn: $openAfterCapture)
            }
            
            Section(header: Text("Storage")) {
                HStack {
                    Text("Save Location:")
                    Spacer()
                    Text(saveLocation)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                    
                    Button("Choose...") {
                        selectFolder()
                    }
                }
            }
            
            Section(header: Text("Shortcuts")) {
                HStack {
                    Text("Capture:")
                    Spacer()
                    Text("⌘⌥2") // Placeholder until we have a real recorder
                        .padding(4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                Text("To change the shortcut, please edit system preferences (Shortcuts) for now or wait for v1.1 update.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 450, height: 250)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                saveLocation = url.path
            }
        }
    }
}

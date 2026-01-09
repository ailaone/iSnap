import Carbon
import AppKit

class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // Default Shortcut: Cmd+Option+2
    // For proper global hotkeys without Accessibility API, Carbon RegisterEventHotKey is best.
    // However, event taps are powerful but need permissions.
    // Let's use Carbon.
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    func registerDefaultHotkey() {
        let hotKeyID = EventHotKeyID(signature: 0x534E4150, id: 1) // SNAP, 1
        
        // Cmd(cmdKey) + Option(optionKey) + 2(kVK_ANSI_2 = 0x13)
        // 0x13 is '2'
        
        let status = RegisterEventHotKey(
            UInt32(0x13), // Key code for '2'
            UInt32(cmdKey | optionKey), // Modifiers
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            print("Registered Hotkey: Cmd+Opt+2")
            installEventHandler()
        } else {
            print("Failed to register hotkey: \(status)")
        }
    }
    
    private func installEventHandler() {
        let eventSpec = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        ]
        
        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
            // Handle Event
            // Access userData to call Swift method
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
            manager.handleHotkey()
            return noErr
        }, 1, eventSpec, pointer, &eventHandler)
    }
    
    private func handleHotkey() {
        print("Global Hotkey Pressed!")
        CaptureFlowManager.shared.startCapture()
    }
}

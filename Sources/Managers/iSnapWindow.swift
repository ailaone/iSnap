import AppKit

class iSnapWindow: NSWindow {
    var onEsc: (() -> Void)?
    
    override func cancelOperation(_ sender: Any?) {
        // Called when Esc is pressed
        onEsc?()
    }
    
    override var canBecomeKey: Bool {
        return true
    }
}

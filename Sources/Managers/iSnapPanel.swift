import AppKit

/// NSPanel subclass for the selection overlay.
/// Using NSPanel (not NSWindow) so `.nonactivatingPanel` works correctly,
/// allowing capture of tooltips and hover states in other apps.
class iSnapPanel: NSPanel {
    var onEsc: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onEsc?()
    }

    override var canBecomeKey: Bool {
        return true
    }
}

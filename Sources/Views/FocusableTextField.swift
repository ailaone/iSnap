import SwiftUI
import AppKit

// MARK: - Focusable Text Field (V3.5)
struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var isBold: Bool
    var isItalic: Bool
    var isUnderline: Bool // V9.3: Add Underline Prop
    var color: Color
    var onCommit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.textColor = NSColor(color)
        textField.font = getFont()
        
        // Transparent background
        textField.backgroundColor = .clear
        
        // V3.5: Unlimited width & Multi-line Configuration
        textField.cell?.wraps = false // Grow horizontally
        textField.cell?.isScrollable = false // Force frame expansion instead of scrolling
        textField.cell?.usesSingleLineMode = false // Allow newlines via code
        
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // CRITICAL FIX: Update coordinator's parent reference to ensure bindings are current
        context.coordinator.parent = self
        
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        // V9.3: Use Attributed String to support Underline
        // nsView.textColor = NSColor(color)
        // nsView.font = getFont()
        
        let font = getFont()
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(color)
        ]
        
        if isUnderline {
             attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        
        let currentString = nsView.stringValue
        nsView.attributedStringValue = NSAttributedString(string: currentString, attributes: attributes)
        
        // Force layout update to fit content
        nsView.invalidateIntrinsicContentSize()
        
        // Auto-focus if not already focused
        DispatchQueue.main.async {
            if let window = nsView.window, window.firstResponder != nsView.currentEditor() {
                window.makeFirstResponder(nsView)
                
                // V9.4: Ensure editor has correct attributes on focus
                if nsView.currentEditor() is NSTextView {
                    nsView.delegate?.controlTextDidChange?(Notification(name: NSText.didChangeNotification, object: nsView))
                }
            }
        }
    }
    
    private func getFont() -> NSFont {
        var font = NSFont.systemFont(ofSize: fontSize, weight: isBold ? .bold : .regular)
        if isItalic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        return font
    }
    
    private func updateAttributes(_ textField: NSTextField) {
        let font = getFont()
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(color)
        ]
        
        // V9.3: Add Underline Support
        if isUnderline { 
             attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        
        textField.attributedStringValue = NSAttributedString(string: text, attributes: attributes)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FocusableTextField

        init(_ parent: FocusableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
            
            // V9.4: Apply attributes to active editor (Live Underline)
            if let textView = textField.currentEditor() as? NSTextView {
                let range = NSRange(location: 0, length: textView.string.count)
                var attributes = textView.typingAttributes
                 
                 // Apply font/color
                let font = parent.getFont()
                attributes[.font] = font
                attributes[.foregroundColor] = NSColor(parent.color)
                
                if parent.isUnderline {
                    attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                } else {
                    attributes[.underlineStyle] = nil
                }
                
                textView.textStorage?.setAttributes(attributes, range: range)
                textView.typingAttributes = attributes // Ensure new typing gets it
            }
            
            textField.invalidateIntrinsicContentSize() // Ensure helper updates
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
                    // Shift+Enter: Insert/Append Newline
                    textView.insertText("\n", replacementRange: textView.selectedRange())
                    return true
                } else {
                    // Enter: Commit
                    parent.onCommit()
                    return true
                }
            }
            return false
        }
    }
}

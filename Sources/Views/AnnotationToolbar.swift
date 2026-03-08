import SwiftUI

struct FloatingToolbarView: View {
    @Binding var selectedTool: AnnotationView.Tool
    @Binding var activePopover: AnnotationView.Tool?
    // Zoom removed
    
    // Actions
    var onUndo: () -> Void
    var onRedo: () -> Void
    var onSave: () -> Void
    var onSaveAs: () -> Void
    var onCopy: () -> Void
    var onPreferences: () -> Void
    var onRefresh: () -> Void
    
    // Environment for color scheme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            // Group 1: Drawing Tools
            Group {
                V3ToolbarIcon(
                    iconName: "pen-20-regular",
                    isSelected: selectedTool == .pen,
                    tooltip: "Pen",
                    action: { selectTool(.pen) }
                )
                
                V3ToolbarIcon(
                    iconName: "highlight-20-regular",
                    isSelected: selectedTool == .highlighter,
                    tooltip: "Highlighter",
                    action: { selectTool(.highlighter) }
                )
                
                V3ToolbarIcon(
                    iconName: "shapes-20-regular",
                    isSelected: selectedTool == .shape,
                    tooltip: "Shapes",
                    action: { selectTool(.shape) }
                )
                
                V3ToolbarIcon(
                    iconName: "eraser-20-regular",
                    isSelected: selectedTool == .eraser,
                    tooltip: "Eraser",
                    action: { selectTool(.eraser) }
                )
            }
            
            ToolbarDivider()
            
            // Group 2: Redact & Text
            Group {
                V3ToolbarIcon(
                    iconName: "redact-20-regular",
                    isSelected: selectedTool == .redact,
                    tooltip: "Redact",
                    action: { selectTool(.redact) }
                )
                
                V3ToolbarIcon(
                    iconName: "text-case-title-20-regular",
                    isSelected: selectedTool == .text,
                    tooltip: "Text",
                    action: { selectTool(.text) }
                )
            }
            
            ToolbarDivider()
            
            // Group 4: Actions
            Group {
                V3ToolbarIcon(
                    iconName: "arrow-undo-20-regular",
                    isSelected: false,
                    tooltip: "Undo",
                    action: onUndo
                )
                
                V3ToolbarIcon(
                    iconName: "arrow-redo-20-regular",
                    isSelected: false,
                    tooltip: "Redo",
                    action: onRedo
                )
                
                V3ToolbarIcon(
                    iconName: "save-20-regular",
                    isSelected: false,
                    tooltip: "Save",
                    action: onSave
                )
                
                V3ToolbarIcon(
                    iconName: "save-edit-20-regular",
                    isSelected: false,
                    tooltip: "Save As",
                    action: onSaveAs
                )
                
                V3ToolbarIcon(
                    iconName: "copy-20-regular",
                    isSelected: false,
                    tooltip: "Copy to clipboard",
                    action: onCopy
                )

                ToolbarSystemIcon(
                    systemName: "gearshape",
                    tooltip: "Preferences",
                    action: onPreferences
                )
                
                V3ToolbarIcon(
                    iconName: "REFRESH-arrow-sync-20-regular",
                    isSelected: false,
                    tooltip: "Start Over",
                    action: onRefresh
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color(nsColor: .darkGray).opacity(0.85) : Color.white.opacity(0.85))
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        // Add subtle border
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func selectTool(_ tool: AnnotationView.Tool) {
        if selectedTool == tool {
            // Toggle popover if same tool
            if activePopover == tool {
                activePopover = nil
            } else {
                // Ensure popover is open for tools that have one
                if hasPopover(tool) {
                    activePopover = tool
                } else {
                    activePopover = nil
                }
            }
        } else {
            selectedTool = tool
            // Auto open popover for certain tools
            if hasPopover(tool) {
                activePopover = tool
            } else {
                activePopover = nil
            }
        }
    }
    
    private func hasPopover(_ tool: AnnotationView.Tool) -> Bool {
        switch tool {
        case .pen, .highlighter, .shape, .text:
            return true
        default:
            return false
        }
    }
}

struct ToolbarSystemIcon: View {
    let systemName: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary.opacity(isHovering ? 1.0 : 0.7))
                .scaleEffect(isHovering ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isHovering)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover in
            isHovering = hover
        }
        .modifier(CustomTooltip(text: tooltip))
    }
}

struct V3ToolbarIcon: View {
    let iconName: String
    let isSelected: Bool
    let tooltip: String
    let action: () -> Void
    
    @State private var isHovering = false
    
    @Environment(\.colorScheme) var colorScheme
    
    var selectionColor: Color {
        colorScheme == .dark ? Color(nsColor: .systemBlue) : .blue
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background Highlight
                if isSelected {
                    Circle()
                        .fill(selectionColor.opacity(colorScheme == .dark ? 0.3 : 0.15))
                        .frame(width: 32, height: 32)
                        // Outer Glow
                        .shadow(color: selectionColor.opacity(0.5), radius: 4, x: 0, y: 0)
                        // Stroke for extra contrast in dark mode
                        .overlay(
                            Circle().stroke(selectionColor.opacity(0.6), lineWidth: 1)
                        )
                }
                
                SVGButton(filename: iconName)
                    .foregroundColor(isSelected ? selectionColor : .primary)
                    .opacity(isSelected || isHovering ? 1.0 : 0.7)
                    .scaleEffect(isHovering ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isHovering)
            }
            .frame(width: 40, height: 40)
            .contentShape(Rectangle()) // Improve hover area
        }
        .buttonStyle(.plain)
        .onHover { hover in
            isHovering = hover
        }
        .modifier(CustomTooltip(text: tooltip))
    }
}

struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 1, height: 24)
            .padding(.horizontal, 4)
    }
}

// Helper to load SVGs from Resources/icons
struct SVGButton: View {
    let filename: String
    
    var image: NSImage? {
        // Handle both .svg and just name
        let name = filename.hasSuffix(".svg") ? filename : filename + ".svg"
        let path = Bundle.main.resourcePath! + "/icons/" + name
        guard let img = NSImage(contentsOfFile: path) else { return nil }
        img.isTemplate = true // Enable tinting for Dark/Light mode
        return img
    }
    
    var body: some View {
        if let nsImage = image {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: "questionmark.circle")
                .foregroundColor(.red)
        }
    }
}

// Custom Tooltip Modifier
struct CustomTooltip: ViewModifier {
    let text: String
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovering = $0 }
            .overlay(
                ZStack {
                    if isHovering {
                        Text(text)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(6)
                            // Position: Shift up above the icon
                            .offset(y: -35)
                            // Transition
                            .transition(.opacity.animation(.easeInOut(duration: 0.1)))
                            .fixedSize() // Ensure no wrapping
                    }
                }
                , alignment: .top // Align overlay to top
            )
    }
}

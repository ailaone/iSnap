import SwiftUI

// MARK: - Generic Popover container
struct PopoverContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 12) {
            content
        }
        .padding(12)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .fixedSize() // V3.0 Fix: Wrap content size
    }
}

struct LineWeightPreview: View {
    let thickness: CGFloat
    let color: Color
    var height: CGFloat = 30
    
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addCurve(
                to: CGPoint(x: size.width, y: size.height / 2),
                control1: CGPoint(x: size.width * 0.25, y: 0),
                control2: CGPoint(x: size.width * 0.75, y: size.height)
            )
            
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: height) // Fixed height for preview
    }
}

// MARK: - Pen Popover
struct PenPopover: View {
    @Binding var selectedColor: Color
    @Binding var selectedThickness: CGFloat
    
    let colors: [Color] = [
        .red, .orange, .yellow, .green, 
        .mint, .teal, .cyan, .blue, 
        .indigo, .purple, .pink, .brown, 
        .white, .gray, Color(nsColor: .darkGray), .black
    ]
    
    var body: some View {
        PopoverContainer {
            // Line Weight
            VStack(alignment: .leading, spacing: 4) {
                Text("Line Weight").font(.caption).foregroundColor(.secondary)
                LineWeightPreview(thickness: selectedThickness, color: selectedColor)
                Slider(value: $selectedThickness, in: 1...20)
                    .accentColor(selectedColor)
                    .frame(width: 160)
            }
            
            // Color Grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 4), spacing: 8) {
                ForEach(colors, id: \.self) { color in
                    ColorSwatch(color: color, isSelected: selectedColor == color) {
                        selectedColor = color
                    }
                }
            }
        }
    }
}

// MARK: - Highlighter Popover
struct HighlighterPopover: View {
    @Binding var selectedColor: Color
    @Binding var selectedThickness: CGFloat
    
    let colors: [Color] = [
        .yellow, .green, .cyan, .pink,
        .orange, .purple, .blue, .red
    ]
    
    var body: some View {
        PopoverContainer {
            // Line Weight
            VStack(alignment: .leading, spacing: 4) {
                Text("Line Weight").font(.caption).foregroundColor(.secondary)
                LineWeightPreview(thickness: selectedThickness * 4, color: selectedColor.opacity(0.5), height: 50)
                Slider(value: $selectedThickness, in: 5...10) // V3.8: Max 50%
                    .accentColor(selectedColor)
                    .frame(width: 160)
            }
            
            // Color Grid (2 rows of 4)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 4), spacing: 8) {
                ForEach(colors, id: \.self) { color in
                    ColorSwatch(color: color, isSelected: selectedColor == color) {
                        selectedColor = color
                    }
                }
            }
        }
    }
}

// MARK: - Shape Popover
struct ShapePopover: View {
    @Binding var selectedShape: AnnotationView.ShapeType
    @Binding var selectedColor: Color
    @Binding var selectedThickness: CGFloat
    
    let colors: [Color] = [
        .red, .orange, .yellow, .green, 
        .mint, .teal, .cyan, .blue, 
        .indigo, .purple, .pink, .brown, 
        .white, .gray, Color(nsColor: .darkGray), .black
    ]
    
    var body: some View {
        PopoverContainer {
            // Line Weight
            VStack(alignment: .leading, spacing: 4) {
                Text("Line Weight").font(.caption).foregroundColor(.secondary)
                LineWeightPreview(thickness: selectedThickness, color: selectedColor)
                Slider(value: $selectedThickness, in: 1...20)
                    .accentColor(selectedColor)
                    .frame(width: 160)
            }
            
            // Shapes Row
            HStack(spacing: 12) {
                ShapeButton(shape: .rectangle, isSelected: selectedShape == .rectangle) { selectedShape = .rectangle }
                ShapeButton(shape: .circle, isSelected: selectedShape == .circle) { selectedShape = .circle }
                ShapeButton(shape: .line, isSelected: selectedShape == .line) { selectedShape = .line }
                ShapeButton(shape: .arrow, isSelected: selectedShape == .arrow) { selectedShape = .arrow }
            }
            .padding(.bottom, 4)
            
            // Color Grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 4), spacing: 8) {
                ForEach(colors, id: \.self) { color in
                    ColorSwatch(color: color, isSelected: selectedColor == color) {
                        selectedColor = color
                    }
                }
            }
        }
    }
}

struct ShapeButton: View {
    let shape: AnnotationView.ShapeType
    let isSelected: Bool
    let action: () -> Void
    
    var iconName: String {
        switch shape {
        case .rectangle: return "square-20-regular"
        case .circle: return "circle-20-regular"
        case .line: return "line-20-regular"
        case .arrow: return "arrow-down-left-20-regular" // Approx
        }
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue, lineWidth: 2)
                        .background(Color.blue.opacity(0.1))
                }
                
                SVGButton(filename: iconName)
                    .foregroundColor(isSelected ? .blue : .primary)
                    .rotationEffect(shape == .arrow ? .degrees(180) : .degrees(0)) // Rotate to point up-right
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Text Popover
struct TextPopover: View {
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderline: Bool
    @Binding var selectedSize: AnnotationView.TextSize // V4.0
    @Binding var selectedColor: Color
    
    let colors: [Color] = [
        .red, .orange, .yellow, .green, 
        .mint, .teal, .cyan, .blue, 
        .indigo, .purple, .pink, .brown, 
        .white, .gray, Color(nsColor: .darkGray), .black
    ]
    
    var body: some View {
        PopoverContainer {
            // Style Toggles
            HStack(spacing: 12) {
                StyleToggleButton(icon: "text-bold-20-regular", isSelected: isBold) { isBold.toggle() }
                StyleToggleButton(icon: "text-italic-20-regular", isSelected: isItalic) { isItalic.toggle() }
                StyleToggleButton(icon: "text-underline-character-u-20-regular", isSelected: isUnderline) { isUnderline.toggle() }
            }
            .padding(.bottom, 4)
            
            // V4.0: Text Size Selector
            HStack(spacing: 8) {
                ForEach(AnnotationView.TextSize.allCases, id: \.self) { size in
                    Button(action: { selectedSize = size }) {
                        Text(size.label)
                            .font(.caption)
                            .fontWeight(selectedSize == size ? .bold : .regular)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedSize == size ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(4)
                            .foregroundColor(selectedSize == size ? .blue : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
            
            // Color Grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 4), spacing: 8) {
                ForEach(colors, id: \.self) { color in
                    ColorSwatch(color: color, isSelected: selectedColor == color) {
                        selectedColor = color
                    }
                }
            }
        }
    }
}

struct StyleToggleButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.1))
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue, lineWidth: 1)
                }
                
                SVGButton(filename: icon)
                    .foregroundColor(isSelected ? .blue : .primary)
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers
struct ColorSwatch: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
                
                if isSelected {
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 30, height: 30)
                }
            }
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }
}

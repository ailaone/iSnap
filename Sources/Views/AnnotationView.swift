import SwiftUI
import AppKit

struct AnnotationView: View {
    let image: NSImage
    weak var window: NSWindow?
    
    @State private var tool: Tool = .pen
    @State private var activePopover: Tool? = nil // V3.0
    
    // V5.0: Event Monitor Resource Management
    @State private var eventMonitor: Any?

    
    @StateObject private var drawingModel = DrawingModel()
    
    enum Tool: Equatable {
        case pen, highlighter, eraser, text, redact, shape
    }
    
    enum ShapeType {
        case rectangle, circle, line, arrow
    }


    struct ToolConfig: Equatable {
        var color: Color
        var thickness: CGFloat
    }

    @State private var toolConfigs: [Tool: ToolConfig] = [
        .pen: ToolConfig(color: .red, thickness: 5.0),
        .highlighter: ToolConfig(color: .yellow, thickness: 6.25),
        .shape: ToolConfig(color: .red, thickness: 5.0),
        .text: ToolConfig(color: .red, thickness: 0),
        .eraser: ToolConfig(color: .clear, thickness: 0),
        .redact: ToolConfig(color: .black, thickness: 0)
    ]
    
    // Helper to get binding for a specific tool
    private func binding(for tool: Tool) -> Binding<ToolConfig> {
        Binding(
            get: { toolConfigs[tool] ?? ToolConfig(color: .red, thickness: 5.0) },
            set: { toolConfigs[tool] = $0 }
        )
    }

    @State private var selectedShapeType: ShapeType = .rectangle
    
    // V3.0: Text State
    @State private var editingTextID: UUID? // Track which text is being edited

    @State private var isBold: Bool = false
    @State private var isItalic: Bool = false
    @State private var isUnderline: Bool = false
    
    // Drag State
    @State private var dragStart: CGPoint?
    @State private var currentDragRect: CGRect?
    @State private var currentDragStartPoint: CGPoint?
    @State private var currentDragEndPoint: CGPoint?
    
    // Selection State
    @State private var selectedAnnotationID: UUID?
    
    // V3.0: Undo/Redo State
    struct UndoState {
        let items: [AnnotationItem]
    }
    @State private var undoStack: [UndoState] = []
    @State private var redoStack: [UndoState] = []
    
    // Track previous state for undo grouping
    @State private var previousState: UndoState? = nil
    
    // V0.2.0: Esc Key Alert State
    @State private var showEscAlert = false

    


    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let imageSize = image.size
                let canvasSize = geometry.size
                
                // V8.2: Hybrid Scaling Logic
                // 1. Calculate aspect-fit scale
                let widthScale = imageSize.width > 0 ? canvasSize.width / imageSize.width : 1.0
                let heightScale = imageSize.height > 0 ? canvasSize.height / imageSize.height : 1.0
                let fitScale = min(widthScale, heightScale)
                let finalScale = min(fitScale, 1.0)
                
                let scaledWidth = imageSize.width * finalScale
                let scaledHeight = imageSize.height * finalScale
                
                let imgX = (canvasSize.width - scaledWidth) / 2
                let imgY = (canvasSize.height - scaledHeight) / 2
                
                let imageOffset = CGPoint(x: imgX, y: imgY)
                
                ZStack(alignment: .topLeading) { 
                    // Background is now on Root VStack
                
                    // Image is now drawn inside drawingContent (CanvasView)
                    
                    // Drawing Layer
                    drawingContent(image: image, offset: imageOffset, scale: finalScale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    
                }
            }
            
            // Toolbar Container
            // V9.2: Refactored to ZStack with strict frame to prevent layout jumping.
            // Using overlay on the Toolbar View itself ensures the popover doesn't impact layout size.
            VStack(spacing: 0) {
                FloatingToolbarView(
                    selectedTool: $tool,
                    activePopover: $activePopover,
                    onUndo: { undo() },
                    onRedo: { redo() },
                    onSave: saveContent,
                    onSaveAs: saveAsContent,
                    onCopy: copyContent,
                    onPreferences: {
                        MenuBarManager.shared.openPreferences()
                    },
                    onRefresh: {
                        saveState() 
                        drawingModel.items.removeAll()
                        editingTextID = nil
                    }
                )
                .overlay(alignment: .bottom) {
                    if let active = activePopover {
                        Group {
                                switch active {
                                case .pen:
                                    PenPopover(selectedColor: binding(for: .pen).color, selectedThickness: binding(for: .pen).thickness)
                                case .highlighter:
                                    HighlighterPopover(selectedColor: binding(for: .highlighter).color, selectedThickness: binding(for: .highlighter).thickness)
                                case .shape:
                                    ShapePopover(selectedShape: $selectedShapeType, selectedColor: binding(for: .shape).color, selectedThickness: binding(for: .shape).thickness)
                                case .text:
                                    TextPopover(
                                        isBold: $isBold, 
                                        isItalic: $isItalic, 
                                        isUnderline: $isUnderline, 
                                        selectedSize: $selectedTextSize, 
                                        selectedColor: binding(for: .text).color
                                    )
                                default:
                                    EmptyView()
                                }
                        }
                        .padding(.bottom, 65) // Lift 80pt from the bottom of the Toolbar View
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 90, maxHeight: 90) // Fixed height bottom area
            .padding(.bottom, 0) // Ensure sits at bottom
            
        } // End Root VStack
        .background(Color.white.opacity(0.85).ignoresSafeArea()) // V8.3: Unified Background (Toolbar sits ON window)
        .frame(minWidth: 540, minHeight: 400) // SwiftUI Constraints

        .onAppear {
            // Enforce Min Window Size based on Toolbar Width
            // Toolbar width is approx 500-520. Add padding.
            let minToolbarWidth: CGFloat = 540 
            let minHeight: CGFloat = 400 // Image + Toolbar
            
            // We do NOT enforce image width anymore (Hybrid Scaling)
            // ensuring window doesn't crush toolbar
            window?.minSize = NSSize(width: minToolbarWidth, height: minHeight)
            
            // Undo/Redo callback
            drawingModel.onStartInteraction = {
                self.saveState()
                self.activePopover = nil // Auto-dismiss popover
                self.commitEditing() // Commit text edit
            }
            
            // Monitor for delete key
            // Monitor for delete key and shortcuts
            // V5.0: Enhanced robustness - Use key codes instead of characters for consistent detection
            // Key Code 8 is 'C'
            let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // V20.0: Fix Zombie Event Monitor
                if let window = self.window, !window.isKeyWindow { return event }

                let keyCode = event.keyCode
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                
                // Command-C for Copy
                // V19.2: Robust Key Detection
                // KeyCode 8 is 'C'
                if flags.contains(.command) && (event.keyCode == 8 || event.charactersIgnoringModifiers?.lowercased() == "c") {
                   if self.editingTextID != nil { return event } // Allow text copy
                   
                   print("iSnap: Command-C detected, copying content...")
                   self.copyContent()
                   return nil // Consume event
                }
                
                if keyCode == 51 { 
                    if self.editingTextID != nil { return event } // Don't delete while typing text
                    if let id = selectedAnnotationID {
                        self.saveState() // Save before delete
                        drawingModel.items.removeAll { $0.id == id }
                        selectedAnnotationID = nil
                        return nil // Consume event
                    }
                }
                return event
            }
            self.eventMonitor = monitor
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("iSnapEscPressed"), object: window)) { _ in
             // V0.2.0: Check settings and content
             let settings = SettingsManager.shared
             
             // If action is configured, it's handled by 'iSnapPerformEscAction' notification.
             // This notification is for "Cancel/Default" behavior (no action configured).
             
             if !drawingModel.items.isEmpty && !settings.escActionSave && !settings.escActionCopy {
                 // Content exists and no auto-action configured -> Confirm with user
                 showEscAlert = true
             } else {
                 // No content or somehow fallthrough -> Close
                 window?.close()
             }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("iSnapPerformEscAction"), object: window)) { _ in
            // Handle configured Esc actions
            let settings = SettingsManager.shared
            
            // We need to commit current text if editing
            if editingTextID != nil {
                commitEditing()
            }
            
            // Actions
            if settings.escActionSave {
                _ = FileSaveManager.shared.saveAnnotatedScreenshot(renderCompositeImage())
            }
            
            if settings.escActionCopy {
                ClipboardManager.shared.copyToClipboard(renderCompositeImage())
            }
            
            // Finally close
            window?.close()
        }
        .alert("Close without saving?", isPresented: $showEscAlert) {
            Button("Save & Close") {
                saveContent()
                copyContent() // PRD: "Save & Close (saves annotated image, copies to clipboard, closes window)"
                window?.close()
            }
            Button("Discard", role: .destructive) {
                window?.close()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved annotations. Do you want to save them before closing?")
        }
    }
    
    enum TextSize: CGFloat, CaseIterable {
        case small = 18.0
        case medium = 24.0
        case large = 36.0
        
        var label: String {
            switch self {
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            }
        }
    }
    
    @State private var selectedTextSize: TextSize = .medium // V4.0: Text Size State

    private func addTextAnnotation(at visualPoint: CGPoint, imageOffset: CGPoint) {
        saveState() 
        activePopover = nil 
        
        // Convert to Model Coords
        let modelPoint = CGPoint(x: visualPoint.x - imageOffset.x, y: visualPoint.y - imageOffset.y)
        
        let font = NSFont.systemFont(ofSize: selectedTextSize.rawValue)
        let lineHeight = font.ascender - font.descender + font.leading
        
        
        // V4.1: Fix Text Placement (User reported "Right and Down")
        // Previously we shifted Y up by 'offset'. Removing this to place Top-Left at cursor.
        // Also compensating for the padding(5) in TextAnnotationView if needed, 
        // but raw placement at cursor is best.
        
        
        let initialHeight = lineHeight + 10
        let centeredY = modelPoint.y - (initialHeight / 2)
        
        // V4.2: Vertically Center Text (User request)
        let newText = TextAnnotation(
            id: UUID(),
            text: "", 
            position: CGPoint(x: modelPoint.x, y: centeredY), 
            size: CGSize(width: 100, height: initialHeight), 
            color: toolConfigs[.text]?.color ?? .red,
            fontSize: selectedTextSize.rawValue,
            isBold: isBold,
            isItalic: isItalic,
            isUnderline: isUnderline
        )
        drawingModel.addItem(AnnotationItem(id: newText.id, type: .text(newText)))
        selectedAnnotationID = newText.id
        editingTextID = newText.id // Auto-focus
    }
    
    private func commitEditing() {
        guard let id = editingTextID else { return }
        editingTextID = nil
        selectedAnnotationID = nil
        NSApp.keyWindow?.makeFirstResponder(nil)
        
        // Cleanup empty text annotations
        // We need to update items in place or remove
        if let item = drawingModel.getItem(id: id), case .text(let text) = item.type {
             if text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                 drawingModel.items.removeAll { $0.id == id }
             }
        }
    }
    
    // V3.0: Add Shape
    private func addShapeAnnotation(start: CGPoint, end: CGPoint) {
        let newShape = ShapeAnnotation(
            id: UUID(),
            type: selectedShapeType,
            startPoint: start,
            endPoint: end,
            color: toolConfigs[.shape]?.color ?? .red,
            lineWidth: toolConfigs[.shape]?.thickness ?? 5.0
        )
        drawingModel.addItem(AnnotationItem(id: newShape.id, type: .shape(newShape)))
        // selectedAnnotationID = newShape.id // V3.8: Don't select shapes as we don't have an overlay for them yet
    }
    
    func drawingContent(image: NSImage, offset: CGPoint, scale: CGFloat) -> some View {
        Group {
            // Drawing Layer
            CanvasRepresentable(
                model: drawingModel,
                image: image, // Pass image
                layoutOffset: offset, // Pass offset
                scale: scale, // Pass scale
                currentTool: tool,
                currentColor: toolConfigs[tool]?.color ?? .red,
                currentThickness: toolConfigs[tool]?.thickness ?? 5.0,
                excludingID: selectedAnnotationID,
                onErase: { point in
                    drawingModel.erase(at: point)
                },
                onShapeChange: { start, end in
                    currentDragStartPoint = start
                    currentDragEndPoint = end
                },
                onShapeEnd: { start, end in
                    addShapeAnnotation(start: start, end: end)
                },
                onTextClick: { point in
                    // V9.3: Improved Interaction Flow
                    // 1. If editing, commit old text first (don't return early)
                    if editingTextID != nil {
                        commitEditing() 
                        selectedAnnotationID = nil
                        // Fallthrough to handle the new click
                    }
                    
                    // 2. Hit Testing for selecting existing text
                     // Adjust for model coords which are relative to Image
                     // Point is coming from CanvasView which already converts to Model Coords? NO.
                     // OnTextClick comes from CanvasView mouseUp. 
                     // We should standardize: CanvasView reports VISUAL points? Or MODEL points?
                     // Let's have CanvasView report MODEL points (already subtracted offset).
                     
                     if let hitItem = drawingModel.items.last(where: { item in
                         guard case .text(let text) = item.type else { return false }
                         let rect = CGRect(x: text.position.x, y: text.position.y, width: text.size.width + 10, height: text.size.height + 10)
                         return rect.contains(point)
                    }) {
                         if case .text(_) = hitItem.type {
                             selectedAnnotationID = hitItem.id
                             editingTextID = hitItem.id
                             return
                         }
                    }
                    
                     addTextAnnotation(at: point, imageOffset: .zero) // Point is already model coord from CanvasView
                }
            )
            .allowsHitTesting(true)
            .contentShape(Rectangle()) // Ensure entire frame is hittable even if transparent
            
            // Text Editing Overlay
            // Only show when valid text editing is happening
            if let id = editingTextID, 
               let item = drawingModel.getItem(id: id),
               case .text(let text) = item.type {
                
                // Overlay View needs VISUAL coordinates
                let visualPos = CGPoint(x: text.position.x * scale + offset.x, y: text.position.y * scale + offset.y)
                
                // Create a binding that proxies the position
                let binding = Binding<TextAnnotation>(
                    get: { 
                         var t = text
                         t.position = visualPos
                         return t
                    },
                    set: { newText in 
                        var updated = newText
                        // Convert back to Model Coords
                        updated.position = CGPoint(x: (newText.position.x - offset.x) / scale, y: (newText.position.y - offset.y) / scale)
                        drawingModel.updateItem(AnnotationItem(id: id, type: .text(updated)))
                    }
                )
                
                TextAnnotationView(
                    annotation: binding,
                    isSelected: true,
                    isEditing: Binding(
                        get: { editingTextID == id },
                        set: { if !$0 { commitEditing() } }
                    ),
                    onSelect: { },
                    scale: scale // Pass scale to handle order correctly
                )
                // Removed external .scaleEffect and .offset to avoid double application
            }
            
            // V3.0: Draw current drag preview for Shapes
            // Shape Preview (Visual)
            if tool == .shape, let start = currentDragStartPoint, let end = currentDragEndPoint {
                ShapePreviewView(
                    type: selectedShapeType,
                    start: CGPoint(x: start.x * scale + offset.x, y: start.y * scale + offset.y), // Convert Model to Visual
                    end: CGPoint(x: end.x * scale + offset.x, y: end.y * scale + offset.y),
                    color: toolConfigs[.shape]?.color ?? .red,
                    lineWidth: (toolConfigs[.shape]?.thickness ?? 5.0) * scale // Scale thickness visual
                )
                }
            
            // Interaction Overlay (V3.3: Fix Zoom Drawing)

        }
        }

    
    private func saveContent() {
        let composite = renderCompositeImage()
        _ = FileSaveManager.shared.saveAnnotatedScreenshot(composite)
        ClipboardManager.shared.copyToClipboard(composite)
        // window?.close() // Removed as per user request
    }
    
    // V5.0: Copy Support
    private func copyContent() {
         let composite = renderCompositeImage()
         ClipboardManager.shared.copyToClipboard(composite)
         
         // Visual feedback (Optional, but nice)
         // For now just copy silently as per standard macOS behavior
    }
    
    // V13: Save As Support
    private func saveAsContent() {
        let composite = renderCompositeImage()
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save Screenshot As"
        savePanel.message = "Choose a location to save your screenshot."
        savePanel.nameFieldStringValue = "Screenshot_\(dateString())"
        
        let completionHandler: (NSApplication.ModalResponse) -> Void = { response in
            if response == .OK, let url = savePanel.url {
                // Convert NSImage to CGImage for saving
                var rect = CGRect(origin: .zero, size: composite.size)
                if let cgImage = composite.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                    _ = FileSaveManager.shared.saveImage(cgImage, to: url)
                }
            }
        }
        
        if let window = self.window {
            savePanel.beginSheetModal(for: window, completionHandler: completionHandler)
        } else {
            // Fallback: Ensure it floats on top if we can't attach as sheet
            savePanel.level = .modalPanel
            savePanel.begin(completionHandler: completionHandler)
        }
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
    
    private func renderCompositeImage(scale: CGFloat = 2.0) -> NSImage {
        // 1. Define Image Rect at Origin (0,0)
        // User requested "Crop to annotations", avoiding extra white border.
        // We start with the image at (0,0).
        let imageRect = CGRect(origin: .zero, size: image.size)
        var totalBounds = imageRect
        
        // 2. Expand bounds for all annotations
        for item in drawingModel.items {
            switch item.type {
            case .stroke(let stroke):
                // V9.5: Fix Smart Crop - Calculate stroke bounds independently first
                // Previously we expanded the *union* (image + stroke), which caused accumulated borders.
                var strokeBounds: CGRect?
                for p in stroke.points {
                    let r = CGRect(origin: p, size: .zero)
                    if strokeBounds == nil { strokeBounds = r }
                    else { strokeBounds = strokeBounds!.union(r) }
                }
                
                if let sb = strokeBounds {
                    let inset = -stroke.width 
                    let expandedStroke = sb.insetBy(dx: inset, dy: inset)
                    totalBounds = totalBounds.union(expandedStroke)
                }
                
            case .shape(let shape):
                let shapeRect = CGRect(
                    x: min(shape.startPoint.x, shape.endPoint.x),
                    y: min(shape.startPoint.y, shape.endPoint.y),
                    width: abs(shape.startPoint.x - shape.endPoint.x),
                    height: abs(shape.startPoint.y - shape.endPoint.y)
                )
                totalBounds = totalBounds.union(shapeRect.insetBy(dx: -shape.lineWidth, dy: -shape.lineWidth))
                
            case .text(let text):
                // Text size might need padding? Text drawing usually fits in size.
                // Using size + small padding to be safe
                let textRect = CGRect(origin: text.position, size: text.size)
                totalBounds = totalBounds.union(textRect)
            }
        }
        
        // Ensure integer mapping
        totalBounds = totalBounds.integral
        
        // 3. Create Image
        // V14.1: Proper DPI Handling
        // logicalSize is what we want the file to "look like" in points (e.g. 500x500)
        
        let logicalSize = totalBounds.size
        
        if logicalSize.width <= 0 || logicalSize.height <= 0 { return NSImage(size: NSSize(width: 100, height: 100)) }
        
        // Create NSImage with proper logical size
        let composite = NSImage(size: logicalSize)
        
        // V17: Dynamic Scale Calculation
        // Calculate the EXACT scale of the source image to avoid mismatch (e.g. 1x vs 2x)
        var srcRect = CGRect(origin: .zero, size: image.size)
        var actualScale: CGFloat = scale // Default to passed scale (usually 2.0)
        
        // Try to get the backing CGImage to check real pixel width
        if let cgImg = image.cgImage(forProposedRect: &srcRect, context: nil, hints: nil) {
            if image.size.width > 0 {
                actualScale = CGFloat(cgImg.width) / image.size.width
            }
        }
        
        // Manual Representation Creation with ACTUAL scale
        let pixelWidth = Int(logicalSize.width * actualScale)
        let pixelHeight = Int(logicalSize.height * actualScale)
        
        // Match Source Color Space if possible
        let targetColorSpaceName: NSColorSpaceName = .deviceRGB
        
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: targetColorSpaceName,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return composite }
        
        // Removed manual assignment of rep.colorSpace (read-only)
        
        rep.size = logicalSize // IMPORTANT: This tells macOS the logical size, implying scale = pixel / logical
        
        // V15: Explicit Context Creation for Sharpness
        // Do NOT use composite.lockFocus(). It relies on global state/screen.
        // Create context directly from the high-res representation.
        guard let graphicsContext = NSGraphicsContext(bitmapImageRep: rep) else {
            print("Failed to create graphics context from rep")
            return composite
        }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        
        // 4. Fill White Background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: logicalSize).fill()
        
        // Prepare Context for simple CG drawing if needed, but NS drawing is fine in NSContext
        let context = graphicsContext.cgContext
        
        // 5. Draw Image
        // totalBounds.origin is the top-left of the crop rect in Model Space.
        // We want to map totalBounds.origin to (0, logicalSize.height) in Context Space (flipped)?
        // NSImage.lockFocus() provides a standard (bottom-left) coordinate system.
        // Image is at (0, 0) in Model Space (Top-Left).
        // totalBounds might start at (-100, -100).
        // If totalBounds.origin is (-100, -100). Width 200, Height 200.
        // We want Model(0,0) to appear at Context(100, ...)
        
        // Calculate offset to shift everything so totalBounds.origin becomes (0,0)
        let shiftX = -totalBounds.origin.x
        let shiftY = -totalBounds.origin.y // Model Y shift
        
        // Drawing Image:
        // Image Origin is (0,0) Model.
        // It should be drawn at (shiftX, ...)
        // In BL coords:
        // DestX = shiftX
        // DestY = logicalSize.height - (0 + shiftY) - image.height?
        
        let destX = shiftX
        let destY = logicalSize.height - shiftY - imageRect.height
        
        // V16: Direct CG Drawing for sharpness
        // Get the underlying CGImage from the NSImage to avoid re-rasterization or resolution mismatch
        // Get the underlying CGImage from the NSImage to avoid re-rasterization or resolution mismatch
        // srcRect already defined above
        if let cgImage = image.cgImage(forProposedRect: &srcRect, context: nil, hints: nil) {
            context.saveGState()
            // Ensure no unwanted interpolation for 1:1 pixel mapping, but High is safer for slight mismatches
            context.interpolationQuality = .high 
            context.draw(cgImage, in: CGRect(x: destX, y: destY, width: imageRect.width, height: imageRect.height))
            context.restoreGState()
        } else {
            // Fallback (Should not happen if image is valid)
            image.draw(in: NSRect(x: destX, y: destY, width: imageRect.width, height: imageRect.height))
        }
        
        // 6. Draw Annotations
        // drawingModel.drawStrokes expects a context.
        // It applies transform: (p.x - offset.x, p.y - offset.y)
        // We want p = totalBounds.origin to map to (0,0).
        // So offset should be totalBounds.origin.
        
        context.saveGState()
        drawingModel.drawStrokes(
            in: context,
            size: logicalSize,
            isFlipped: false, // We are in NSImage context (BL), but drawStrokes handles flip logic if we tell it?
            // Wait, drawStrokes logic:
            // if isFlipped { return (x, y) } else { return (x, size.height - y) }
            // If we pass isFlipped: false (standard BL context).
            // It converts Model Y to BL Y. Correct.
            // Offset logic: x - offset.x.
            // We want Model(totalBounds.minX) -> 0.
            // So offset = totalBounds.origin.
            offset: totalBounds.origin,
            type: .export // V9.9: High Fidelity Export
        )
        context.restoreGState()
        
        NSGraphicsContext.restoreGraphicsState()
        
        composite.addRepresentation(rep)
        return composite
    }
    
    // MARK: - Undo/Redo Logic
    private func saveState() {
        let currentState = UndoState(
            items: drawingModel.items
        )
        undoStack.append(currentState)
        redoStack.removeAll()
    }
    
    private func undo() {
        guard let lastState = undoStack.popLast() else { return }
        // Save current to redo
        let currentState = UndoState(items: drawingModel.items)
        redoStack.append(currentState)
        
        // Restore
        drawingModel.items = lastState.items
    }
    
    private func redo() {
        guard let nextState = redoStack.popLast() else { return }
        // Save current to undo
        let currentState = UndoState(items: drawingModel.items)
        undoStack.append(currentState)
        
        // Restore
        drawingModel.items = nextState.items
    }

}

// MARK: - Shape Models & Views (V3.0)

struct ShapeAnnotation: Identifiable {
    let id: UUID
    var type: AnnotationView.ShapeType
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: Color
    var lineWidth: CGFloat
}

struct ShapePreviewView: View {
    let type: AnnotationView.ShapeType
    let start: CGPoint
    let end: CGPoint
    let color: Color
    let lineWidth: CGFloat
    var startScaled: CGPoint { start }
    var endScaled: CGPoint { end }
    
    var rect: CGRect {
        CGRect(
             x: min(start.x, end.x),
             y: min(start.y, end.y),
             width: abs(start.x - end.x),
             height: abs(start.y - end.y)
        )
    }
    
    var body: some View {
        Group {
            if type == .rectangle {
                rectangleView
            } else if type == .circle {
                circleView
            } else if type == .line {
                lineView
            } else if type == .arrow {
                arrowView
            }
        }
    }

    @ViewBuilder
    var rectangleView: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(color, lineWidth: lineWidth)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    @ViewBuilder
    var circleView: some View {
        Ellipse()
            .stroke(color, lineWidth: lineWidth)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    @ViewBuilder
    var lineView: some View {
        createLinePath()
            .stroke(color, lineWidth: lineWidth)
    }

    @ViewBuilder
    var arrowView: some View {
        createArrowPath()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
    
    private func createLinePath() -> Path {
        Path { path in
            path.move(to: startScaled)
            path.addLine(to: endScaled)
        }
    }
    
    private func createArrowPath() -> Path {
        Path { path in
            path.move(to: startScaled)
            path.addLine(to: endScaled)
            
            // Arrowhead Logic
            
            let arrowLength = lineWidth * 4.0
            
            // Explicit Double Math to avoid ambiguity
            let dx = Double(endScaled.x - startScaled.x)
            let dy = Double(endScaled.y - startScaled.y)
            let angle = atan2(dy, dx)
            let arrowAngle = Double.pi / 6.0 // 30 degrees
            let arrowLen = Double(arrowLength)
            
            let p1x = Double(endScaled.x) - arrowLen * cos(angle - arrowAngle)
            let p1y = Double(endScaled.y) - arrowLen * sin(angle - arrowAngle)
            
            let p2x = Double(endScaled.x) - arrowLen * cos(angle + arrowAngle)
            let p2y = Double(endScaled.y) - arrowLen * sin(angle + arrowAngle)
            
            let p1 = CGPoint(x: p1x, y: p1y)
            let p2 = CGPoint(x: p2x, y: p2y)
            
            path.move(to: endScaled)
            path.addLine(to: p1)
            path.move(to: endScaled)
            path.addLine(to: p2)
        }
    }
}

struct ShapeAnnotationView: View {
    @Binding var annotation: ShapeAnnotation
    var zoom: Double
    var isSelected: Bool
    var onSelect: () -> Void
    
    var body: some View {
        ShapePreviewView(
            type: annotation.type,
             start: annotation.startPoint,
             end: annotation.endPoint,
             color: annotation.color,
             lineWidth: annotation.lineWidth
        )
        .onTapGesture { onSelect() }
        .overlay(
            isSelected ?             Path { path in
                 let start = annotation.startPoint
                 let end = annotation.endPoint
                 let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
                 path.addRect(rect)
            }
            .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, dash: [5]))
            : nil
        )
    }
}

extension CGRect {
    init(from: CGPoint, to: CGPoint) {
        self.init(x: min(from.x, to.x), y: min(from.y, to.y), width: abs(from.x - to.x), height: abs(from.y - to.y))
    }
}

// MARK: - Text Annotation Model & View
struct TextAnnotation: Identifiable {
    let id: UUID
    var text: String
    var position: CGPoint
    var size: CGSize 
    var color: Color
    var fontSize: CGFloat // V4.0
    var isBold: Bool
    var isItalic: Bool
    var isUnderline: Bool
}
// Moved View Logic to Overlay


struct TextAnnotationView: View {
    @Binding var annotation: TextAnnotation
    var isSelected: Bool
    @Binding var isEditing: Bool // V3.1: External control
    var onSelect: () -> Void
    var scale: CGFloat = 1.0 // V9.0: Handle scaling internally
    
    @State private var dragOffset: CGSize = .zero 
    @State private var initialPosition: CGPoint?

    var body: some View {
        ZStack(alignment: .leading) {
            // Hidden text to force checking layout size (Fix clipping)
            Text(annotation.text + "_") // Add extra char for cursor space
                .font(.system(
                    size: annotation.fontSize, // V4.0 
                    weight: annotation.isBold ? .bold : .regular, 
                    design: .default
                ))
                .italic(annotation.isItalic)
                .underline(annotation.isUnderline)
                .multilineTextAlignment(.leading) // V3.7: Fix alignment
                .opacity(0)
                .layoutPriority(1) // Prioritize this size
                
            if isEditing {
                FocusableTextField(
                    text: $annotation.text,
                    fontSize: annotation.fontSize, // V4.0
                    isBold: annotation.isBold,
                    isItalic: annotation.isItalic,
                    isUnderline: annotation.isUnderline, // V9.3: Pass underline
                    color: annotation.color,
                    onCommit: {
                        isEditing = false // Handled by binding
                        // NSApp.keyWindow?.makeFirstResponder(nil) // Handled by commitEditing
                        // Trigger commit via binding set in parent
                    }
                )
            } else {
                Text(annotation.text.isEmpty ? "Text" : annotation.text)
                    .font(.system(
                        size: annotation.fontSize, // V4.0 
                        weight: annotation.isBold ? .bold : .regular, 
                        design: .default
                    ))
                    .italic(annotation.isItalic)
                    .underline(annotation.isUnderline)
                    .multilineTextAlignment(.leading) // V3.7: Fix alignment
                    .foregroundColor(annotation.color)
                    .opacity(annotation.text.isEmpty ? 0.5 : 1.0) // Dim placeholder
            }
        }
            .padding(5)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .overlay(
                isSelected ? RoundedRectangle(cornerRadius: 4).stroke(Color.blue, lineWidth: 1) : nil
            )
            .fixedSize()
            // V9.0: Apply Scale BEFORE Offset
            .scaleEffect(scale, anchor: .topLeading)
            // V4.1: Compensate for padding(5) so text starts at actual position
            .offset(
                x: annotation.position.x + dragOffset.width - 5,
                y: annotation.position.y + dragOffset.height - 5
            )
            .onTapGesture(count: 2) {
                onSelect()
                isEditing = true
            }
            .onTapGesture(count: 1) {
                onSelect()
                // Do NOT stop editing on single tap if already editing
                if !isEditing {
                    isEditing = false
                }
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if isEditing { return }
                        onSelect()
                        if initialPosition == nil { initialPosition = annotation.position }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        if let start = initialPosition {
                            // Convert translation back to model space
                            annotation.position = CGPoint(
                                x: start.x + value.translation.width, 
                                y: start.y + value.translation.height
                            )
                        }
                        dragOffset = .zero
                        initialPosition = nil
                    }
            )
    }
}


// MARK: - Drawing Model (Updated for Eraser)

class DrawingModel: ObservableObject {
    @Published var items: [AnnotationItem] = []
    
    var onStartInteraction: (() -> Void)?
    
    struct Stroke: Identifiable {
        let id = UUID() // V2.1: Add ID for object erasing
        var points: [CGPoint]
        var color: NSColor
        var width: CGFloat
        var isHighlighter: Bool
        var isRedact: Bool
        // isEraser removed as we erase objects
    }
    
    func erase(at point: CGPoint, threshold: CGFloat = 10.0) {
        items.removeAll { item in
            switch item.type {
            case .stroke(let stroke):
                 return stroke.points.contains { p in hypot(p.x - point.x, p.y - point.y) < threshold }
            case .shape(let shape):
                 let bounds = CGRect(from: shape.startPoint, to: shape.endPoint).insetBy(dx: -5, dy: -5)
                 return bounds.contains(point)
            case .text(let text):
                 let rect = CGRect(
                    x: text.position.x, 
                    y: text.position.y, 
                    width: text.size.width + 10, // expanded hit area 
                    height: text.size.height + 10
                 ).insetBy(dx: -5, dy: -5)
                 return rect.contains(point)
            }
        }
    }
    
    func addItem(_ item: AnnotationItem) {
        items.append(item)
    }
    
    func getItem(id: UUID) -> AnnotationItem? {
        items.first { $0.id == id }
    }
    
    func updateItem(_ item: AnnotationItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }

    
    enum ContextType {
        case live
        case export
    }

    func drawStrokes(in context: CGContext?, size: CGSize, excludingID: UUID? = nil, isFlipped: Bool = true, offset: CGPoint = .zero, type: ContextType = .live) {
        guard let context = context else { return }
        
        // Helper to transform point
        func t(_ p: CGPoint) -> CGPoint {
            let x = p.x - offset.x
            let y = p.y - offset.y
            if isFlipped {
                return CGPoint(x: x, y: y)
            } else {
                return CGPoint(x: x, y: size.height - y)
            }
        }
        
        for item in items {
            if item.id == excludingID { continue }
            
            switch item.type {
            case .stroke(let stroke):
                 context.saveGState()
                 context.setLineCap(.round)
                 context.setLineJoin(.round)
                 context.setLineWidth(stroke.width)
                 
                 context.setStrokeColor(stroke.color.cgColor)
                 if stroke.isHighlighter {
                      if type == .export {
                          context.setBlendMode(.multiply)
                          context.setAlpha(1.0) // Export: Deep, vibrant multiply
                      } else {
                          context.setBlendMode(.multiply) // Live: Now using multiply as well since image is in context
                          context.setAlpha(0.6) // Match the live drawing alpha
                      }
                      
                      context.setLineCap(.butt) 
                      
                      // V9.6: Use brighter neon colors for highlighter
                      let brightColor = stroke.color.toHighlighterColor()
                      context.setStrokeColor(brightColor.cgColor)
                 } else {
                      context.setBlendMode(.normal)
                      context.setAlpha(1.0)
                      context.setLineCap(.round)
                 }
                 
                 let points = stroke.points.map { t($0) }
                 
                 if stroke.isRedact {
                     if let start = points.first, let end = points.last {
                         context.setFillColor(stroke.color.cgColor)
                         // Rect calculation handles flipped/unflipped if we use min/max/abs
                         context.fill(CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y)))
                     }
                 } else {
                     let path = CGMutablePath()
                     guard let start = points.first else { 
                         context.restoreGState()
                         continue 
                     }
                     path.move(to: start)
                     for point in points.dropFirst() {
                         path.addLine(to: point)
                     }
                     context.addPath(path)
                     context.strokePath()
                 }
                 context.restoreGState()
                 
            case .shape(let shape):
                 context.saveGState()
                 context.setStrokeColor(NSColor(shape.color).cgColor)
                 context.setLineWidth(shape.lineWidth)
                 context.setLineCap(.round)
                 context.setLineJoin(.round)
                 
                 let start = t(shape.startPoint)
                 let end = t(shape.endPoint)
                 let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
                 
                 switch shape.type {
                 case .rectangle:
                     let path = CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil)
                     context.addPath(path)
                     context.strokePath()
                 case .circle:
                     context.strokeEllipse(in: rect)
                 case .line:
                    context.move(to: start)
                    context.addLine(to: end)
                    context.strokePath()
                 case .arrow:
                    // Shaft
                    context.move(to: start)
                    context.addLine(to: end)
                    context.strokePath()
                    
                    // Arrowhead
                    let arrowLength = shape.lineWidth * 4.0
                    // Angle calculation needs correct Y direction
                    // If !isFlipped (Bottom-Left), Y increases Up. 
                    // atan2(dy, dx). If dragging down-right:
                    // Screen (Top-Left): dy > 0. 
                    // Image (Bottom-Left): dy < 0.
                    // The calculated points passed to context lines should be correct relative to visual end point.
                    
                    let angle = atan2(end.y - start.y, end.x - start.x)
                    let arrowAngle = CGFloat.pi / 6
                    
                    let p1 = CGPoint(
                        x: end.x - arrowLength * cos(angle - arrowAngle),
                        y: end.y - arrowLength * sin(angle - arrowAngle)
                    )
                    let p2 = CGPoint(
                        x: end.x - arrowLength * cos(angle + arrowAngle),
                        y: end.y - arrowLength * sin(angle + arrowAngle)
                    )
                    
                    context.move(to: end)
                    context.addLine(to: p1)
                    context.move(to: end)
                    context.addLine(to: p2)
                    context.strokePath()
                 }
                 context.restoreGState()
                 
            case .text(let text):
                 let fontSize = text.fontSize
                 var font = NSFont.systemFont(ofSize: fontSize)
                 if text.isBold { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
                 if text.isItalic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
                 
                 var attrs: [NSAttributedString.Key: Any] = [
                     .foregroundColor: NSColor(text.color),
                     .font: font
                 ]
                 if text.isUnderline {
                     attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                 }
                 
                 let str = NSAttributedString(string: text.text, attributes: attrs)
                 let textSize = str.size()
                 
                 // Calculate Origin
                 let p = t(text.position)
                 var origin = p
                 
                 // If NOT flipped (Bottom-Left), 'p' is the top-left corner of the text visually converted to BL coords.
                 // t() converts (x, y_tl) -> (x, H - y_tl).
                 // Visually: text.position is Top-Left of the text block.
                 // In BL system, the point (x, H - y_tl) is the TOP-Left of the text block.
                 // NSString.draw(in:) with default context (BL) expects rect origin at Bottom-Left?
                 // Wait, str.draw(in: rect) usually aligns top-left of rect with start of text?
                 // No, standard Cocoa drawing in unflipped context: Rect (x, y, w, h). Text draws inside.
                 // Usually baseline is handled.
                 // If I pass a Rect to .draw(in:), it figures it out.
                 // But I need the Rect to be correct.
                 // If I am in BL context: Rect(x, y, w, h).
                 // Text will draw inside this rect.
                 // If text.position is visual Top-Left.
                 // In BL context, visual Top-Left is at y' = H - y_tl.
                 // Visual Bottom-Left is at y'' = H - y_tl - h_text.
                 // The Rect origin should be (x, y'').
                 
                 if !isFlipped {
                     origin.y -= textSize.height
                 }
                 
                 let rect = CGRect(origin: origin, size: textSize)
                 
                 NSGraphicsContext.saveGraphicsState()
                 str.draw(in: rect)
                 NSGraphicsContext.restoreGraphicsState()
            }
        }
    }
}

// MARK: - Unified Data Model
struct AnnotationItem: Identifiable {
    let id: UUID
    var type: AnnotationType
}

enum AnnotationType {
    case stroke(DrawingModel.Stroke)
    case shape(ShapeAnnotation)
    case text(TextAnnotation)
}


// MARK: - Canvas Views (Updated)
// CanvasRepresentable & CanvasView logic remains largely same, just updated toolAttributes for Eraser

struct CanvasRepresentable: NSViewRepresentable {
    @ObservedObject var model: DrawingModel
    var image: NSImage? // V9.10: Pass image for internal rendering
    var layoutOffset: CGPoint
    var scale: CGFloat // V8.2: Hybrid Scaling support
    var currentTool: AnnotationView.Tool
    var currentColor: Color 
    var currentThickness: CGFloat 
    var excludingID: UUID?
    var onErase: (CGPoint) -> Void 
    var onShapeChange: ((CGPoint?, CGPoint?) -> Void)?
    var onShapeEnd: ((CGPoint, CGPoint) -> Void)?
    var onTextClick: ((CGPoint) -> Void)?
    
    func makeNSView(context: Context) -> CanvasView {
        let view = CanvasView()
        view.autoresizingMask = [.width, .height]
        updateNSView(view, context: context)
        return view
    }
    
    func updateNSView(_ view: CanvasView, context: Context) {
        view.update(model: model, image: image, tool: currentTool, color: currentColor, thickness: currentThickness, excludingID: excludingID, layoutOffset: layoutOffset, scale: scale)
        view.onErase = onErase
        view.onShapeChange = onShapeChange
        view.onShapeEnd = onShapeEnd
        view.onTextClick = onTextClick
    }
}

class CanvasView: NSView {
    var model: DrawingModel?
    var image: NSImage? // V9.10
    var currentTool: AnnotationView.Tool = .pen
    var currentColor: NSColor = .red
    var currentThickness: CGFloat = 5.0
    var excludingID: UUID?
    var layoutOffset: CGPoint = .zero 
    var scale: CGFloat = 1.0 // V8.2
    
    var onErase: ((CGPoint) -> Void)? 
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    var onShapeChange: ((CGPoint?, CGPoint?) -> Void)?
    var onShapeEnd: ((CGPoint, CGPoint) -> Void)?
    var onTextClick: ((CGPoint) -> Void)?
    
    private var currentPoints: [CGPoint] = []
    private var dragStartPoint: CGPoint?
    
    override var isFlipped: Bool { true } 
    
    func update(model: DrawingModel, image: NSImage?, tool: AnnotationView.Tool, color: Color, thickness: CGFloat, excludingID: UUID?, layoutOffset: CGPoint, scale: CGFloat) {
        self.model = model
        self.image = image
        self.currentTool = tool
        self.currentColor = NSColor(color)
        self.currentThickness = thickness
        self.excludingID = excludingID
        self.layoutOffset = layoutOffset
        self.scale = scale // Update scale
        self.needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        
        // Transform Context to Visual Coordinates (Offset + Scale)
        context.translateBy(x: layoutOffset.x, y: layoutOffset.y)
        context.scaleBy(x: scale, y: scale)
        
        // This context is transparent by default in an NSView (if isOpaque=false)
        // Drawing efficiently: In a real app we'd use an offscreen bitmap buffer.
        // For simple strokes, redrawing all is okay.
        
        // 1. Draw the base image FIRST
        if let image = image, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.saveGState()
            // Fix Flipped Coordinate System for Image Drawing
            // We are in a Flipped View (Top-Left origin).
            // CGImage expects Bottom-Left origin.
            // Transform: Translate down by Height, then Scale Y by -1.
            context.translateBy(x: 0, y: image.size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            
            let imageRect = CGRect(origin: .zero, size: image.size)
            context.draw(cgImage, in: imageRect)
            context.restoreGState()
        }

        // 2. Draw Strokes
        // CanvasView is Flipped (True)
        // Offset is handled by Context Transform now, so pass .zero for offset logic inside drawStrokes
        // Actually, drawStrokes internally handles text flip logic. 
        // Text Position is Model Coord. Context is transformed to Visual.
        // It should match.
        model?.drawStrokes(
             in: context, 
             size: bounds.size, // Size is ignored for untransformed/unflipped? Pass bounds just in case.
             excludingID: excludingID,
             isFlipped: true,
             offset: .zero,
             type: .live // V9.9: Live Preview
        )
        
        if !currentPoints.isEmpty {
            drawCurrentStroke(in: context)
        }
        
        context.restoreGState()
    }
    
    private func drawCurrentStroke(in context: CGContext) {
        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        // Transform Context to Visual Coordinates
        // currentPoints are stored in Model Coordinates
        // Validation: Context is ALREADY transformed by draw(_:)
        // DO NOT apply transform again.
        // context.translateBy(x: layoutOffset.x, y: layoutOffset.y)
        // context.scaleBy(x: scale, y: scale)
        
        if currentTool == .eraser { 
            context.restoreGState()
            return 
        } // Don't draw eraser trail
        
        let (color, width, isHighlighter, isRedact) = toolAttributes()
        
        context.setLineWidth(width)
        context.setStrokeColor(color.cgColor)
        if isHighlighter {
             context.setBlendMode(.multiply) // Live Drawing: TRUE Multiply
             context.setAlpha(0.6) // Slightly higher alpha for visibility
             context.setLineCap(.butt) 
             // Brighter Color
             context.setStrokeColor(color.toHighlighterColor().cgColor)
        } else {
             context.setBlendMode(.normal)
             context.setAlpha(1.0)
             context.setLineCap(.round)
        }
        
        if isRedact {
             if let start = currentPoints.first, let end = currentPoints.last {
                context.setFillColor(color.cgColor)
                context.fill(CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y)))
            }
        } else {
            let path = CGMutablePath()
            guard let start = currentPoints.first else { return }
            path.move(to: start)
            for point in currentPoints.dropFirst() {
                path.addLine(to: point)
            }
            context.addPath(path)
            context.strokePath()
        }
        context.restoreGState()
    }
    
    private func toolAttributes() -> (NSColor, CGFloat, Bool, Bool) {
        // Returns: (Color, Width, Highlighter, Redact)
        // Eraser handled separately
        switch currentTool {
        case .pen: 
            return (currentColor, currentThickness, false, false)
        case .highlighter: 
            return (currentColor, currentThickness * 4, true, false)
        case .redact: 
            return (.black, 1.0, false, true) 
        default: 
            return (.clear, 0, false, false)
        }
    }
    
    // MARK: - Event Handling
    
    // MARK: - Event Handling
    
    // V3.4: Improve Hit Testing for Zoom
    // V3.4: Improve Hit Testing for Zoom
    // Removed manual hitTest override. Standard NSView frame-based hit testing is robust enough since we control layout.
    // Overriding hitTest can cause issues with coordinate conversion if not careful.
    
    // Allow accepting mouse events even if window is not key (though it usually is)
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    


    override func mouseDown(with event: NSEvent) {
        
        // Common Input Handling: Convert to local view coordinates (handles zoom/scroll)
        let point = convert(event.locationInWindow, from: nil)
        // Convert Visual Point -> Model Point: (Visual - Offset) / Scale
        let normalized = CGPoint(x: (point.x - layoutOffset.x) / scale, y: (point.y - layoutOffset.y) / scale)
        
        // Notify start
        model?.onStartInteraction?()
        
        switch currentTool {
        case .pen, .highlighter, .redact, .eraser:
            currentPoints = [normalized]
            needsDisplay = true // Ensure visual updates start immediately
            if currentTool == .eraser { onErase?(normalized) }
            
        case .shape:
            dragStartPoint = normalized
            onShapeChange?(dragStartPoint, dragStartPoint)
            
        case .text:
             onTextClick?(normalized)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let normalized = CGPoint(x: (point.x - layoutOffset.x) / scale, y: (point.y - layoutOffset.y) / scale)
        
        switch currentTool {
        case .pen, .highlighter, .redact:
            currentPoints.append(normalized)
            needsDisplay = true
            
        case .eraser:
            onErase?(normalized)
            
        case .shape:
            guard let start = dragStartPoint else { return }
            onShapeChange?(start, normalized)
            
        case .text:
            break
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let normalized = CGPoint(x: (point.x - layoutOffset.x) / scale, y: (point.y - layoutOffset.y) / scale)
        
        switch currentTool {
        case .pen, .highlighter, .redact:
            if currentPoints.count > 1 {
                let (color, width, isHighlighter, isRedact) = toolAttributes()
                let stroke = DrawingModel.Stroke(
                    points: currentPoints,
                    color: color,
                    width: width,
                    isHighlighter: isHighlighter,
                    isRedact: isRedact
                )
                model?.addItem(AnnotationItem(id: stroke.id, type: .stroke(stroke)))
            }
            currentPoints = []
            needsDisplay = true

            
        case .eraser:
            onErase?(normalized)
            needsDisplay = true

        case .shape:
            guard let start = dragStartPoint else { return }
            // Only add if dragged significantly (> 5pt)
            if hypot(normalized.x - start.x, normalized.y - start.y) > 5 {
                onShapeEnd?(start, normalized)
            }
            onShapeChange?(nil, nil) // Clear preview
            dragStartPoint = nil
            
        default:
            currentPoints = []
        }
    }
}

// MARK: - Color Extension for Highlighter
extension NSColor {
    func toHighlighterColor() -> NSColor {
        // Convert standard palette to Neon Brights
        // Usually colors are: Red, Orange, Yellow, Green, Blue, Purple
        
        let colorSpace = self.usingColorSpace(.deviceRGB) ?? self
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        colorSpace.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Simple heuristic: If dominant component, maximize it.
        // Or map known defaults.
        
        // Red -> Neon Pink/Magenta
        if red > 0.8 && green < 0.5 && blue < 0.5 { return NSColor(deviceRed: 1.0, green: 0.0, blue: 1.0, alpha: 1.0) }
        
        // Green -> Neon Green
        if green > 0.8 && red < 0.5 && blue < 0.5 { return NSColor(deviceRed: 0.0, green: 1.0, blue: 0.0, alpha: 1.0) }
        
        // Blue -> Cyan
        if blue > 0.8 && red < 0.5 && green < 0.5 { return NSColor(deviceRed: 0.0, green: 1.0, blue: 1.0, alpha: 1.0) }
        
        // Yellow -> Neon Yellow
        if red > 0.8 && green > 0.8 && blue < 0.5 { return NSColor(deviceRed: 1.0, green: 1.0, blue: 0.0, alpha: 1.0) }
        
        // Orange -> Neon Orange
        if red > 0.8 && green > 0.4 && green < 0.7 && blue < 0.5 { return NSColor(deviceRed: 1.0, green: 0.6, blue: 0.0, alpha: 1.0) }

        // Default: just boost saturation/brightness if possible, or return self
        return self
    }
}

// MARK: - Zoomable Scroll View (NSViewRepresentable)

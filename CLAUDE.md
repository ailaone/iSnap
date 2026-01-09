# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iSnap is a lightweight macOS menu bar application for screen capture and annotation. It provides a streamlined workflow: capture a screen region, automatically save and copy to clipboard, then open an annotation interface with drawing tools, shapes, text, and redactions.

**Key Design Principles:**
- Menu bar only app (no dock icon) via `LSUIElement` in Info.plist
- Minimal UI footprint during capture (full-screen transparent overlay)
- Rich post-capture annotation capabilities
- Async screen capture with proper thread marshaling

## Build and Run Commands

### Build the application
```bash
# Standard debug build
swift build

# Release build (creates optimized executable)
swift build -c release --build-path /tmp/iSnapBuild
```

### Build complete .app bundle
```bash
# Creates iSnap.app with proper bundle structure, icons, and Info.plist
./build_app.sh

# Run the app
open iSnap.app
```

### Icon generation
```bash
# Regenerate AppIcon.icns from SVG (runs automatically during build_app.sh)
./create_icns.sh
```

**Note:** The build script uses `/tmp` as build directory to avoid network drive locking issues.

## Architecture Overview

### Manager-Based Architecture

The application follows a **singleton manager pattern** with clear separation of concerns:

```
iSnapApp (Entry Point)
└── AppDelegate
    ├── MenuBarManager (status bar icon and menu)
    └── HotkeyManager (global hotkey: Cmd+Opt+2)
```

**Core Managers:**

- **MenuBarManager**: Status bar integration, menu items, app entry point
- **HotkeyManager**: Global hotkey registration using Carbon Events API
- **CaptureFlowManager**: Orchestrates entire capture-to-annotation workflow
- **ScreenCaptureManager**: Low-level screen capture using ScreenCaptureKit (macOS 14+)
- **SelectionOverlayWindowController**: Full-screen transparent selection overlay
- **AnnotationWindowController**: Creates and manages annotation window
- **FileSaveManager**: PNG file persistence to `~/Pictures/iSnap/`
- **ClipboardManager**: NSPasteboard operations

All managers use singleton pattern: `ManagerName.shared`

### Capture Flow

The complete capture sequence:

```
User Trigger (Hotkey/Menu)
    ↓
CaptureFlowManager.startCapture()
    ↓
Permission Check (Screen Recording)
    ↓
SelectionOverlayWindowController (full-screen transparent overlay)
    ↓
User draws selection rectangle
    ↓
ScreenCaptureManager.captureRegion() [Async with ScreenCaptureKit]
    ↓
Parallel Actions:
    ├─ FileSaveManager.saveBaseScreenshot() → ~/Pictures/iSnap/
    ├─ ClipboardManager.copyToClipboard()
    └─ CaptureFlowManager.startAnnotation()
        ↓
AnnotationWindowController opens with captured image
```

**Key Implementation Details:**
- Selection overlay uses `NSWindow.Level.screenSaver` (highest level)
- Coordinate system conversion: AppKit (bottom-left origin) ↔ CoreGraphics (top-left origin)
- ScreenCaptureKit excludes iSnap's own windows from capture
- Fallback to `CGWindowListCreateImage()` for older macOS versions

### Annotation System

**AnnotationView** is the central annotation interface built with SwiftUI + NSView integration:

**State Management:**
- `DrawingModel` (@StateObject): Manages strokes for pen, highlighter, eraser, redact tools
- `shapeAnnotations`: Array of ShapeAnnotation (rectangle, circle, line, arrow)
- `textAnnotations`: Array of TextAnnotation with formatting (bold, italic, underline)

**Tools Available:**
- **Pen**: Freehand drawing (5-20pt width, customizable color)
- **Highlighter**: Translucent overlay with multiply blend mode (50% alpha)
- **Eraser**: Hit-test based removal of strokes/shapes/text
- **Text**: Tap to place, double-tap to edit, drag to move
- **Redact**: Black fill for sensitive information
- **Shape**: Rectangle, circle, line, arrow with drag-to-draw

**Undo/Redo System:**
- Stack-based full state preservation
- Captures complete snapshot: strokes + shapes + text annotations
- `saveState()` called on interaction start, restored via `undo()`/`redo()`

**Rendering Pipeline (on save):**
1. Create `NSImage` at original capture size
2. Draw base screenshot image
3. Render all strokes via `DrawingModel.drawStrokes()` (CoreGraphics)
4. Render all shapes via CoreGraphics context
5. Render all text via `NSAttributedString`
6. Save as PNG with `_annotated` suffix
7. Copy composite to clipboard
8. Window remains open (user must close manually)

### Window Management

**Window Hierarchy:**
- **SelectionOverlay**: `.screenSaver` level (highest, above everything)
- **AnnotationWindow**: `.floating` level
- **PreferencesWindow**: Standard window level

**Custom Window: iSnapWindow**
- Extends `NSWindow` to override `cancelOperation()` for Esc key handling
- Esc during selection: Cancel capture
- Esc during annotation: Save and close window

## Key Architectural Patterns

1. **Singleton Managers**: All managers use `static let shared` for app-wide access
2. **Callback/Closure Pattern**: Event-driven with `onSelectionComplete` callbacks
3. **Observable State**: SwiftUI `@StateObject` and `@Published` for reactive UI
4. **NSViewRepresentable Bridge**: `CanvasView` bridges SwiftUI ↔ NSView for CoreGraphics drawing
5. **Async/Await + GCD**: Screen capture is async, callbacks marshal to main thread
6. **Weak References**: `[weak self]` in closures to prevent retain cycles

## File Organization

```
Sources/
├── iSnapApp.swift                    # App entry point, AppDelegate
├── Managers/
│   ├── MenuBarManager.swift             # Status bar icon and menu
│   ├── HotkeyManager.swift              # Global hotkey registration
│   ├── CaptureFlowManager.swift         # Orchestrates capture workflow
│   ├── ScreenCaptureManager.swift       # ScreenCaptureKit integration
│   ├── SelectionOverlayWindowController.swift  # Selection UI
│   ├── AnnotationWindowController.swift # Annotation window creation
│   ├── FileSaveManager.swift            # PNG persistence
│   ├── ClipboardManager.swift           # NSPasteboard operations
│   └── iSnapWindow.swift             # Custom NSWindow for Esc key
└── Views/
    ├── AnnotationView.swift             # Main annotation interface
    ├── AnnotationToolbar.swift          # Tool selection UI
    ├── AnnotationPopovers.swift         # Color/size pickers
    └── PreferencesView.swift            # Settings window

Resources/
├── Info.plist                           # Bundle config (LSUIElement, permissions)
├── AppIcon.icns                         # Generated from SVG
└── icons/
    └── iSnap-logo.svg                # Source icon (18x18 for menu bar)
```

## Important Technical Details

### Permissions
- **Screen Recording**: Required for ScreenCaptureKit
- Request via: `CGRequestScreenCaptureAccess()`
- Check via: `CGPreflightScreenCaptureAccess()`
- Usage string in Info.plist: `NSScreenCaptureUsageDescription`

### Coordinate System Handling
AppKit uses bottom-left origin, CoreGraphics uses top-left. Coordinate conversion in `SelectionOverlayWindowController`:

```swift
let flippedY = primaryScreenHeight - (globalRect.origin.y + globalRect.height)
let flippedRect = CGRect(x: globalRect.origin.x, y: flippedY,
                         width: globalRect.width, height: globalRect.height)
```

### ScreenCaptureKit Configuration
- **Color Space**: sRGB
- **Scale**: 1x (native resolution)
- **Show Cursor**: false
- **Window Exclusion**: Filters out iSnap's own windows via `windowID`
- **Display Selection**: Finds display containing selection rect automatically

### File Naming Convention
- Base screenshots: `Screenshot_YYYY-MM-DD_HH-MM-SS.png`
- Annotated screenshots: `Screenshot_YYYY-MM-DD_HH-MM-SS_annotated.png`
- Default location: `~/Pictures/iSnap/` (configurable in Preferences)

## Common Development Patterns

### Adding a New Annotation Tool

1. Add tool case to `Tool` enum in `AnnotationView.swift`
2. Add tool button to `FloatingToolbarView` with appropriate SF Symbol
3. Implement tool behavior in `AnnotationView`:
   - For drawing tools: Add to `DrawingModel` with new stroke type
   - For object tools: Create new annotation type similar to `ShapeAnnotation`
4. Update rendering in `saveContent()` to include new tool output
5. Update undo/redo system if new state needs preservation

### Modifying Capture Behavior

- Selection UI: `SelectionOverlayWindowController.swift` and `SelectionView` in that file
- Screen capture: `ScreenCaptureManager.swift` (ScreenCaptureKit configuration)
- Post-capture flow: `CaptureFlowManager.swift` (orchestration logic)

### Window Behavior Changes

- Window levels: Modify `window.level` in controller initializers
- Window styling: Update window properties in `AnnotationWindowController` or `SelectionOverlayWindowController`
- Keyboard shortcuts: Override in `iSnapWindow.swift` or add to menu in `MenuBarManager.swift`

## Technology Stack

- **Frameworks**: AppKit (NSWindow, NSView, NSStatusBar) + SwiftUI
- **Graphics**: CoreGraphics (CGContext, CGImage), NSImage
- **Capture**: ScreenCaptureKit (macOS 14+) with CGWindowListCreateImage fallback
- **Hotkeys**: Carbon Events API (RegisterEventHotKey)
- **Persistence**: UserDefaults (@AppStorage), FileManager
- **Clipboard**: NSPasteboard
- **Minimum macOS**: 14.0 (specified in Package.swift)

## Bundle Identifier

`com.ailadesign.Snapmark` - Used for app identification and permissions

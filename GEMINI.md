# Project Overview

iSnap is a macOS menu bar application for taking and annotating screenshots. It's written in Swift using the AppKit framework. The application runs as an accessory, meaning it doesn't appear in the Dock, and is primarily interacted with via a menu bar icon and global hotkeys.

## Building and Running

The project is built using Swift Package Manager. A custom build script, `build_app.sh`, is provided to create the final `.app` bundle.

To build and run the application:

1.  **Build the application:**

    ```bash
    ./build_app.sh
    ```

2.  **Run the application:**

    ```bash
    open iSnap.app
    ```

## Development Conventions

The codebase is structured into `Managers` and `Views`.

*   **Managers:** Handle the core logic of the application, such as screen capture, hotkey management, and the menu bar interface.
*   **Views:** Contain the SwiftUI views for the application's user interface, such as the annotation tools and preferences.

The application follows the standard Swift coding conventions.

# Session Memory

## Current State
- Working target is `v0.2.0`.
- Bundle ID is `com.arthurazoulai.isnap`.
- Version/build are `0.2.0` / `20`.
- Release prep values are stored in `RELEASE_PREP_v0.2.0.md`.

## Build And Release Workflow
- Normal local build: `./build_app.sh`
- Signed QA build:
```bash
ISNAP_SIGN_APP=1 \
ISNAP_SIGNING_IDENTITY="Developer ID Application: Arthur Azoulai (VV6P9DRYR6)" \
./build_app.sh
```
- DMG packaging: `./create_dmg.sh`
- Notarization after QA: `./notarize_dmg.sh`
- Notary keychain profile name: `iSnapNotary`
- App-specific password is only for notarization, not local signed builds.

## Important QA Notes
- Screen Recording permission is more stable when testing a signed build from `/Applications`.
- Unsigned local builds can cause repeated permission prompts.
- `Open at Login` is implemented with `SMAppService.mainApp` and should be tested from `/Applications`.

## Capture Architecture
- Region capture now uses a frozen-screen overlay instead of a live transparent overlay.
- This was necessary so iSnap can capture open Finder menus, submenus, and transient UI like the native screenshot tool.
- Core files:
  - `Sources/Managers/CaptureFlowManager.swift`
  - `Sources/Managers/SelectionOverlayWindowController.swift`
  - `Sources/Managers/ScreenCaptureManager.swift`

## Capture Behavior That Currently Works
- Open menus and submenus can be captured.
- `Esc` cancels capture mode.
- Small capture windows no longer crop the toolbar.
- Preferences button is present in the annotation toolbar.
- Open at Login is wired in settings.

## Known Tradeoff
- Canceling capture can still show some app-dependent flicker.
- This flicker is structural: the overlay becomes key/frontmost so first-shot cursor swap and `Esc` cancellation work reliably, then iSnap restores the previously frontmost app on cancel.
- Further attempts to reduce that flicker risk breaking:
  - first-shot cursor swap
  - `Esc` cancel
  - menu capture stability
- Recommendation from this session: keep the current capture behavior unless the flicker becomes release-blocking, and treat future capture-overlay changes as high-risk.

## What Was Implemented This Session
- Updated app metadata in `Resources/Info.plist`
- Added universal build output in `build_app.sh`
- Added `create_dmg.sh`
- Added `notarize_dmg.sh`
- Added `PreferencesWindowManager`
- Added toolbar preferences button
- Implemented Open at Login in `SettingsManager`
- Reworked Esc handling in the annotation window
- Reworked capture mode to frozen overlay capture

## Collaboration Constraints
- Git operations are handled by the repository owner in GitHub Desktop only.
- Do not use git CLI commands for commits, rebases, pushes, or other normal repo operations unless explicitly asked.

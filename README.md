# DownloadScroller

A familiar fan. Room for every file.

DownloadScroller is a native macOS app that opens a **scrollable file fan** from its own Dock icon or the menu bar. Choose Downloads (or another folder), then scroll, search, preview, and open your files without the built-in stack's overflow cutoff.

**Early preview · macOS 14 or later · Swift + SwiftUI + AppKit · MIT licensed**

<img src="docs/images/fan.png" alt="DownloadScroller's floating Dock-style file fan, using generated sample files" width="420">

The fan uses floating filename capsules and real file icons on a transparent window, with a curve inspired by the macOS Dock fan. It has no surrounding panel or file cards. Scroll with a trackpad or mouse wheel anywhere in the fan's browsing area, including the gaps between files and the empty space beside them. Search opens at the bottom when you click the magnifying glass or press Command-F; short results stay close to it. The screenshot capture uses a plain backdrop; the running fan floats over your desktop.

This is a standalone app. It does not modify Apple's Downloads stack or replace the Dock process. Its Dock icon opens a floating panel at the usable edge of the current display; its menu bar button opens the panel below that button. The app is **not yet published on the Mac App Store**.

## Features

- Continuous scrolling through all visible items, with smooth interpolation for regular mouse wheels and native trackpad momentum.
- A dedicated curved fan with softer filename capsules and high-resolution Quick Look thumbnails.
- A running Dock icon that shows the newest completed file, regardless of search, filter, or sort order.
- Search by filename, including multiple words and case-insensitive matches.
- File-type filters and newest, oldest, name, size, or kind sorting.
- Single-click opening, Quick Look, and reveal in Finder.
- Live updates when items arrive, disappear, or are renamed.
- Folder access remembered using a read-only security-scoped bookmark.
- Keyboard navigation, accessibility labels, and reduced-motion support.
- A sample folder with 240 real generated files to try before granting access.
- Local operation, with no analytics, accounts, network entitlement, or third-party dependencies.

## Build and run

With Apple's Command Line Tools and Swift 6 or later:

```sh
git clone https://github.com/mganesh1610/DownloadScroller.git
cd DownloadScroller
bash scripts/build-app.sh
open dist/DownloadScroller.app
```

The script builds for the current Mac's architecture, creates the app bundle and icon, and applies an **ad-hoc signature with App Sandbox enabled**. This is a local development build, not a notarized download or an App Store distribution package. Build locally or use your own signing identity. Don't disable Gatekeeper to run a downloaded development build.

With full Xcode 16 or later, open `DownloadScroller.xcodeproj`, select your signing team, and run the `DownloadScroller` scheme. The native project also supports universal release builds and archives. Its default bundle identifier is `io.github.mganesh1610.DownloadScroller`; use your own identifier for forks.

On first launch, choose Downloads using the folder picker. The **folder menu** at the bottom of the fan provides sorting, filters, folder selection, disconnect, and pinning. Keep the app in the Dock manually using the Dock's **Options → Keep in Dock** action if desired. Closing the fan leaves the app running; **⌘Q** quits it. Pinning keeps it visible when switching apps.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ↑ / ↓ | Select a file |
| Return | Open selected file |
| Space or ⌘Y | Quick Look (Space while not editing search) |
| ⌘F | Search |
| ⌘R | Refresh |
| ⇧⌘R | Reveal selected file in Finder |
| ⇧⌘O | Choose a folder |
| ⌘1 | Show the panel while the app is active |
| Esc / ⌘W | Close the panel (Esc clears a search first) |
| ⌘Q | Quit |

These shortcuts work while DownloadScroller is active; they are not global hotkeys.

## Development

```sh
swift test                        # Full Xcode: XCTest suite
bash scripts/test-core.sh         # The same scenarios, without XCTest, for Command Line Tools
bash scripts/prepare-assets.sh    # Regenerate the original vector app icon
python3 scripts/generate-xcode-project.py
```

The eight core scenarios cover search, sorting, classification, a 240-file scan, hidden files, non-recursive enumeration, missing-folder errors, newest completed-file selection, and wheel motion at different refresh rates, direction reversals, and bounds. CI also builds the native Xcode target for both Apple Silicon and Intel without distribution signing.

`Sources/DownloadScrollerCore` contains immutable file metadata, classification, queries, and enumeration. `Sources/DownloadScroller` owns the sandbox bookmark, folder watcher, a layer-backed AppKit fan and scroll surface, SwiftUI controls, floating panel, dynamic Dock icon, status item, and Quick Look controller. No user-selected file is modified or deleted by the app. Opening a file delegates to the user's chosen application.

## Current limits

- One selected folder at a time; immediate children only. Hidden files are omitted.
- Directory events trigger a debounced rescan. Content-only edits inside existing files may need **⌘R**.
- Preview availability depends on the Quick Look providers installed on the Mac.
- Cloud-only files may need their provider to download them before opening or previewing.
- The dynamic Dock icon is active while the app runs. The original app icon remains in the app bundle and is restored on quit or when no completed file is available.
- Known partial-download suffixes and folders are excluded from the Dock image; completion of arbitrary file formats cannot be inferred.
- Dock panel placement uses the display's usable edge, not private Dock icon geometry.
- There is no launch-at-login feature, global shortcut, drag-out support, or automatic updater in this preview.
- Minimum-version testing, Intel runtime testing, and App Store review remain release tasks; compiling for those targets is not equivalent to testing on them.

See [validation notes](docs/VALIDATION.md), [App Store preparation](docs/APP_STORE.md), [privacy](PRIVACY.md), and [contributing](CONTRIBUTING.md).

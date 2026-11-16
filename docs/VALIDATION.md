# Validation

This document distinguishes completed checks from release work. App Store readiness requires further testing and account setup.

## Earlier local checks (before the native-scroll update)

Environment: Apple Silicon Mac, macOS 27.0.1, Apple Swift 6.4.2 Command Line Tools. No full Xcode installation or distribution signing identity was available locally.

- Release executable compiled, bundled as a native `.app`, and launched.
- Ad-hoc signature passed `codesign --verify --strict`; the app includes sandbox, user-selected read-only, and app-scope bookmark entitlements.
- Plist, entitlement, privacy manifest, and Xcode project syntax validated with `plutil`.
- Five core scenarios passed through the Command Line Tools adapter. These run the same methods that XCTest runs with full Xcode: multi-term/case/accent search, sort behavior, file-type classification, a 240-file non-recursive scan, and an unavailable-folder error.
- Native UI displayed 240 sample files; trackpad-style scrolling reached the last item without a file-count cutoff.
- Command-F search reduced the sample folder to one matching image.
- Quick Look displayed the content of a generated text file.
- A generated test folder was selected through the real macOS picker while the app was sandboxed.
- A file added externally to that test folder appeared in the open panel automatically.
- After quitting and relaunching, the saved test folder reopened with its four files, without another picker.
- Down-arrow navigation changed the selected file; Space opened Quick Look.
- List view and an empty type-filter result displayed correctly; clearing filters restored the files.
- Disconnecting the folder returned to onboarding and removed the saved bookmark.
- The redesigned transparent fan was visually checked with floating capsules and icons. Wheel scrolling without a visible scrollbar reached item 240; Command-F searched the stack, and a single result reduced the window height.
- PNG Quick Look rendered correctly after ending search-field editing before handing off the responder chain.
- Opening a generated text file from the fan launched TextEdit with the expected document contents and dismissed the unpinned fan.
- The finished app was copied to the local user's Applications folder, its signature reverified, and its onboarding screen opened successfully.

The local `swift test` command cannot run because Apple's Command Line Tools installation does not contain XCTest. `scripts/test-core.sh` provides a small assertion adapter and now executes the same ten test methods. CI uses full Xcode and runs real XCTest plus the native universal application build.

## CI verification

The initial native version passed all five XCTest cases and the arm64 + x86_64 Xcode release build on a GitHub-hosted macOS 15 runner with Xcode 16.4 / Swift 6.1.2. The workflow now runs all ten cases and universal builds with both Xcode 16.4 and 26.3. This covers compilation of the native-material fallback and the Liquid Glass path; the macOS 15 runner does not exercise Liquid Glass at runtime. Check the [latest workflow result](https://github.com/mganesh1610/DownloadScroller/actions/workflows/ci.yml) for the current commit.

## Known preview-provider behavior

Text and PNG Quick Look were verified. SVG and CSV preview attempts on this Mac displayed a loading indicator rather than promptly rendering, while SVG thumbnails did render. CSV was rechecked after the focus-handling fix and still stalled. Quick Look is delegated to installed macOS providers; these formats need further testing before claiming broad preview coverage.

## Native fan and regular-wheel update

The fan now defines one rectangular scroll surface behind the floating files, including empty space. Its background retains a single alpha step so macOS can route input over otherwise fully transparent pixels. File buttons cover their labels and icons; clicking blank space does not open a file.

The fan uses an AppKit `NSScrollView` with a fixed-height document and only the visible file rows. There is no lazy-row size estimation. Curve transforms update with implicit layer animation disabled. Regular mouse-wheel notches are interpolated on the display refresh clock; precise events and their momentum stay with AppKit. Reduce Motion uses direct AppKit scrolling and an unrotated arrangement. The system-appearance update below replaces the earlier custom row layers with native material, text, and image views.

Eight core scenarios passed locally. The added cases verify newest completed-file selection (excluding folders and known partial extensions), gradual wheel travel, matching displacement at 60/120 Hz, direction reversal, bounded queued travel, and clamping at both ends. These are deterministic motion tests, not measured frame-rate or physical-device benchmarks.

The sandboxed release app was rebuilt and its ad-hoc signature verified. Native UI checks with generated samples covered:

- All 240 files, including the last item, are reachable.
- Forward scrolling in the blank area and at the right edge; reverse scrolling between rows.
- Blank clicks leave files unopened; clicking a rotated filename opens the correct text file.
- Context-menu Quick Look displays the selected text document; Command-Y from search displays the matching PNG.
- Command-F opens search at the bottom. A single result stays near the bottom, and typing leaves the window height stable.
- File accessibility buttons are enabled and labelled; broader VoiceOver testing remains on the release checklist.
- The folder menu has no list-view option.
- Original gray capsules, native icons, and higher-resolution previews were visually inspected. Public screenshots contain generated sample files only.

The dynamic icon is driven by all scanned entries, independently of visible results, through the public AppKit icon API. Newest-file selection has automated coverage. A direct visual check of the Dock icon and its behavior across Dock settings remains a release check; the automation could not capture the Dock surface on this Mac.

## Outside-click dismissal and Dock identity

The fan now observes mouse-down events delivered to other apps while it is open, covering system menu-bar popovers that leave DownloadScroller active. It also closes when another window takes focus or the app deactivates. The mouse monitor is removed on dismissal, app hiding, window closure, and termination. **Keep window open** still opts out; the folder picker and the app's own Quick Look panel remain part of the current session.

The rebuilt sandboxed app passed signature verification and all eight then-existing core scenarios. Native UI checks confirmed that the fan's own menu, keyboard Quick Look, and folder-picker cancellation remain usable after installing the monitor. The automation cannot directly open Control Center, and interactions aimed at a background app do not reproduce a physical system-menu click. The user subsequently performed that manual check and confirmed that opening Control Center closes the fan. This is user-confirmed behavior, not an automated system-menu test.

This revision originally introduced a mint **DS** badge. The redesign below replaces those letters with the app's own logo in both the fallback icon and completed Quick Look thumbnail. Direct Dock-surface verification remains subject to the automation limitation noted above.

## Newest-at-bottom fan and system appearance

The fan now opens with the newest entry at the bottom and older entries above. It returns to this end when reopened. File icons are 44 points rather than 64, with a fixed 58-point row stride. Filtering and alternate sort orders also put their highest-priority result nearest the Dock. The sort menu labels describe this orientation.

Ten core scenarios passed locally. New assertions cover bottom-first fan ordering, alternate sorts, a new arrival, filtered recent results, a single result, and no results. Existing newest-file and wheel-motion tests still pass.

The rebuilt sandboxed app passed signature verification and was installed locally. Checks using generated sample files confirmed:

- The latest sample file appears at the bottom on launch. Scrolling through the gaps and along the right edge reaches all 240 files, and reopening returns to the newest end.
- Bottom search leaves the window height stable and keeps one matching result near the controls. Command-Y previews the matching PNG.
- Clicking blank space does not open a file. Clicking a rotated filename opens the intended text document.
- A new generated test file appears at the bottom automatically while viewing that end of the fan. The test file was removed afterward.
- The updated welcome screen and fan render in light appearance; the fan also renders in dark appearance and a combined increased-contrast/reduced-transparency preview.
- Opaque, legible surfaces replace translucent materials in the accessibility preview.
- Quitting the preview and relaunching normally restores the user's saved folder and inherits the system appearance. No macOS appearance settings were changed.

Appearance checks use process-only launch arguments, not changes to the user's global settings. Native semantic colors and effective-appearance/display-option observers are used in the implementation. Floating controls use SwiftUI Liquid Glass on macOS 26 or later when compiled with a supporting SDK; older systems/builds use AppKit native materials. This revision originally used AppKit popover material for filename capsules; the translucency update below replaces it with native glass. See Apple's [adopting Liquid Glass guidance](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).

The new original logo shares vector artwork across the bundled icon, welcome screen, and Dock badge. Light/dark logo and recent-file composites were inspected at multiple sizes using a generic PDF icon. The [logo/badge rendering preview](images/dock-badge.png), [light fan](images/fan-light.png), [dark fan](images/fan-dark.png), and [accessibility preview](images/fan-high-contrast.png) contain generated samples or generic icons only. The bundle still uses traditional app icon assets, not Icon Composer clear/tinted variants.

These checks do not measure physical mouse-wheel smoothness or frame rate. Large-directory performance, live appearance transitions, and complete accessibility coverage remain release work.

## Dock-style translucency and file icons — November 16, 2026

Comparison used the user's captures of Apple's Downloads fan and DownloadScroller over the same background. The automation could not access the system Dock surface directly. The previous filename material looked flat and opaque, while Quick Look was supplying undecorated page thumbnails.

Filename capsules now use AppKit `NSGlassEffectView` with its regular legibility treatment, rounded corners, and native appearance adaptation. The item-count chip uses the same glass family as the floating controls. Older systems/builds use a lighter native menu material; text remains fully opaque. Reduce Transparency or Increase Contrast uses opaque system-color surfaces. Layer edge antialiasing and a short fade at the scroll boundaries soften rotated edges and cropped rows. Row geometry is reused during scrolling instead of resetting each row's frame size every frame.

Thumbnail requests now enable [Quick Look's icon mode](https://developer.apple.com/documentation/quicklookthumbnailing/qlthumbnailgenerator/request/iconmode), which asks the system for file-icon decorations. Document frames and shadows come from the installed macOS provider; the app no longer adds a second shadow. The fan remains at 44-point icons. Opening the fan leaves its labels neutral until a file is hovered or selected with the keyboard.

The sandboxed release app was rebuilt, its signature verified, and the installed copy checked with generated samples:

- Light → Dark → Follow System transitions updated the existing fan without restarting. Native appearance transitions were allowed to settle before comparing captures.
- Increase Contrast in dark appearance and Reduce Transparency in light appearance were checked separately; both produced opaque, legible capsules and controls.
- Scrolling through empty space and along the right edge reached the oldest of 240 files. Reopening returned to the newest end. Arrow-key selection showed the native accent highlight.
- Bottom search, PNG Quick Look, and clicking a rotated text-file label all worked. The expected sample text opened in TextEdit and the fan dismissed.
- The final normal launch restored the saved folder, inherited the current system appearance, and contained no contributor preview menu. Global macOS settings were not changed.

Contributor contrast previews explicitly request the fallback as well as selecting an appearance name: named high-contrast appearances can resolve to their base appearance when the global setting is off. Live changes to global accessibility/accent/glass preferences, physical-device frame-rate measurements, and runtime checks on older macOS remain release tasks. The app uses [public native glass APIs](https://developer.apple.com/documentation/appkit/nsglasseffectview); it does not reproduce private Dock rendering or promise identical rendering on every OS release.

## Release checklist still required

- Signed Xcode archive validation, provisioning, TestFlight, and App Review.
- Real runtime tests on macOS 14 and Intel hardware; a universal compile is not a runtime test.
- VoiceOver, keyboard-only onboarding, Reduce Motion, and live system appearance/accent/transparency/contrast changes beyond the app-only previews above.
- Multiple monitors, display resizing, full-screen Spaces, and all Dock positions.
- Very large directories and rapid changes while switching folders.
- Folder moves, deletion, expired/revoked bookmarks, network/cloud provider disconnects, and sleep/wake.
- Preview-provider coverage for PDF, images, video, audio, archives, and unsupported formats.
- Quarantined downloads: opening must continue to use normal macOS protections.
- Final store screenshots, privacy answers, age rating, export compliance, pricing, and support URLs.

No App Store approval, notarization, minimum-version runtime compatibility, or broad accessibility certification is implied by these checks.

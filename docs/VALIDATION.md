# Validation

This document distinguishes completed checks from release work. App Store readiness requires further testing and account setup.

## Clicking the regular Dock icon a second time — 20 November 2026

On the previous installed build, the user clicked the regular Dock icon while an independent observer recorded the Documents window. Twice it disappeared and returned about 0.2 seconds later. A separate AppKit event test reproduced one cause. A mouse-down inside the visible Dock with Finder identified as its target triggered outside dismissal. The following reopen consequently showed the regular fan again.

The updated build uses the mouse event's recorded screen position. Each fan handles a physical press once, including when an outside dismissal precedes the reopen. In the same event test, the regular fan closed, a duplicate reopen had no effect and the fixed launcher stayed open. All 50 Command Line Tools scenarios passed. The installed executable matched the signed release build, and the saved folder, launcher documents and fixed-right choice were verified.

Using Finder’s Open action on the installed app, the visible windows went from Downloads alone to both fans and back to Downloads alone. The Downloads window kept exactly the same frame in all three observations. Visibility was measured without reactivating DownloadScroller.

## Regular fan alignment with its Dock icon — 20 November 2026

- The previous layout reserved 560 points for a right-hand launcher even when it was closed. A 1920-point display test reproduced a bottom file icon at x = 1272 for a Dock click at x = 1496. The corrected layout places it at x = 1496. All 46 Command Line Tools scenarios passed, including placement with both fans, close tiles, side Docks and saved positions on multiple displays.
- On the installed app, the supplied screenshot and a measurement of the old Documents fan put the regular tile near x = 1498. That position was set as the initial saved anchor on this Mac. The rendered bottom folder icon measured x = 1498 when opened alone, with the Downloads launcher open and after Command-1 reopening. The two windows had an eight-point gap. The right launcher's frame was identical with Documents open and closed. Its search field and close-search control worked at the narrower width.
- The Dock accessibility surface timed out during this run. The installed measurements verify rendering against the screenshot and restoration through normal app controls. Physical Dock-click capture and physical secondary-display layouts were not exercised. The release signature, existing browsing bookmark, launcher identities and fixed-right choice were verified. Placement uses the display's usable bounds. [AppKit visible frame](https://developer.apple.com/documentation/appkit/nsscreen/visibleframe)

## Fixed-right launcher and copies between fans — 20 November 2026

- All 43 Command Line Tools scenarios passed. The new cases cover the right-hand launcher setting, opening order, narrower displays, copies in both directions, existing names, concurrent copies, recursive destinations and symlinked destination rows.
- A sandboxed review app opened two different folders. Opening, closing and reopening the regular fan left the fixed fan’s frame identical. Reopening the original launcher document through Finder closed only its own window. The installed application repeated the placement check with Documents and the existing badged Downloads copy launcher. The right window stayed at x = 1348 with width 560 on the tested display. Repeating Finder’s Open action on the installed application also toggled the regular fan. The Dock’s own accessibility surface timed out.
- In the review app, cancelling the receiving-folder sheet displayed **Copy cancelled**. Allowing copies through the picker produced a new `01 Original copy.txt` in the other fan and copied `Return from right.txt` into its sibling fan’s `Backlog` folder in the opposite direction. Both results matched their respective sources byte for byte, and all five original fixture files kept their hashes. These two transfers used **Copy to Open Fan**.
- A separate AppKit integration check sent a file URL through the receiving window’s drag callbacks. It exercised an empty fan's root and the on-screen bounds of a folder icon. Both destinations received the expected bytes. The window-scoped UI driver started a drag from a real filename and restored the source after Escape. It could not release the mouse in the other fan. Neither hands-on test file arrived before the review session closed, so a physical fan-to-fan mouse release remains unverified. [AppKit window drop registration](https://developer.apple.com/documentation/appkit/nswindow/registerfordraggedtypes%28_%3A%29)
- The installed executable matched the strictly verified release. The pinned launcher retained its file identity and document contents, the private launcher registry and main browsing bookmark retained their hashes, and the existing window-pin settings persisted. No personal folder needed a copy grant for installation.

## File drops and outside-click dismissal — 20 November 2026

- A hands-on drag from the regular fan delivered `02 Middle.txt` to a separate Finder folder. The 49-byte copy matched the original byte for byte. A drag from the launcher fan delivered `Invoice #2 résumé.txt` to a local Safari page, which displayed the expected filename, 36-byte size, and full file contents. All four original test files kept their original hashes.
- Both open fans disappeared after a click in the transparent area beside the launcher’s file. Repeating with **Keep window open** enabled for only the launcher left just that window visible. Cancelling an active drag restored the fan. These checks used a sandboxed review copy and generated files. The hands-on drops exercised the release after the window-scoped UI tool couldn’t complete a cross-app mouse release. On the installed app, opening Documents in Finder brought Finder to the front and left zero fans on screen with DownloadScroller still running.
- The source retains the original press and its folder access throughout the drag. Both floating fans yield the screen area to the receiving app. Apple specifies the original mouse-down event when starting an AppKit drag. [AppKit drag-session documentation](https://developer.apple.com/documentation/appkit/nsview/begindraggingsession%28with%3Aevent%3Asource%3A%29)
- All 38 Command Line Tools scenarios passed, including two regressions covering file URL export from independent folders and Escape during a drag. The installed executable matched the signed release build. Existing folder and launcher identities were preserved. The previously enabled Documents **Keep window open** setting was turned off.

## Independent launcher fans and live icon updates — 20 November 2026

- All 36 local scenarios passed with Command Line Tools, including 21 core and 15 app scenarios. The release build and its strict sandbox signature passed.
- In an isolated sandbox, two Finder launcher documents opened different folders together from a cold start. Switching between the two fans preserved each search and selection. Changing one launcher's folder, closing its window, or disabling it left the other fan available in the Window menu.
- Finder displayed each launcher's own newest image with the DownloadScroller badge. Adding a new image and then editing it in place updated that launcher's icon while both fans were closed. The sibling icon, launcher file identities, and document contents stayed the same. The app writes the artwork to the original launcher using [Apple’s file-icon API](https://developer.apple.com/documentation/appkit/nsworkspace/seticon%28_%3Aforfile%3Aoptions%3A%29).
- The installed build reopened Documents and the pinned Downloads copy in separate fans. Documents listed six items and Downloads listed 242 at the time of the check. The main fan's **Keep window open** choice persisted after restart.
- The Dock entry beside Trash pointed to the original Downloads copy file, which contained the updated custom icon. Finder rendered the artwork. The system Dock timed out during visual inspection, so its on-screen refresh is still unverified.

## Dock visibility and multiple launchers — 20 November 2026

Added **Dock & Launchers…** settings with a persistent normal-app Dock toggle, independent launcher profiles, creation/duplication, folder changes, enabled states, Finder reveal and fan opening. Launchers are registered `.downloadscroller` documents containing only a version and local profile UUID. Read-only folder bookmarks stay in private app storage; launcher activation preserves the normal startup bookmark. The menu-bar item remains configured in both activation modes. Pinning/removing files in the Dock is a user action.

- **32 CLT scenarios passed**: 20 core and 12 app. Added checks cover launcher persistence, independent duplicates, copied documents, name collisions and traversal, malformed/oversized/future/unknown files, corrupt registries, real write failures/rollback, and visibility preference persistence/failure recovery. Full XCTest and hosted CI were not run in this CLT environment.
- The release build and strict sandbox signature passed, as did plist/project syntax and diff whitespace checks. A scratch mutation reversing the enabled-launcher guard was rejected by the suite.
- Independent review found and resolved a transaction-order bug: refreshed bookmark persistence now precedes switching the live fan. Native testing found and fixed an oversized Settings window caused by List intrinsic sizing. [Review details](reviews/2026-11-20-dock-launchers.md).
- An isolated sandboxed app selected real generated folders through the picker, created three launchers, changed a duplicate to an empty folder, and verified original/duplicate independence. Disabling a document produced a settings error; re-enabling the same document restored operation. Finder file opening worked both while running and after quitting, with Doctor confirming the unique review process and signature.
- Turning Show app in Dock off persisted across restart. Settings reopened from the fan menu, remained usable, and its Quit button terminated the review app. Turning it on persisted too. These checks verify controls, accepted policy changes, persistence and recovery; they do not visually prove the system Dock icon's presence/absence.
- Activating another launcher's folder preserved the default bookmark hash. Normal app relaunch restored the default three-file folder. Search → Down → Escape restored all results; Quick Look displayed the generated text. A 240-file folder scrolled from newest to oldest. Original fixture hashes were unchanged.
- **Actual Dock and menu-bar system-surface interactions remain manual checks.** CUA Dock access returned `timeoutReached`. No Dock preference changes, restarts or Accessibility permission requests were used. The earlier successful-cross-app-drop coverage gap remains; it is not reported as fixed by this feature.
- Installed the tested build at `~/Applications/DownloadScroller.app` with rollback copies. Its executable matches the release build, its strict signature is valid, and its bookmark hash/sort preference are unchanged. It reopened all 239 current items and started from its actual launcher file as the sole running app process. Created **Downloads** and **Downloads copy** through Settings and left their files revealed in Finder for manual pinning. Normal Dock visibility remains on by default.
- Evidence and rollback bundles: `.build/dock-launchers-2026-11-20/`; successful native session: `review-3`. All three review sessions' owned scratch trees and containers were cleaned, retaining evidence. The existing verification skill now includes a source-grounded Dock/launcher recipe and unique test document registration.

## Dock-click positioning and file dragging — 16 November 2026

The fan now captures the pointer near the Dock when the app launches/reopens, chooses that display, and aligns the base file column near the click. Filenames face inward on the left side of the display. Screen bounds constrain placement; keyboard reopening and refresh retain the anchor. The menu-bar entry point keeps its separate anchor. This uses public pointer/display information, not private Dock inspection or Accessibility permissions, and does not continuously track Dock rearrangements.

File opening now occurs on mouse release. Moving a pressed filename/icon at least five points starts an AppKit dragging session carrying the real file URL. The source offers copying only, preserves the selected folder's read-only scope, suppresses outside-interaction dismissal during tracking, and closes an unpinned fan after a successful drop. Cancelled/rejected drags do not open files.

- All 18 local CLT scenarios passed: ten core, two Escape-state, and six placement scenarios. Placement covers left/right base alignment, count changes, edge clamping, secondary-display coordinates, side Docks, small displays, menu-bar positioning, and an auto-hidden Dock. These are geometry tests, not real Dock interactions.
- The sandboxed release build, strict signature, Xcode/plist syntax, and diff whitespace checks passed. Full XCTest/hosted CI were not run in this local CLT environment.
- An isolated sandboxed copy selected a generated three-file folder through the real picker. Clicking a filename and an icon opened the intended text in TextEdit. Search → Down → Escape restored all three results. Fixture hashes remained unchanged.
- CUA entered native drag tracking from a label/icon; Escape cancelled it without opening a file, after which search worked. Attempts to drop into a disposable Finder window did not deliver a file, and the synthesized drag remained in tracking until cancelled. **A successful receiving-app drop remains unverified.** This is not recorded as a passing copy/attachment test.
- Access to the system Dock through CUA timed out. **Actual Dock-click anchoring and left-side visual rendering remain unverified** despite passing geometry checks. Side Docks, multiple real displays, and moving a Dock icon need hands-on checks.
- The updated build was installed at `/Users/ganesh/Applications/DownloadScroller.app` and relaunched with all 217 items. Its executable matches the tested build, its strict signature is valid, and the saved bookmark fingerprint and sort preference are unchanged. The previous installed app and evidence remain in `.build/dock-drag-fix-2026-11-16/`; the isolated review app/container and fixture scratch tree were removed.

## Escape fix and review follow-up — 16 November 2026

Escape now uses one `LibraryModel.handleEscape` action from both the native key monitor and SwiftUI exit commands: clear the query, hide the empty search field, then dismiss. Marked-text cancellation remains with the input method. `FanMetrics` supplies the window and document's shared row spacing/top clearance, and an `Equatable` `FanScrollIdentity` replaces delimiter-joined strings. The native Xcode project includes the new metrics file.

- `bash scripts/test-app.sh` passed all ten existing core scenarios and two new app-state scenarios. The new tests are also configured as a SwiftPM XCTest target for full Xcode; local validation used the CLT adapter because XCTest is unavailable here.
- In a scratch copy, replacing the Escape action with unconditional dismissal caused the new regression test to fail because the query was retained. Product source was never mutated by this check; the scratch copy was removed.
- The sandboxed release build and strict signature check passed. Xcode project/plist syntax and `git diff --check` passed. The new changes have not been run in hosted CI yet.
- The real native UI passed search → Down/Up → Escape for both matching and empty results. Focused text input, blank-canvas focus, and returning from Quick Look also clear the query correctly. A second Escape hides the empty search field. Menu/Quick Look Escape closes that menu/preview without clearing the query underneath; the active file-type filter is preserved when clearing search.
- The 240-file sample fan still scrolls through blank space and both faded edges, reaches its oldest entry, and returns to newest on Command-1. Name sorting and image filtering update correctly. Long filenames, the three-file fixture folder, and the empty-folder state were checked after sharing the geometry.
- `/Users/ganesh/Applications/DownloadScroller.app` was replaced with the tested build and relaunched normally. The installed executable hash matches the built bundle; its strict signature is valid. A final search/arrow/Escape check in the installed copy restored all 217 items, and search was closed afterward. The saved bookmark fingerprint and sort preference match their pre-update values.
- Test copies and their unique sandbox containers were removed. Generated-file screenshots, AX snapshots, logs and a rollback copy of the prior installed app remain in `.build/escape-fix-2026-11-16/` (ignored by Git).

The live test is essential: the unit scenarios cover the shared action's state changes, not AppKit event routing. Physical wheel frame timing, VoiceOver, actual IME composition, Reduce Motion/system preference propagation, and older-system/Intel runtime coverage remain separate release checks. Global macOS settings were not changed.

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

# Validation

This document distinguishes completed checks from release work. App Store readiness requires further testing and account setup.

## Local checks completed

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

The local `swift test` command cannot run because Apple's Command Line Tools installation does not contain XCTest. `scripts/test-core.sh` provides a small assertion adapter and executes the same five test methods. CI uses full Xcode and runs real XCTest plus the native universal application build.

## CI verification

The initial native version passed all five XCTest cases and the arm64 + x86_64 Xcode release build on a GitHub-hosted macOS 15 runner with Xcode 16.4 / Swift 6.1.2. The same workflow runs for subsequent revisions. Check the [latest workflow result](https://github.com/mganesh1610/DownloadScroller/actions/workflows/ci.yml) for the current commit.

## Known preview-provider behavior

Text and PNG Quick Look were verified. SVG and CSV preview attempts on this Mac displayed a loading indicator rather than promptly rendering, while SVG thumbnails did render. CSV was rechecked after the focus-handling fix and still stalled. Quick Look is delegated to installed macOS providers; these formats need further testing before claiming broad preview coverage.

## Release checklist still required

- Signed Xcode archive validation, provisioning, TestFlight, and App Review.
- Real runtime tests on macOS 14 and Intel hardware; a universal compile is not a runtime test.
- VoiceOver, keyboard-only onboarding, Reduce Motion and Increase Contrast.
- Multiple monitors, display resizing, full-screen Spaces, and all Dock positions.
- Very large directories and rapid changes while switching folders.
- Folder moves, deletion, expired/revoked bookmarks, network/cloud provider disconnects, and sleep/wake.
- Preview-provider coverage for PDF, images, video, audio, archives, and unsupported formats.
- Quarantined downloads: opening must continue to use normal macOS protections.
- Final store screenshots, privacy answers, age rating, export compliance, pricing, and support URLs.

No App Store approval, notarization, minimum-version runtime compatibility, or broad accessibility certification is implied by these checks.

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

The local `swift test` command cannot run because Apple's Command Line Tools installation does not contain XCTest. `scripts/test-core.sh` provides a small assertion adapter and executes the same five test methods. CI uses full Xcode and runs real XCTest plus the native universal application build.

## Known preview-provider behavior

Text Quick Look was verified. SVG and CSV preview attempts on this Mac displayed a loading indicator rather than promptly rendering, while SVG thumbnails did render. Quick Look is delegated to installed macOS providers; these formats need further testing before claiming broad preview coverage.

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

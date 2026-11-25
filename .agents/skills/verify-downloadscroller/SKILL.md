---
name: verify-downloadscroller
description: Verify DownloadScroller's native macOS fan, folder access, search, file actions, and lifecycle using an isolated sandboxed app and CUA. Use after UI changes or for a release review.
---

# Verify DownloadScroller

## Launch

The primary surface is a native AppKit/SwiftUI app, not a website. Require macOS 14+, Swift 6+ and CUA native-app access. Run from the repository root:

```sh
bash scripts/test-app.sh
bash scripts/build-app.sh
.agents/skills/verify-downloadscroller/helpers/session.py prepare --evidence .build/verification/current
```

Choose a new evidence directory for each run; `prepare` refuses an existing session. It copies the built app, gives it a unique bundle identity, display name, launcher extension/type and signature, signs with the production sandbox entitlements, and creates three disposable text files plus an empty folder. It records paths and the pinned revision in `session.json`. The original app and its preferences are not used. Unique document registration prevents review launchers from opening the production app.

Read `session.json`. In CUA, initialize with `cua.getApp()` using its exact `bundle` path. After a context reset use `await cua.rewriteDocumentation()` first. An onboarding window with AX buttons **Choose Downloads folder** and **Take a look with sample files** proves readiness. A process existing is insufficient. Do not open the production app for destructive folder-state tests.

## Doctor

```sh
.agents/skills/verify-downloadscroller/helpers/session.py doctor --evidence .build/verification/current
```

This read-only check requires exactly one process at the owned bundle's executable path, a valid signature, and an unchanged executable hash. It prints the revision, unique bundle ID and PID. Run after launch and whenever a UI step looks wrong. Then get a fresh CUA accessibility tree to check the expected app/window. A valid process does not prove a picker or preview is usable.

## Drive

Read [the feature index](features/README.md) first. Use only CUA for native UI. Get a fresh AX tree after every action batch and resolve current element indices by their accessible labels; never cache numeric indices across actions.

```js
let reviewApp = await cua.getApp(session.bundle);
const state = await reviewApp.getAXState({emit:false, disableDiffing:true});
const chooseIndex = Number(state.match(/^\s*(\d+) button Choose Downloads folder$/m)[1]);
await reviewApp.click(chooseIndex);
await reviewApp.getAXState();
await reviewApp.pressKey("super+shift+g");
const goTo = await reviewApp.getAXState({emit:false, disableDiffing:true});
const pathIndex = Number(goTo.match(/^\s*(\d+) text field .*ID: PathTextField/m)[1]);
await reviewApp.setValue(pathIndex, session.fixtures);
await reviewApp.pressKey("Return");
await reviewApp.getAXState();
// Resolve and click the button named Choose folder. Expect 3 items and the three fixture filenames.
```

`session` is parsed from the manifest; indices are resolved from the current tree. All real labels, shortcuts, expected content and edge cases are in the feature files. Scroll coordinates must come from a current screenshot: use the visibly blank area inside the fan, not another app's window. CUA scroll is a functional input check, not a physical mouse-wheel frame-rate benchmark.

## Evidence

Keep logs, action descriptions, AX text and screenshots under the chosen evidence directory, outside `scratch`. CUA `getAXState({emit:false})` and `getScreenshot({emit:false})` can be saved with `node:fs/promises`. Save before/after states and name the feature/entry point. Only generated fixtures may appear in repo evidence.

Exercise real picker, menu, keyboard, search and file-open paths. Do not call model setters. For folder access, verify displayed filenames, quit/relaunch persistence, and disconnect/relaunch onboarding. For live updates, write a new fixture externally and observe it without Refresh. Hash fixtures before/after browsing to verify the app did not modify them. File opening must show the fixture text in the receiving app. Missing providers or inaccessible system surfaces are blocked coverage, never a pass through a different entry point.

`bash scripts/test-app.sh` runs 24 core scenarios and 29 app scenarios using the Command Line Tools assertion adapter. Coverage includes file copies, name collisions, drag initiation and URL export, Escape, saved Dock positions on separate displays, repeat-click dismissal, regular icon alignment, fixed-right placement, independent window settings, replacement of a watched folder and Dock visibility. Full `swift test` needs XCTest from full Xcode. Replay search → arrow → Escape through CUA to exercise native event routing. Open the actual launcher files from Finder to exercise Launch Services. Performance claims need measured release paths and the benchmark-checklist skill.

## Cleanup

Close only test documents/windows opened during this run. Quit the exact review app using CUA Command-Q, then:

```sh
.agents/skills/verify-downloadscroller/helpers/session.py cleanup --evidence .build/verification/current
```

Cleanup refuses a running review process. It removes only the marked scratch tree and the unique review bundle's sandbox container. macOS may retain protected container metadata; report this if printed. Evidence and `session.json` survive. Confirm `cleanup.txt` and proof artifacts still exist. Never kill by process name, clear production defaults, or delete a user's files. After a failed iteration, use this same cleanup before preparing a fresh session.

## Helpers

`helpers/session.py` is executable and supports the three invocations above. It does not launch or drive UI, read production preferences, or require external packages. A unique bundle ID isolates bookmarks/preferences from the installed app; signing changes executable signature bytes, so the manifest stores the source and re-signed hashes separately.

Use `/maintain-verification-skill` to keep the map current after behavior changes.

# Dock visibility and multiple launchers

Date: 20 November 2026. Status: implemented and installed locally. Native launcher journeys verified; actual Dock pin/click and menu-bar system-surface checks remain manual.

The follow-up recorded in [validation](../VALIDATION.md) supersedes the original single-window and static launcher artwork decisions below.

## Intended result

DownloadScroller remains one native, sandboxed app. A user can keep its normal running-app icon, use launcher files beside the Trash, or use both. Multiple launchers can point to the same folder or to different folders. The menu-bar button remains available in every mode so settings, opening the fan, and quitting are always reachable.

The existing installation, saved Downloads bookmark, sort preference, fan placement, scrolling, search, Quick Look, and file dragging must survive the update. Existing worktree edits are the starting point, not changes to discard. The unrelated PDF in the worktree is outside this feature.

## User controls and journeys

1. **Dock & Launchers…** opens a native settings window from the fan's folder menu, onboarding, and the app menu. It must also work when the app's normal Dock icon is hidden.
2. **Show app in Dock** defaults to on for existing and new users. Turning it off changes the running app to accessory mode; turning it on restores regular mode. Remember the choice across launches and roll back the preference if macOS rejects the change. The menu-bar button remains present.
3. **Create launcher** accepts a name and a folder. The current real folder is the default where available; the folder picker also supports selecting another folder without changing the current fan. Generated sample data cannot become a permanent launcher accidentally.
4. **Duplicate** creates a separate launcher identity and file for the selected launcher's folder. Names are readable, collisions get a suffix, and existing files are never overwritten. A user can change the duplicate's folder independently.
5. **Enabled** can be switched off for an individual launcher. Its pinned shortcut remains visible, but opening it explains that it is disabled and directs the user to settings. Re-enabling restores operation without a new shortcut.
6. **Open fan**, **Choose folder…**, and **Show in Finder** operate on the selected launcher. Finder reveals the actual launcher file so the user can drag it between the Dock divider and Trash.
7. Opening a launcher from Finder or the Dock starts the app if needed, loads that launcher's authorized folder, resets the fan's query/selection, and opens the fan near the initiating Dock click when one is available. A launcher can be opened repeatedly while the app is already running.
8. One fan is active at a time. Opening a different launcher switches the fan's folder; it does not create additional background app processes. The existing default-folder bookmark remains the normal startup preference.

## macOS constraints shown in the UI

- Apps belong in the Dock's application area; launcher documents belong in its files/folders area.
- The app changes its own activation policy. It does not rewrite Dock preferences, restart the Dock, use private Dock interfaces, or request Accessibility access.
- Pinning/removing/reordering launcher shortcuts is a user Dock action. An Enabled toggle changes what a launcher does, not whether its pinned icon is drawn.
- A manually pinned app shortcut can remain after the running icon is hidden. Explain this once in settings.
- Launcher icons use stable app artwork; the existing running-app icon continues to show the latest completed file. Dynamic thumbnails on each launcher are outside this change.

## Design and ownership

### Launcher storage module

Add a small Foundation module with an interface for listing, creating, duplicating, updating, locating, and resolving launchers. It owns persistence, version validation, names, collision handling, and document parsing. Callers do not assemble paths or decode the registry themselves.

Each profile has a UUID, name, read-only security-scoped folder bookmark, enabled state, and managed document filename. Profiles live in the app's sandbox Application Support directory. The movable `.downloadscroller` document contains only a format version and profile UUID—no filesystem path, folder bookmark, or executable instruction. Copying the document refers to the same profile; the app's Duplicate action creates an independently editable profile.

Registry writes are atomic. A creation failure must not overwrite an older launcher or discard the existing registry. A corrupt registry is reported without resetting it. Read external launcher documents as untrusted data: require a local regular file, the expected extension, a bounded size, a supported version, and a profile identifier present in the local registry. Disabled, unknown, and malformed launchers produce distinct actionable errors.

### Folder access

Reuse the existing security-scoped bookmark mechanism. Create launcher bookmarks with `.securityScopeAllowOnlyReadAccess`; retain the current sandbox entitlements. Launcher creation writes only inside the app's own container, so it needs no additional filesystem entitlement.

Factor the existing bookmark restore path so both default-folder restoration and launcher activation use the same resolution/scope handling. Keep a resolved scope alive while the scan/watcher uses it; release the previous scope only after its pending scan finishes. Refresh stale bookmarks in the owning profile. If resolving a launcher fails, keep the existing fan's folder intact and show a reconnect action in settings.

### Settings and activation

A dedicated settings/controller module owns the visibility preference, launcher list, creation/picker dialogs, errors, and activation requests. A SwiftUI settings view uses native form/list controls, keyboard-accessible buttons, visible selection, and useful empty/disabled states. The app delegate connects settings callbacks to the existing shelf controller and keeps file-event routing separate from storage.

Register a unique exported document type and extension in `Info.plist`. Handle both startup document events and events delivered to an already-running app. Queue events received before controllers are ready; reply to the system only after handling or reporting the failure. Do not route unrecognized files into the user's default editor.

## Implementation sequence

| Step | Deliverable | Acceptance evidence |
| --- | --- | --- |
| 1 | Save the current source baseline and this plan | Existing edits retained; implementation diff can be isolated |
| 2 | Launcher storage and document format | Create/reload/open, duplicate independence, failure and invalid-document checks |
| 3 | Shared bookmark activation and visibility preference | Folder scopes retained correctly; preference persists; default bookmark remains unchanged |
| 4 | Native Dock & Launchers settings | Create, duplicate, enable/disable, change folder, reveal and open through visible controls |
| 5 | Document registration and app lifecycle | Opening a real launcher while running and after quitting reaches the intended folder |
| 6 | Independent code review and regression checks | Required findings resolved; meaningful test mutation fails |
| 7 | Isolated sandboxed native verification | Generated files, picker, launchers, persistence, search, Quick Look, long/empty folder paths |
| 8 | Update docs and local installation | Signed build installed with rollback copy; production bookmark/sort preserved |

## Testing interfaces and expected coverage

- **Launcher storage interface:** test against a disposable real directory. Verify durable names/identities, same-folder duplicates, independently changed bookmarks/enabled flags, restart persistence, copying a document, collision handling, corrupted registry preservation, malformed/oversized/unknown-version documents, missing profiles, and disabled launchers. This does not prove Launch Services or Dock behavior.
- **Visibility preference interface:** use an isolated defaults domain and a controllable activation-policy operation. Verify default on, successful toggle persistence, failed policy change rollback, and relaunch restoration. Native UI must separately verify recovery through settings in accessory mode.
- **Existing library interface:** retain the current file-query, wheel, Escape, and placement scenarios. Add only behavior checks justified by the changed bookmark path, without testing private methods.
- **Native user journeys:** select fixture folders through the real picker; create two launchers for one folder and one for another; disable/re-enable; switch folders; quit/reopen using an actual launcher document; toggle Dock mode both ways; check search → arrow → Escape and Quick Look; verify fixture hashes stay unchanged.
- **Actual Dock checks:** attempt the real Dock surface and pin/click distinct launcher files if CUA exposes it. If it remains inaccessible, record that precise limitation rather than treating a Finder launch or geometry test as a Dock pass. Likewise preserve the existing unverified cross-app file-drop limitation.

The review helper must give its app a unique document extension/type as well as a unique bundle ID, preventing test launchers from being opened by the installed production app. Keep evidence outside disposable scratch and clean only owned review processes, fixtures, and containers.

## Skills and review approach

- Matt Pocock **codebase-design**: keep persistence/validation behind one useful interface and test observable behavior at that interface. No repo-wide issue-tracker setup is needed for this local feature.
- Addy Osmani **code-review-and-quality**: inspect correctness, readability, architecture, security, and performance; use an independent reviewer; prove at least one regression test rejects a deliberately broken condition in a scratch source copy.
- Lauren Tan's **Pstack** verification skills and the project's **verify-downloadscroller**: maintain source-grounded feature recipes, exercise native UI in an isolated sandboxed app, preserve evidence, and distinguish missing tool coverage from a passing feature.
- The full Matt Pocock TDD workflow requires separate user agreement on test interfaces. It is not being invoked merely because the pack is available; the module-design skill is the relevant selected workflow here.

## Release and rollback

Build with the existing Swift/CLT scripts and regenerate the Xcode project for added source files. Run required tests, check plist/project syntax, and verify the sandbox signature. Preserve a rollback copy of the installed app and fingerprints of the current folder bookmark and sort preference. Replace the local app only after the isolated checks and review. No GitHub publication, commit, push, or release is required by this request.

## Progress

- [x] Inspected current source and saved a baseline under `.build/dock-launchers-2026-11-20/baseline/`.
- [x] Wrote the implementation plan before product edits.
- [x] Implemented storage, folder access, preferences, settings, and launch handling.
- [x] Completed independent review and required checks: 32 CLT scenarios, sandboxed release build, signature/plist/project checks, and a rejected test mutation.
- [x] Completed isolated native verification and documented limitations: three independent launchers, different folders, enable/disable, Finder warm/cold activation, Dock toggle persistence/recovery, default-folder preservation, search, Quick Look, and 240-file scrolling. CUA cannot reach the actual Dock; no actual pin/click or menu-bar-system-surface pass is claimed.
- [x] Updated the local installed app and verified preserved settings. Created Downloads and Downloads copy launchers and revealed them in Finder; the user can pin either or both. Normal app Dock visibility remains on.

## Results and evidence

See [validation](../VALIDATION.md) and [review](../reviews/2026-11-20-dock-launchers.md). Local evidence is in `.build/dock-launchers-2026-11-20/`; `review-3` contains the successful isolated native run. Review scratch apps/fixtures and containers were cleaned; evidence survives. `installed-before.app` and `installed-replaced.app` are rollback copies. The current app path is `~/Applications/DownloadScroller.app`.

The final build preserves the previous bookmark hash and sort preference, opens all 239 current Downloads items, and is the sole running DownloadScroller process after launching its document from Finder. The installed executable matches the tested release build. No external publication occurred.

Platform references: [Apple Dock guide](https://support.apple.com/en-jo/guide/mac-help/mh35859/mac), [activation policy](https://developer.apple.com/documentation/appkit/nsapplication/setactivationpolicy(_:)), [document types](https://developer.apple.com/documentation/BundleResources/Information-Property-List/CFBundleDocumentTypes), and [exported types](https://developer.apple.com/documentation/bundleresources/information-property-list/utexportedtypedeclarations).

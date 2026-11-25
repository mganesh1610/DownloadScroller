# Dock launchers implementation review

20 November 2026. Review compared the feature against the saved dirty-worktree baseline, preserving earlier fan-positioning and file-dragging work.

## Required finding, resolved

The first implementation switched LibraryModel's folder before saving a refreshed stale bookmark. A registry write failure therefore reported a failed launch after changing the live fan. Resolution now acquires access, persists refreshed data through the owning store, and only then switches the live folder. A failed save releases the new scope and leaves the original fan intact. An independent reviewer rechecked this change and found no remaining actionable feature defects.

## Additional findings addressed

- Real filesystem failure tests now cover document creation failure, failed atomic registry writes, rollback of only the newly created document, and preservation of existing registry/document bytes.
- Command-W closes the settings window when it is key. Settings provides a Quit button for accessory-mode recovery.
- Native verification found NSHostingView expanding the settings window to the List's intrinsic height. Disabling hosting-driven window sizing retains the explicit resizable native window bounds. A fresh isolated run verified all controls fit and the real folder picker works.
- Review copies receive a unique launcher extension and exported type as well as a unique bundle ID; production document associations remain separate.

## Evidence

- 20 core and 12 app scenarios passed with the CLT adapter. The signed sandboxed release build, strict signature, plist/project syntax and whitespace checks passed.
- Inverting the enabled-launcher guard in a scratch source copy caused the suite to fail. Product source was not mutated.
- Real native picker, creation, duplicate folder changes, disable/re-enable, actual document opening in Finder while running and after quitting, accessory-mode settings/quit recovery and persistence, default-folder preservation, search/arrow/Escape, Quick Look and 240-file scrolling passed. Fixture content hashes were unchanged.
- Installed executable matches the tested build; production bookmark fingerprint and sort preference match their pre-update values. The actual installed bundle opened its launcher and displayed 239 items. Two production launchers were created through visible settings controls.

Local logs, snapshots, hashes, baseline and rollback bundles are in `.build/dock-launchers-2026-11-20/`. No user document content was saved as verification evidence.

## Remaining coverage and pre-existing concerns

- No unit regression directly forces a stale bookmark's `saveRefresh` callback to throw; the ordering/scope fix was independently reviewed. Core persistence failures are exercised against real directories, and normal bookmark activation/default preservation were exercised natively.
- Actual Dock pinning, Dock-icon visibility/anchoring and menu-bar system-surface recovery require hands-on checks: CUA's Dock access returned `timeoutReached`. A passing Finder launch or toggle state is not a passing Dock interaction.
- Successful cross-app file dropping remains unverified from the earlier drag implementation; this change does not claim to resolve that tooling limitation.
- A pre-existing scope-lifetime concern remains: successive refreshes replace the tracked scan worker; an earlier cancelled worker blocked in filesystem I/O could outlive the scope retained for the newest worker. This was present in the saved baseline and was not changed by this feature.
- Full XCTest/hosted CI, older macOS, Intel runtime, physical wheel performance and VoiceOver were not rerun locally.

# System appearance

Native materials and semantic colors follow system appearance and accessibility choices.

## Sub-features

- `appearance-native`: light/dark, transparent capsules, smooth edges.
- `appearance-live`: change while fan remains open.
- `appearance-accessibility`: Reduce Transparency, Increase Contrast, Reduce Motion and keyboard/VoiceOver.

## How to get to it (user POV)

Normal app inherits macOS appearance. System Settings controls the user's appearance/accessibility preferences. Contributor process-only preview flags are documented in README; they are substitutes for visual inspection, not system-preference propagation tests.

## Driving it with CUA

Preconditions: healthy review sample fan, host settings recorded, no permission to change unrelated user preferences inferred from a review request.

- Capture normal native appearance over a real backdrop. Inspect label corners and file frames at top/middle/bottom, with search open and closed.
- If launch arguments are available in the approved development harness, `--preview-controls` enables Preview Appearance → Light/Dark/Follow System; inspect live switching in the same window. Record the override explicitly.
- Test global Reduce Motion/Transparency/Increase Contrast only when those settings are already active or the user authorizes changing them. Record actual values and restore them afterward. Process-only preview flags prove fallback rendering, not observation of a system change.
- For VoiceOver, enable only with authorization and verify focused file announcements and activation. AX labels alone are not a VoiceOver pass.

## Gotchas

- Screenshots may flatten transparent pixels; inspect native view configuration and real backdrop, not just PNG alpha.
- Compile success with Xcode 16/26 does not prove macOS 14 fallback runtime. A second OS/Intel test remains separate coverage.
- Physical wheel motion and Reduce Motion need real user-path verification; deterministic core tests alone do not satisfy that journey.

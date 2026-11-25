# DownloadScroller verification map

Use the isolated app prepared by [the verification skill](../SKILL.md). Start from its onboarding screen, or state the selected fixture/sample folder. Run Doctor before driving and after surprises. Prefer current AX labels; coordinate actions require a current screenshot. Capture action plus resulting state and relevant filesystem side effects. Preserve all evidence during cleanup.

Each entry point is separate coverage. Do not call a physical wheel, Dock, Control Center, VoiceOver, or global accessibility test passed based on a keyboard or process-only preview substitute. Report unmet preconditions explicitly.

- [Folder access](folder-access.md): picker, cancellation, live arrivals, restart, disconnect, empty folder.
- [Fan browsing](fan-browsing.md): all items, gaps/edges, search, sort/filter, keyboard.
- [File actions](file-actions.md) covers opening, Quick Look, reveal, outgoing drags and copies between fans.
- [Window lifecycle](window-lifecycle.md): entry points, dismissal, pinning, Dock identity.
- [Dock and launchers](dock-launchers.md): visibility, creation, duplicates, folder changes, disabled documents, warm/cold file activation.
- [System appearance](system-appearance.md): native materials, system preferences, accessibility.

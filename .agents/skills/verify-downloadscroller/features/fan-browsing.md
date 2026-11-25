# Fan browsing

Browse every item, with the highest-priority result at the bottom and search near the controls.

## Sub-features

- `fan-endpoints`: all 240 sample items and newest-at-bottom.
- `fan-gap-scroll`: blank area, between rows, top/bottom faded edges.
- `fan-search`: button/Command-F, matching and empty results, clear.
- `fan-query`: alternate sort/filter and selection.

## How to get to it (user POV)

Try Sample Files on onboarding. Search files button or Command-F. Sort by and Filter by kind in Folder options. Arrow keys select; Command-1 reopens.

## Driving it with CUA

Preconditions: healthy review app, sample folder selected using the AX button Take a look with sample files.

- Capture newest visible files and 240 items. Scroll up repeatedly from screenshot-derived blank coordinates inside the fan until the oldest files appear; scroll down to newest. Repeat between filenames and along both faded boundaries. Blank clicks must not open a file.
- Press `super+1`; newest must be back at the bottom. Press Up; a visible row must be selected without changing geometry.
- Click Search files; capture the search field at the bottom. Type `coastal`; expect one PNG. Close search, open via `super+f`, and repeat. Use `zznoresultzz`; expect No matching files; Show all files must recover.
- With a nonempty search, press Down to leave text editing, then Escape. Expect an empty field and all results for the active filter, with the fan still available. A second Escape hides the empty search field; a third dismisses the fan. Repeat with Up, no matching results, focused text editing, and focus on the blank canvas.
- Open Folder options while a query is active, then Escape: only the menu should close. Open Quick Look with Command-Y, then Escape: only the preview should close. A subsequent Escape in the fan clears the query.
- Change Sort by to Name, then filter Images. Verify highest-priority matching result sits at the bottom, count updates, and switching All files/newest restores the initial list.

## Gotchas

- Scroll input synthesized by CUA does not prove regular-wheel smoothness or trackpad momentum. Test actual devices separately.
- Accessibility only enumerates visible/buffered rows; scroll to prove endpoints instead of expecting 240 AX elements.
- Escape after keyboard selection is a regression guard. App-state tests alone do not prove native event routing; keep this live journey.

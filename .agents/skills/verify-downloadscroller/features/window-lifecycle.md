# Window lifecycle

The fan opens from its app, closes on outside interaction, and optionally remains pinned.

## Sub-features

- `window-entry`: Dock, menu-bar button, Command-1; Dock-click anchoring and inward-facing filenames.
- `window-dismiss`: outside app, system menu, Escape, close button.
- `window-pin`: Keep window open overrides outside dismissal.
- `dock-identity`: newest completed file plus logo badge.

## How to get to it (user POV)

Dock app icon or Open DownloadScroller status item. Folder options → Keep window open / Unpin window. Close window button, Escape or Command-W.

## Driving it with CUA

Preconditions: selected review folder; known unpinned state; healthy review app.

- Open the regular and launcher fans with their default settings. Switch between them. Click Finder, then check that both fans have closed. Repeat by clicking blank canvas beside a filename. Pin one fan using **Keep window open**, repeat, and verify that only the pinned fan stays visible.
- Open app's own Folder options and cancel a folder picker; neither should dismiss the fan. Open/close Quick Look and confirm fan persists.
- Exercise menu-bar and Dock entry points only if CUA exposes their actual controls. System Control Center click requires a real system surface; report inaccessible tooling rather than substituting an app switch.
- On an accessible Dock surface, click the launcher chosen with **Fix on right**. Its file column should sit at the bottom right. Click the regular icon, then each icon again. Only the corresponding fan should toggle. Compare the fixed window’s frame as the regular fan opens and closes. For other launchers, check the click anchor, inward-facing labels and screen bounds. Test side Docks and another display separately.
- For a repeat-click regression, observe the regular fan for at least a second after the second click. It can disappear briefly and reopen. Check window visibility without activating the app again, and record whether the clicks came from the physical Dock or from Finder.
- With a regular tile near the right end of the application section, measure the bottom file icon’s center against that tile. Repeat with the fixed fan open, after closing and reopening with Command-1, and after relaunch. Check that the fixed fan’s file column remains in place and its search and folder controls fit. Record whether the reference point came from an actual Dock click or from a supplied screenshot.
- With a generated newest file, inspect the running Dock icon and logo badge; apply search/filter and confirm icon identity remains based on whole folder. Capture only if Dock is reachable.

## Gotchas

- The app's own menu is not a system-menu dismissal test. Pinning deliberately changes outside-click behavior.
- The host CUA may not expose Dock/Control Center. Prior user confirmation is historical, not fresh automated proof.
- Closing fan does not quit the app; cleanup requires Command-Q of the exact review instance.

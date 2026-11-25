# File actions

Open, preview, reveal or copy the intended file. Verify destination and original contents for every copy.

## Sub-features

- `file-open`: single click on release, Return and menu action.
- `file-drag`: filename/icon drag exports a native file URL for copying or attaching.
- `fan-copy` covers a copy to another open fan's root or an immediate folder row.
- `file-preview`: Space, Command-Y and row context menu.
- `file-reveal`: Show in Finder and open folder.

## How to get to it (user POV)

Click a file label/icon, Return, File → Open Selected File; Space/Command-Y or row context menu Quick Look; Shift-Command-R, Show in Finder, or bottom Open in Finder.

## Driving it with CUA

Preconditions: real fixture folder or generated samples, healthy review app.

- Search `Original`; press Down, then Space. Quick Look must display the fixture text. Close preview; fan remains. Repeat Command-Y from a focused search field and context-menu Quick Look, treating each as separate coverage.
- Search a text fixture then click its label. The configured text editor must display the exact fixture text; an unpinned fan should close. Close only this test document without edits.
- From a selected fixture, press `super+shift+r`. Finder must select that exact filename. Test Open in Finder separately for the containing folder.
- Open a regular fan and a launcher fan for different fixture folders. Begin dragging a filename or icon. The source yields while the other fan stays visible as a destination. Drop into a disposable Finder folder and compare source and destination hashes. An unpinned source closes after an external drop. An explicitly pinned fan stays open. Escape restores a cancelled drag. Test a local attachment target separately.
- With two open fans, drag from the regular fan onto a folder row in the launcher, then drag from the launcher onto the regular fan’s folder name. Confirm the first **Allow copies** sheet for each recipient. Compare the bytes at the two exact destinations and verify both windows remain open. Test the **Copy to Open Fan** context menu separately, including cancellation of the grant and a filename collision.
- Save action/result AX/screenshots and unchanged fixture hashes.

## Gotchas

- CSV/SVG Quick Look may stall on the host provider; record blocked format coverage. Do not equate thumbnails with working previews.
- Space in a focused text field inserts a space. Leave editing first, or use Command-Y.
- Cross-window drag synthesis may not be supported by the host CUA. A cancelled drag or a correct pasteboard alone is not proof of a successful receiving-app drop; report that coverage explicitly.
- Never close unrelated editor/Finder windows. A menu click passing does not prove the rotated row's hit target.

# Folder access

Browsing remembers a read-only bookmark. A fan requests a separate grant the first time it receives a file copy.

## Sub-features

- `folder-pick`: real sandbox picker grants access.
- `folder-live`: additions/removals appear automatically.
- `folder-restart`: bookmark survives quit/relaunch.
- `folder-disconnect`: disconnect returns to onboarding across restart.
- `folder-empty`: empty directory gives a usable empty state.

## How to get to it (user POV)

Choose Downloads Folder… on onboarding, Choose folder… in Folder options, or Shift-Command-O. Disconnect folder is in Folder options.

## Driving it with CUA

Preconditions: healthy isolated session; manifest's `fixtures` has 01 Original.txt, 02 Middle.txt, 03 Recent.txt; `empty` is empty.

- Click the AX button Choose Downloads folder (or press `super+shift+o`), press `super+shift+g`, type the manifest fixture path, Return, then resolve Choose folder from current AX and click it. Expect all three filenames and 3 items.
- Reopen picker and cancel; the same folder must remain usable.
- Externally create `04 Arrival.txt` in the owned fixture folder with text `Verification arrival`. Do not refresh. Expect 4 items and the new file nearest the bottom in newest sort. Remove only that generated arrival; expect 3 again.
- Quit via `super+q`; reacquire exact bundle via `cua.getApp`. Expect three files without another picker.
- Choose empty folder through the real picker. Expect This folder is empty and working Folder options.
- Use the other fan to send a file here. Cancel **Allow copies** and check that nothing was created. Repeat, confirm this exact destination folder, and verify the new file. A second copy into this folder or one of its immediate subfolders must work with the saved grant.
- Choose Disconnect folder. Expect onboarding, then quit/relaunch and expect onboarding again. Compare fixture hashes with the initial values.

## Gotchas

- Never use personal Downloads for disconnect/restart tests. Separate bundle identity is mandatory.
- Missing/deleted bookmark targets and revoked permissions need separate disposable-folder cases; three happy-path files do not cover them.
- Content-only edits may require Command-R by documented design; directory arrivals must not.

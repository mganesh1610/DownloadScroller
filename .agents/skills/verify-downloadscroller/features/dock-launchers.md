# Dock and launchers

One app can expose its normal Dock icon and multiple launcher documents for the Dock's files/folders area. Open launcher windows can stay visible together.

## Entry points and controls

Onboarding **Dock & Launchers**, folder menu **Dock & Launchers…**, or Command-comma. The window is titled **Dock & Launchers**. Controls: **Show app in Dock**, **Launcher name**, **Choose launcher folder**, **Create launcher**, each row's **Enable NAME**, **Open fan**, **Duplicate**, **Change folder…**, **Show in Finder**, **Quit DownloadScroller**.

## Native checks

Open **Privacy Policy** in the settings footer and verify the default browser shows DownloadScroller’s public policy, including its description of permission to copy into a folder.

1. Start the isolated app. Open settings from onboarding. Create must be disabled until a real folder is selected. The window and its bottom controls must fit on screen; a scrollable list must not expand the window's intrinsic height.
2. Choose launcher folder → real picker → Command-Shift-G → manifest `fixtures` → Choose folder. Set a recognizable name and create. Verify the new row, selected state and creation message. No default-folder selection should be written by this journey.
3. Duplicate the row. Expect a different name/file and ID. Change the selected duplicate’s folder using the picker to manifest `empty`. Open both documents. Check both titles in the Window menu, switch between them, and verify three files versus the empty-folder message. Give one launcher a query, open its document to close just that fan, then reopen the same document. Its query and the other fan should both survive. Disabling one must leave the other usable.
4. Show in Finder → actual launcher document → Command-O. Verify the intended folder. Repeat with the app already running. Disable a launcher and open its document: expect actionable settings error, not a folder switch. Re-enable the same row and reopen the same file.
5. Quit the exact review app and open a launcher through Finder again. Run Doctor and inspect the fan: it must be the unique review app and the intended folder. The manifest's unique extension/type prevents routing into production.
6. Choose a normal default folder from the fan. Activate a different launcher's folder. Quit/relaunch the app normally: expect the original default folder. Compare only hashes of private bookmark bytes if recording preference evidence.
7. Toggle Show app in Dock off. Settings must remain usable; its Quit button must work. Quit/relaunch, reopen settings and confirm off persists. Toggle on and confirm persistence. Exercise actual menu-bar recovery and Dock visibility only when those system surfaces are available; UI switch state is not a screenshot of the Dock.
8. For the file icon, use two distinct generated image files in two folders. Inspect the original launcher files that Show in Finder reveals. Each must acquire its own recent-file image with the DownloadScroller badge. Close both fans, add a new image to just one folder and check that only its launcher's icon changes. Edit its pixels in place and verify another update. Compare launcher IDs, data fork bytes and file identity before and after. An ordinary Finder copy has a snapshot of the artwork.
9. Create a third launcher for the first folder. Verify independent selection/enabled settings, current document JSON keys limited to `version` and `profileID`, and immutable fixture hashes. Test Command-W closing settings, search/arrow/Escape and Quick Look after launcher activation.
10. Select the launcher intended for the Trash side and choose **Fix on right**. Open the fans in both orders. Use a long generated filename. Verify its full text with the fixed fan alone, its shortened text when a sibling needs the space, and its full text again as soon as that sibling closes. Check that the fixed right edge stays in place. When both names fit or the other fan is on another display, both should be complete. Repeat each Dock or launcher activation and check that only its own fan toggles. Record the entry point exercised.

## Evidence and limitations

Save actual AX states/screenshots, operation descriptions, Doctor results and fixture hashes outside scratch. Use only generated fixture names in evidence. Do not call model setters, replace preference files, or invoke app callbacks as a substitute for a user journey.

For actual Dock pinning/clicks, use its system surface if exposed. Drag separate files between the divider and Trash, click each and check fan anchoring. If the Dock is inaccessible, record the blocker and leave the user pinning step explicit. Do not rewrite Dock preferences or restart it. Copying the document is not the same as creating an independent duplicate.

Cleanup closes only owned Finder/test windows and the unique review app. Run the session helper cleanup; protected macOS container metadata may remain and must be reported. Existing production defaults and documents are outside this fixture session.

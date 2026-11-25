# DownloadScroller privacy policy

Effective November 20, 2026

DownloadScroller works locally on your Mac. The app does not collect or transmit personal data, filenames, file contents, usage analytics, crash reports, or device identifiers to its developer. It includes no advertising, tracking, third-party analytics, or network client/server entitlements.

## Folder access

You choose a folder using the standard macOS folder picker. DownloadScroller remembers read-only access for listing files, reading metadata, generating thumbnails and showing previews. When you first copy into a fan, a separate picker asks you to allow copies into that folder. A writable security-scoped bookmark for that fan stays in the app's local preferences. Copying creates a new item in the receiving folder or the folder row you choose. Existing items keep their contents.

Each enabled launcher watches its chosen folder while the app is running. The launcher file's custom icon contains a preview of the newest completed file and the app badge. That preview can travel with the launcher if you copy or share it. The launcher’s folder permission stays in the app’s local storage.

The app stores the browsing bookmark and sort preference locally. Use **Folder menu → Disconnect folder** in the main fan to remove its saved browsing and copy permissions. The sample-files feature creates sample documents in the app's temporary directory.

## macOS services and other apps

Thumbnails and previews use Apple's Quick Look services. Opening a file or revealing it in Finder asks macOS to hand that file to the appropriate application. Those applications and any cloud storage provider you use have their own privacy practices. DownloadScroller does not send your files to its developer.

While the fan is open, a mouse-click event monitor lets it close when you interact with another app or a system menu. DownloadScroller keeps the last position used for its own Dock icon on each display in local preferences so keyboard reopening can use the same position. It keeps no click history and does not monitor global keystrokes.

## Support

Use [GitHub Issues](https://github.com/mganesh1610/DownloadScroller/issues) for support. Issues are public: avoid attaching private filenames, screenshots, or documents. Information you voluntarily post to GitHub is handled by GitHub under its own privacy policy.

If the app's data practices change, this policy will be updated with the corresponding release.

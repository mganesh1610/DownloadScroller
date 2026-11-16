# Security

DownloadScroller uses public APIs and App Sandbox with user-selected read-only files and app-scoped bookmarks. It requests no network, accessibility, automation, Full Disk Access, or administrator permissions.

Do not include private files or credentials in a public bug report. Report security concerns using the repository's private vulnerability reporting feature when available. For a non-sensitive issue, use [GitHub Issues](https://github.com/mganesh1610/DownloadScroller/issues).

The app passes a selected file to the default macOS application when the user opens it. It does not certify the safety of downloaded files or bypass Gatekeeper and quarantine checks.

# Security

DownloadScroller uses public APIs, App Sandbox and app-scoped bookmarks. Browsing uses read-only bookmarks. Copying into a fan requires a separate grant for its selected folder. The user-selected read/write entitlement supports this operation. Existing destination files are preserved. The app requests no network, Accessibility, automation, Full Disk Access, or administrator permissions.

Do not include private files or credentials in a public bug report. Report security concerns using the repository's private vulnerability reporting feature when available. For a non-sensitive issue, use [GitHub Issues](https://github.com/mganesh1610/DownloadScroller/issues).

The app passes a selected file to the default macOS application when the user opens it. It does not certify the safety of downloaded files or bypass Gatekeeper and quarantine checks.

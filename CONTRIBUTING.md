# Contributing

DownloadScroller is an early native macOS utility. Bug reports, accessibility feedback, and focused pull requests are welcome.

1. Open an issue describing the behavior and macOS version. Use generated sample files when reporting file-access problems.
2. Keep changes focused and use public Apple APIs. Preserve App Sandbox and read-only folder access.
3. Run `swift test` with full Xcode, or `bash scripts/test-core.sh` with Command Line Tools. Build the app with `bash scripts/build-app.sh`.
4. For UI changes, test with a long folder, a long filename, an empty folder, keyboard navigation, and Reduce Motion.
5. If you add source files, regenerate the native project with `python3 scripts/generate-xcode-project.py`.

Do not commit signing keys, provisioning profiles, local build outputs, personal files, or screenshots of private downloads. Describe what you tested and any remaining limitations in your pull request.

Contributions are licensed under the repository's MIT license.

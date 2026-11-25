import AppKit
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

@MainActor
final class FanCopyPermission {
    private let defaults: UserDefaults
    private let key: String

    init(launcherID: UUID?, defaults: UserDefaults) {
        self.defaults = defaults
        key = "fanCopyBookmark." + (launcherID?.uuidString ?? "main")
    }

    func forget() { defaults.removeObject(forKey: key) }

    func access(to root: URL, in window: NSWindow) async throws -> FolderAccess? {
        if let saved = defaults.data(forKey: key) {
            if let resolved = try? FolderBookmark.resolve(saved, allowWriting: true),
               FanFileCopy.sameDirectory(root, resolved.access.url) {
                if resolved.bookmark != saved { defaults.set(resolved.bookmark, forKey: key) }
                return resolved.access
            }
            forget()
        }
        let panel = NSOpenPanel()
        panel.title = "Allow copies into \(root.lastPathComponent)"
        panel.message = "Select \(root.lastPathComponent) to let this fan receive copies here and in its subfolders."
        panel.prompt = "Allow copies"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = root
        window.makeKeyAndOrderFront(nil)
        guard await panel.beginSheetModal(for: window) == .OK, let url = panel.url else { return nil }
        let lease = FolderAccess(url: url, scoped: url.startAccessingSecurityScopedResource())
        guard FanFileCopy.sameDirectory(root, url) else { throw FanFileCopy.CopyError.invalidFolder }
        let bookmark = try FolderBookmark.create(for: url, allowWriting: true)
        defaults.set(bookmark.bookmark, forKey: key)
        return lease
    }
}

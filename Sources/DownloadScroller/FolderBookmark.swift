import Foundation
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

/// A scan or thumbnail request can retain access until its last read finishes.
final class FolderAccess: Sendable {
    let url: URL
    private let scoped: Bool

    init(url: URL, scoped: Bool) {
        self.url = url
        self.scoped = scoped
    }

    deinit {
        if scoped { url.stopAccessingSecurityScopedResource() }
    }
}

enum FolderBookmark {
    enum AccessError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Folder access is unavailable. Choose the folder again to reconnect it." }
    }

    /// The caller already holds access (from its picker or an active bookmark).
    static func create(for url: URL, allowWriting: Bool = false) throws -> LauncherFolder {
        guard try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw AccessError.unavailable }
        let options: URL.BookmarkCreationOptions = allowWriting ? [.withSecurityScope] : [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
        let data = try url.bookmarkData(options: options,
                                        includingResourceValuesForKeys: nil, relativeTo: nil)
        return LauncherFolder(name: url.lastPathComponent, bookmark: data)
    }

    static func resolve(_ data: Data, allowWriting: Bool = false) throws -> (access: FolderAccess, bookmark: Data) {
        var stale = false
        let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                          relativeTo: nil, bookmarkDataIsStale: &stale)
        guard url.startAccessingSecurityScopedResource() else { throw AccessError.unavailable }
        let access = FolderAccess(url: url, scoped: true)
        guard try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw AccessError.unavailable }
        return (access, stale ? try create(for: url, allowWriting: allowWriting).bookmark : data)
    }
}

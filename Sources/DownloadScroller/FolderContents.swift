import Combine
import Foundation
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

/// One live directory listing can serve several windows and launcher icons.
/// Search, selection, sorting and scrolling belong to each window.
@MainActor
final class FolderContents {
    private struct Identity: Equatable {
        let volume: UInt64
        let file: UInt64

        init?(_ url: URL) {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let volume = attributes[.systemNumber] as? NSNumber,
                  let file = attributes[.systemFileNumber] as? NSNumber else { return nil }
            self.volume = volume.uint64Value
            self.file = file.uint64Value
        }
    }

    let access: FolderAccess
    let isSample: Bool
    @Published private(set) var listing: Result<[FileEntry], Error>?
    @Published private(set) var loading = false
    private(set) var newestForLauncher: FileEntry?
    private let watcher = FolderWatcher()
    private let latestFileWatcher = FolderWatcher()
    private let launcherExtension: String?
    private let identity: Identity?
    private var scan: Task<Void, Never>?

    init(access: FolderAccess, isSample: Bool = false, launcherExtension: String? = nil) {
        self.access = access
        self.isSample = isSample
        self.launcherExtension = launcherExtension
        identity = Identity(access.url)
        watcher.start(access.url) { [weak self] in self?.refresh() }
        refresh()
    }

    func represents(_ url: URL) -> Bool {
        guard watcher.isWatching, let identity, access.url.standardizedFileURL == url.standardizedFileURL else { return false }
        return identity == Identity(url)
    }

    func refresh() {
        scan?.cancel()
        loading = true
        let worker = Task.detached(priority: .userInitiated) { [access, isSample] in
            try withExtendedLifetime(access) {
                let files = try FolderScanner.scan(access.url)
                guard isSample else { return files }
                // Use fixture dates rather than when macOS added the samples.
                return files.map {
                    FileEntry(url: $0.url, name: $0.name, kind: $0.kind, size: $0.size,
                              addedAt: $0.modifiedAt, modifiedAt: $0.modifiedAt)
                }
            }
        }
        scan = Task { [weak self] in
            let result = await withTaskCancellationHandler { await worker.result } onCancel: { worker.cancel() }
            guard !Task.isCancelled, let self else { return }
            if let launcherExtension {
                // Directory events catch arrivals and removals. A write inside
                // the current file can change its preview without a directory event.
                // Exclude launcher documents to avoid watching our own icon writes.
                let candidates = (try? result.get())?.filter { $0.url.pathExtension.caseInsensitiveCompare(launcherExtension) != .orderedSame }
                newestForLauncher = DockFile.newest(in: candidates ?? [])
                if let latest = newestForLauncher {
                    latestFileWatcher.start(latest.url) { [weak self] in self?.refresh() }
                } else {
                    latestFileWatcher.stop()
                }
            }
            listing = result
            loading = false
        }
    }

    deinit { scan?.cancel() }
}

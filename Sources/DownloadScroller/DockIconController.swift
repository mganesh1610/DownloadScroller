import AppKit
import Combine
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

/// Public AppKit API; the bundle's original icon remains available when not running.
@MainActor
final class DockIconController {
    private var subscription: AnyCancellable?
    private var thumbnailTask: Task<Void, Never>?

    init(model: LibraryModel) {
        subscription = model.$entries.map { DockFile.newest(in: $0) }.removeDuplicates()
            .sink { [weak self] entry in self?.update(entry) }
    }

    private func update(_ entry: FileEntry?) {
        thumbnailTask?.cancel()
        guard let entry else { NSApp.applicationIconImage = nil; return }
        let store = ThumbnailStore.shared
        NSApp.applicationIconImage = DockIconRenderer.image(with: store.cached(for: entry) ?? store.icon(for: entry))
        thumbnailTask = Task { @MainActor in
            let image = await store.image(for: entry)
            guard !Task.isCancelled else { return }
            NSApp.applicationIconImage = DockIconRenderer.image(with: image)
        }
    }

    func stop() {
        subscription?.cancel()
        thumbnailTask?.cancel()
        NSApp.applicationIconImage = nil
    }
}

import AppKit
import Combine
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

/// Public AppKit API; the bundle's original icon remains available when not running.
@MainActor
final class DockIconController {
    private var subscriptions = Set<AnyCancellable>()
    private var thumbnailTask: Task<Void, Never>?
    private var currentEntry: FileEntry?

    init(model: LibraryModel) {
        model.$entries.map { DockFile.newest(in: $0) }.removeDuplicates()
            .sink { [weak self] entry in self?.currentEntry = entry; self?.update(entry) }
            .store(in: &subscriptions)
        NSApp.publisher(for: \.effectiveAppearance).dropFirst()
            .sink { [weak self] _ in self?.update(self?.currentEntry) }
            .store(in: &subscriptions)
    }

    private func update(_ entry: FileEntry?) {
        thumbnailTask?.cancel()
        let dark = SystemAppearance.isDark(NSApp.effectiveAppearance)
        guard let entry else { NSApp.applicationIconImage = AppLogo.image(dark: dark); return }
        let store = ThumbnailStore.shared
        NSApp.applicationIconImage = DockIconRenderer.image(with: store.cached(for: entry) ?? store.icon(for: entry), dark: dark)
        thumbnailTask = Task { @MainActor in
            let image = await store.image(for: entry)
            guard !Task.isCancelled else { return }
            NSApp.applicationIconImage = DockIconRenderer.image(with: image, dark: dark)
        }
    }

    func stop() {
        subscriptions.removeAll()
        thumbnailTask?.cancel()
        NSApp.applicationIconImage = nil
    }
}

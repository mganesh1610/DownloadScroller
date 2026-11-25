import AppKit
import Combine
import OSLog
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

/// A Dock document tile uses the icon of its backing file. Keep that file's
/// identity intact so existing Dock shortcuts continue to refer to it.
@MainActor
final class LauncherArtwork {
    private struct Artwork: Equatable {
        let newest: FileEntry?
        let dark: Bool
    }

    private let profile: LauncherProfile
    private let store: LauncherStore
    private var observation: AnyCancellable?
    private var thumbnail: Task<Void, Never>?
    private var requested: Artwork?
    private var written: Artwork?
    private weak var source: FolderContents?
    private let log = Logger(subsystem: "DownloadScroller", category: "LauncherArtwork")

    init(profile: LauncherProfile, store: LauncherStore) {
        self.profile = profile
        self.store = store
    }

    func observe(_ contents: FolderContents?) {
        observation = nil
        thumbnail?.cancel()
        requested = nil
        source = contents
        if let contents {
            observation = contents.$listing.compactMap { $0 }.sink { [weak self] _ in
                self?.update()
            }
        } else {
            update()
        }
    }

    func appearanceChanged() {
        if let source, source.listing == nil { return }
        update()
    }

    private func update() {
        let artwork = Artwork(newest: source?.newestForLauncher, dark: SystemAppearance.isDark(NSApp.effectiveAppearance))
        guard requested != artwork else { return }
        thumbnail?.cancel()
        requested = artwork
        guard written != artwork else { return }
        thumbnail = Task { [weak self, access = source?.access] in
            defer { withExtendedLifetime(access) {} }
            let image: NSImage
            if let entry = artwork.newest {
                let preview = await ThumbnailStore.shared.image(for: entry)
                image = DockIconRenderer.image(with: preview, dark: artwork.dark)
            } else {
                image = AppLogo.image(dark: artwork.dark)
            }
            guard !Task.isCancelled, let self else { return }
            do {
                let url = try store.iconDestination(for: profile)
                guard NSWorkspace.shared.setIcon(image, forFile: url.path, options: []) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                // Let file presenters (including pinned document tiles) see a
                // content date change even if they cache resource-fork updates.
                try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
                written = artwork
            } catch {
                requested = nil    // retry on the next scan
                log.error("Could not update the launcher icon: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    deinit { thumbnail?.cancel() }
}

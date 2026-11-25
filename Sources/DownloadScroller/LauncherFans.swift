import AppKit
import Combine
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

/// Documents have independent windows even when several point at one folder.
/// Directory watchers and reads can be shared. A window is created on demand.
@MainActor
final class LauncherFans {
    @MainActor private final class Session {
        var profile: LauncherProfile
        var contents: FolderContents?
        var shelf: ShelfController?
        let artwork: LauncherArtwork

        init(_ profile: LauncherProfile, store: LauncherStore) {
            self.profile = profile
            artwork = LauncherArtwork(profile: profile, store: store)
        }

        func closeWindow() {
            shelf?.dismiss()
            shelf?.shutdown()
            shelf?.model.shutdown()
            shelf = nil
        }
    }

    private let store: LauncherStore
    private let fanPositions: FanPositionPreferences
    private var sessions: [UUID: Session] = [:]
    private var appearance: AnyCancellable?
    var onShowSettings: ((ShelfController) -> Void)?
    var onFolderChanged: (() -> Void)?

    init(store: LauncherStore, fanPositions: FanPositionPreferences) {
        self.store = store
        self.fanPositions = fanPositions
        appearance = NSApp.publisher(for: \.effectiveAppearance).dropFirst().sink { [weak self] _ in
            self?.sessions.values.forEach { $0.artwork.appearanceChanged() }
        }
    }

    func synchronize(_ profiles: [LauncherProfile]) {
        let live = Set(profiles.map(\.id))
        for id in sessions.keys.filter({ !live.contains($0) }) {
            sessions.removeValue(forKey: id)?.closeWindow()
        }
        for profile in profiles {
            do { _ = try configure(profile) }
            catch {
                // A disconnected volume must not block other launchers.
                // Opening this launcher retries and surfaces the access error.
                if let session = sessions[profile.id] {
                    session.closeWindow()
                    session.contents = nil
                    session.artwork.observe(nil)
                }
            }
        }
    }

    func open(_ profile: LauncherProfile, toggle: Bool) throws {
        guard profile.isEnabled else { throw LauncherError.disabled(profile.name) }
        let session = try configure(profile)
        guard let contents = session.contents else { throw FolderBookmark.AccessError.unavailable }
        if fanPositions.rightLauncherID == nil { fanPositions.fixOnRight(profile.id) }
        if session.shelf == nil {
            let model = LibraryModel(launcherID: profile.id)
            model.display(contents)
            let shelf = ShelfController(model: model, fanPositions: fanPositions)
            shelf.window?.title = profile.name + " — DownloadScroller"
            model.onShowDockSettings = { [weak self, weak shelf] in
                if let shelf { self?.onShowSettings?(shelf) }
            }
            model.onSetLauncherFolder = { [weak self] folder in
                guard let self else { throw LauncherError.missingProfile }
                try store.update(profile.id, folder: folder)
                onFolderChanged?()
            }
            session.shelf = shelf
        }
        session.shelf?.showFromDock(toggle: toggle)
    }

    private func configure(_ profile: LauncherProfile) throws -> Session {
        let existing = sessions[profile.id]
        if let existing, existing.profile == profile {
            if !profile.isEnabled { return existing }
            if let contents = existing.contents, contents.represents(contents.access.url) { return existing }
        }
        let session = existing ?? Session(profile, store: store)
        sessions[profile.id] = session
        guard profile.isEnabled else {
            session.profile = profile
            session.closeWindow()
            session.contents = nil
            session.artwork.observe(nil)
            return session
        }
        let resolved = try FolderBookmark.resolve(profile.folder.bookmark)
        var current = profile
        if resolved.bookmark != profile.folder.bookmark {
            current.folder = LauncherFolder(name: resolved.access.url.lastPathComponent, bookmark: resolved.bookmark)
            try store.update(profile.id, folder: current.folder)
        }
        let shared = sessions.values.compactMap(\.contents).first { $0.represents(resolved.access.url) }
        let contents = shared ?? FolderContents(access: resolved.access, launcherExtension: store.fileExtension)
        session.profile = current
        session.contents = contents
        session.shelf?.model.display(contents)
        session.artwork.observe(contents)
        return session
    }

    func shutdown() {
        sessions.values.forEach { $0.closeWindow() }
        sessions.removeAll()
        appearance = nil
    }
}

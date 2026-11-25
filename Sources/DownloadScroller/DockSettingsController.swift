import AppKit
import Combine
import SwiftUI
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

@MainActor
final class DockSettingsModel: ObservableObject {
    @Published private(set) var profiles: [LauncherProfile] = []
    @Published var selectedID: UUID?
    @Published var draftName = ""
    @Published private(set) var draftFolder: LauncherFolder?
    @Published var message: String?
    @Published private(set) var storageAvailable = true
    let store: LauncherStore
    let visibility: DockVisibility
    weak var window: NSWindow?
    var onActivate: ((LauncherProfile) throws -> Void)?
    var onProfilesChanged: (([LauncherProfile]) -> Void)?

    init(store: LauncherStore, visibility: DockVisibility) {
        self.store = store
        self.visibility = visibility
    }

    var selected: LauncherProfile? { profiles.first { $0.id == selectedID } }

    func prepare(currentFolder: URL?, isSample: Bool) {
        reload()
        if draftFolder == nil, !isSample, let currentFolder {
            do {
                draftFolder = try FolderBookmark.create(for: currentFolder)
                draftName = draftFolder?.name ?? ""
            } catch { message = error.localizedDescription }
        }
    }

    func reload() {
        do {
            profiles = try store.list()
            onProfilesChanged?(profiles)
            storageAvailable = true
            if !profiles.contains(where: { $0.id == selectedID }) { selectedID = profiles.first?.id }
        } catch {
            storageAvailable = false
            profiles = []
            selectedID = nil
            message = error.localizedDescription
        }
    }

    func setDockVisible(_ visible: Bool) {
        if !visibility.setVisible(visible) { message = "macOS could not change the Dock icon. Please try again." }
        // Changing activation policy can deactivate the settings window.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func chooseDraftFolder() {
        chooseFolder { [weak self] folder in
            guard let self else { return }
            if self.draftName.isEmpty || self.draftName == self.draftFolder?.name { self.draftName = folder.name }
            self.draftFolder = folder
        }
    }

    func create() {
        guard let draftFolder else { return }
        perform {
            let profile = try store.create(name: draftName.isEmpty ? draftFolder.name : draftName, folder: draftFolder)
            selectedID = profile.id
            message = "Launcher created. Choose Show in Finder, then drag it beside the Trash in your Dock."
        }
    }

    func duplicateSelected() {
        guard let selectedID else { return }
        perform {
            self.selectedID = try store.duplicate(selectedID).id
            message = "Duplicate created for the same folder. Choose Change folder… to give it a different folder."
        }
    }

    func setEnabled(_ enabled: Bool, id: UUID) {
        perform { try store.update(id, isEnabled: enabled) }
    }

    func changeSelectedFolder() {
        guard let selectedID else { return }
        chooseFolder { [weak self] folder in
            self?.perform { try self?.store.update(selectedID, folder: folder) }
        }
    }

    func openSelected() {
        guard let selected, selected.isEnabled else { return }
        perform { try onActivate?(selected) }
    }

    func revealSelected() {
        guard let selectedID else { return }
        perform {
            let url = try store.documentURL(for: selectedID)
            guard FileManager.default.fileExists(atPath: url.path) else {
                message = "This launcher's file was moved or removed. Duplicate it to create a new file."
                return
            }
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func perform(_ operation: () throws -> Void) {
        message = nil
        do { try operation(); reload() }
        catch { message = error.localizedDescription }
    }

    private func chooseFolder(_ completion: @escaping (LauncherFolder) -> Void) {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose a folder for this launcher"
        panel.message = "Choose a folder to browse. The first incoming copy asks for permission to write here."
        panel.prompt = "Choose folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do { completion(try FolderBookmark.create(for: url)) }
            catch { self?.message = error.localizedDescription }
        }
    }
}

@MainActor
final class DockSettingsController: NSWindowController {
    let model: DockSettingsModel

    init(store: LauncherStore, visibility: DockVisibility, fanPositions: FanPositionPreferences) {
        model = DockSettingsModel(store: store, visibility: visibility)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 620),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Dock & Launchers"
        window.level = .floating
        window.minSize = NSSize(width: 640, height: 620)
        window.isReleasedWhenClosed = false
        let content = NSHostingView(rootView: DockSettingsView(model: model, visibility: visibility, fanPositions: fanPositions))
        // The scrollable List has no useful intrinsic height. Keep the native
        // window's explicit size instead of expanding it to the list's ideal size.
        content.sizingOptions = []
        window.contentView = content
        super.init(window: window)
        model.window = window
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(currentFolder: URL?, isSample: Bool) {
        model.prepare(currentFolder: currentFolder, isSample: isSample)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

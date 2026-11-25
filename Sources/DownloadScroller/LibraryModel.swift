import AppKit
import Combine
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

@MainActor
final class LibraryModel: ObservableObject {
    @Published private(set) var entries: [FileEntry] = []
    @Published private(set) var visibleEntries: [FileEntry] = []
    @Published private(set) var folder: URL?
    @Published private(set) var loading = false
    @Published private(set) var isSample = false
    @Published var errorMessage: String?
    @Published var dropHint: String?
    @Published var availableForFanDrop = false
    @Published var copyNotice: String?
    let copyPermission: FanCopyPermission
    @Published var search = "" { didSet { updateQuery() } }
    @Published var isSearchPresented = false
    @Published var filter: FileKind? { didSet { updateQuery() } }
    @Published var selectedID: String?
    @Published var searchFocusRequest = 0
    @Published var selectionScrollRequest = 0
    @Published var fanOpenRequest = 0
    @Published var pinned: Bool {
        didSet { defaults.set(pinned, forKey: pinKey) }
    }
    @Published var fanIconSide = FanIconSide.right
    @Published var filenameWrapWidth: CGFloat?
    let launcherID: UUID?
    private let defaults: UserDefaults
    private let pinKey: String
    private let sortKey: String
    var isDraggingFile = false
    @Published var sort: FileSort {
        didSet {
            defaults.set(sort.rawValue, forKey: sortKey)
            updateQuery()
        }
    }

    var onPreview: (([URL], Int) -> Void)?
    var onDismiss: (() -> Void)?
    var onShowDockSettings: (() -> Void)?
    var onSetLauncherFolder: ((LauncherFolder) throws -> Void)?
    private var contents: FolderContents?
    private var subscriptions = Set<AnyCancellable>()
    private var switchingFolder = false
    private let bookmarkKey = "selectedFolderBookmark"

    init(launcherID: UUID? = nil, defaults: UserDefaults = .standard) {
        self.launcherID = launcherID
        self.defaults = defaults
        copyPermission = FanCopyPermission(launcherID: launcherID, defaults: defaults)
        pinKey = "keepFanOpen." + (launcherID?.uuidString ?? "main")
        sortKey = launcherID.map { "fanSortFromDock." + $0.uuidString } ?? "fanSortFromDock"
        let saved = defaults.string(forKey: sortKey) ?? defaults.string(forKey: "fanSortFromDock")
        sort = FileSort(rawValue: saved ?? "") ?? .newest
        pinned = defaults.bool(forKey: pinKey)
    }

    var selectedEntry: FileEntry? { visibleEntries.first { $0.id == selectedID } }
    var folderAccess: FolderAccess? { contents?.access }
    var folderName: String { folder?.lastPathComponent ?? "Downloads, unfolded." }

    func restore() {
        guard let data = defaults.data(forKey: bookmarkKey) else { return }
        do {
            let resolved = try FolderBookmark.resolve(data)
            if resolved.bookmark != data { defaults.set(resolved.bookmark, forKey: bookmarkKey) }
            display(FolderContents(access: resolved.access))
        } catch {
            errorMessage = "Your saved folder could not be opened. Choose it again to reconnect."
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = launcherID == nil ? "Choose a folder for DownloadScroller" : "Choose a folder for this launcher"
        panel.message = "Choose a folder to browse. The first incoming copy asks for permission to write here."
        panel.prompt = "Choose folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = folder ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window) { [weak self] response in
                guard response == .OK, let url = panel.url else { return }
                self?.acceptFolder(url)
            }
        } else if panel.runModal() == .OK, let url = panel.url { acceptFolder(url) }
    }

    private func acceptFolder(_ url: URL) {
        let access = FolderAccess(url: url, scoped: url.startAccessingSecurityScopedResource())
        do {
            try withExtendedLifetime(access) {
                let bookmark = try FolderBookmark.create(for: url)
                if launcherID != nil {
                    guard let onSetLauncherFolder else { throw LauncherError.missingProfile }
                    try onSetLauncherFolder(bookmark)
                } else {
                    defaults.set(bookmark.bookmark, forKey: bookmarkKey)
                    display(FolderContents(access: access))
                }
            }
        } catch {
            errorMessage = "Couldn't save access to this folder: \(error.localizedDescription)"
        }
    }

    func display(_ source: FolderContents?) {
        guard contents !== source else { return }
        if let old = contents?.access.url, source?.access.url.standardizedFileURL != old.standardizedFileURL {
            copyPermission.forget()
        }
        dropHint = nil
        copyNotice = nil
        subscriptions.removeAll()
        contents = source
        folder = source?.access.url
        isSample = source?.isSample ?? false
        switchingFolder = true
        search = ""
        isSearchPresented = false
        filter = nil
        entries = []
        visibleEntries = []
        selectedID = nil
        switchingFolder = false
        errorMessage = nil
        loading = false
        guard let source else { return }
        source.$loading.sink { [weak self] in self?.loading = $0 }.store(in: &subscriptions)
        source.$listing.compactMap { $0 }.sink { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let files):
                entries = files
                errorMessage = nil
            case .failure:
                entries = []
                errorMessage = "This folder is unavailable. Reconnect it or choose another folder."
            }
            updateQuery()
        }.store(in: &subscriptions)
    }

    func refresh() { contents?.refresh() }

    private func updateQuery() {
        guard !switchingFolder else { return }
        visibleEntries = FileQuery.fanOrder(entries, search: search, kind: filter, sort: sort)
        if !visibleEntries.contains(where: { $0.id == selectedID }) { selectedID = visibleEntries.last?.id }
    }

    func prepareToShow() {
        selectedID = visibleEntries.last?.id
        fanOpenRequest += 1
    }

    /// Keyboard events and SwiftUI exit commands must follow the same order.
    func handleEscape() {
        guard !isDraggingFile else { return }
        if !search.isEmpty { search = "" }
        else if isSearchPresented { isSearchPresented = false }
        else { onDismiss?() }
    }

    func moveSelection(_ delta: Int) {
        guard !visibleEntries.isEmpty else { return }
        let current = visibleEntries.firstIndex { $0.id == selectedID } ?? (delta > 0 ? -1 : visibleEntries.count)
        selectedID = visibleEntries[min(max(current + delta, 0), visibleEntries.count - 1)].id
        selectionScrollRequest += 1
    }

    func open(_ entry: FileEntry? = nil) {
        guard let entry = entry ?? selectedEntry else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(entry.url, configuration: configuration) { [weak self] _, error in
            Task { @MainActor in
                if let error { self?.errorMessage = "Couldn't open this item: \(error.localizedDescription)" }
                else if self?.pinned == false { self?.onDismiss?() }
            }
        }
    }

    func reveal(_ entry: FileEntry? = nil) {
        if let url = (entry ?? selectedEntry)?.url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    func openFolder() {
        guard let folder else { return }
        NSWorkspace.shared.open(folder)
    }

    func preview(_ entry: FileEntry? = nil) {
        if let entry { selectedID = entry.id }
        guard let index = visibleEntries.firstIndex(where: { $0.id == selectedID }) else { return }
        onPreview?(visibleEntries.map(\.url), index)
    }

    func useSamples() {
        do { display(FolderContents(access: FolderAccess(url: try SampleLibrary.create(), scoped: false), isSample: true)) }
        catch { errorMessage = "Couldn't create sample files: \(error.localizedDescription)" }
    }

    func disconnect() {
        guard launcherID == nil else { return }
        defaults.removeObject(forKey: bookmarkKey)
        copyPermission.forget()
        display(nil)
    }

    func shutdown() {
        subscriptions.removeAll()
        contents = nil
    }
}

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
    @Published var search = "" { didSet { updateQuery() } }
    @Published var filter: FileKind? { didSet { updateQuery() } }
    @Published var selectedID: String?
    @Published var searchFocusRequest = 0
    @Published var selectionScrollRequest = 0
    @Published var fanOpenRequest = 0
    @Published var pinned = false
    @Published var sort: FileSort {
        didSet {
            UserDefaults.standard.set(sort.rawValue, forKey: "fanSortFromDock")
            updateQuery()
        }
    }

    var onPreview: (([URL], Int) -> Void)?
    var onDismiss: (() -> Void)?
    private let watcher = FolderWatcher()
    private var scopedFolder: URL?
    private var scanTask: Task<Void, Never>?
    private var scanWorker: Task<[FileEntry], Error>?
    private var generation = 0
    private var switchingFolder = false
    private let bookmarkKey = "selectedFolderBookmark"

    init() {
        let defaults = UserDefaults.standard
        // The former top-down preference belongs to the old layout. Start the
        // Dock-oriented fan with recent files at its base, then remember choices.
        sort = FileSort(rawValue: defaults.string(forKey: "fanSortFromDock") ?? "") ?? .newest
    }

    var selectedEntry: FileEntry? { visibleEntries.first { $0.id == selectedID } }
    var folderName: String { folder?.lastPathComponent ?? "Downloads, unfolded." }

    func restore() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                              relativeTo: nil, bookmarkDataIsStale: &stale)
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Folder access expired. Choose your folder again to reconnect."
                return
            }
            if stale {
                do { try saveBookmark(url) }
                catch {
                    url.stopAccessingSecurityScopedResource()
                    throw error
                }
            }
            switchFolder(to: url, scoped: true, sample: false)
        } catch {
            errorMessage = "Your saved folder could not be opened. Choose it again to reconnect."
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder for DownloadScroller"
        panel.message = "Choose Downloads or another folder. DownloadScroller only needs permission to read it."
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
        let scoped = url.startAccessingSecurityScopedResource()
        do {
            try saveBookmark(url)
            switchFolder(to: url, scoped: scoped, sample: false)
        } catch {
            if scoped { url.stopAccessingSecurityScopedResource() }
            errorMessage = "Couldn't save access to this folder: \(error.localizedDescription)"
        }
    }

    private func saveBookmark(_ url: URL) throws {
        let data = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                        includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    private func switchFolder(to url: URL, scoped: Bool, sample: Bool) {
        generation += 1
        scanTask?.cancel()
        scanWorker?.cancel()
        watcher.stop()
        let previousScope = scopedFolder
        let previousWorker = scanWorker
        // Finish any in-flight read before releasing its security scope.
        Task {
            _ = await previousWorker?.result
            previousScope?.stopAccessingSecurityScopedResource()
        }
        scopedFolder = scoped ? url : nil
        folder = url
        isSample = sample
        switchingFolder = true
        search = ""
        filter = nil
        entries = []
        visibleEntries = []
        selectedID = nil
        switchingFolder = false
        errorMessage = nil
        watcher.start(url) { [weak self] in self?.refresh() }
        refresh()
    }

    func refresh() {
        guard let folder else { return }
        generation += 1
        let currentGeneration = generation
        scanTask?.cancel()
        scanWorker?.cancel()
        loading = true
        let worker = Task.detached(priority: .userInitiated) { try FolderScanner.scan(folder) }
        scanWorker = worker
        scanTask = Task { [weak self] in
            do {
                let files = try await worker.value
                guard let self, !Task.isCancelled, currentGeneration == self.generation else { return }
                // Give the built-in sample files meaningful ages, independent of
                // when macOS added the generated fixtures to their temporary folder.
                self.entries = self.isSample ? files.map {
                    FileEntry(url: $0.url, name: $0.name, kind: $0.kind, size: $0.size,
                              addedAt: $0.modifiedAt, modifiedAt: $0.modifiedAt)
                } : files
                self.errorMessage = nil
                self.updateQuery()
                self.loading = false
            } catch {
                guard let self, !Task.isCancelled, currentGeneration == self.generation else { return }
                self.loading = false
                self.entries = []
                self.updateQuery()
                self.errorMessage = "This folder is unavailable. Reconnect it or choose another folder."
            }
        }
    }

    private func updateQuery() {
        guard !switchingFolder else { return }
        visibleEntries = FileQuery.fanOrder(entries, search: search, kind: filter, sort: sort)
        if !visibleEntries.contains(where: { $0.id == selectedID }) { selectedID = visibleEntries.last?.id }
    }

    func prepareToShow() {
        selectedID = visibleEntries.last?.id
        fanOpenRequest += 1
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
        do { switchFolder(to: try SampleLibrary.create(), scoped: false, sample: true) }
        catch { errorMessage = "Couldn't create sample files: \(error.localizedDescription)" }
    }

    func disconnect() {
        generation += 1
        scanTask?.cancel()
        scanWorker?.cancel()
        watcher.stop()
        let previousScope = scopedFolder
        let previousWorker = scanWorker
        Task {
            _ = await previousWorker?.result
            previousScope?.stopAccessingSecurityScopedResource()
        }
        scopedFolder = nil
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        folder = nil
        isSample = false
        loading = false
        entries = []
        search = ""
        filter = nil
        selectedID = nil
        errorMessage = nil
    }

    func shutdown() {
        scanTask?.cancel()
        scanWorker?.cancel()
        watcher.stop()
        // Process exit releases the remaining scope after background reads stop.
    }
}

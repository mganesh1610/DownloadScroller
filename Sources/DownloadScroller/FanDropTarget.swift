import AppKit
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

/// Both drag-and-drop and the file's context menu use the same destination
/// selection, sandbox grant and copy operation.
@MainActor
final class FanDropTarget: NSObject {
    private struct MenuCopy {
        let file: URL
        let access: FolderAccess
        let root: FolderAccess
        let child: String?
    }

    private let model: LibraryModel
    private weak var panel: ShelfPanel?
    private var busy = false
    private var clearNotice: Task<Void, Never>?

    init(model: LibraryModel, panel: ShelfPanel) {
        self.model = model
        self.panel = panel
    }

    private func accepts(_ info: NSDraggingInfo) -> Bool {
        guard !busy, let panel, panel.isVisible, panel.attachedSheet == nil, model.folderAccess != nil,
              info.draggingSourceOperationMask.contains(.copy) else { return false }
        if let sender = info.draggingSource as? FanCanvas { return sender.window !== panel && sender.draggedFile != nil }
        return info.draggingPasteboard.pasteboardItems?.count == 1 && info.draggingPasteboard.types?.contains(.fileURL) == true
    }

    func update(_ info: NSDraggingInfo) -> NSDragOperation {
        guard accepts(info) else { clearHover(); return [] }
        let row = panel?.canvas?.folderRow(atWindowPoint: info.draggingLocation)
        let hint = "Copy to " + (row?.name ?? model.folderName)
        if model.dropHint != hint { model.dropHint = hint }
        panel?.canvas?.dropFolderID = row?.id
        return .copy
    }

    func clearHover() {
        if model.dropHint != nil { model.dropHint = nil }
        panel?.canvas?.dropFolderID = nil
    }

    func perform(_ info: NSDraggingInfo) -> Bool {
        defer { clearHover() }
        guard accepts(info), let root = model.folderAccess else { return false }
        let child = panel?.canvas?.folderRow(atWindowPoint: info.draggingLocation)?.url.lastPathComponent
        if let sender = info.draggingSource as? FanCanvas, let file = sender.draggedFile {
            let accepted = receive(file.entry.url, access: file.access, root: root, child: child)
            if accepted { sender.acceptedByFan = true }
            return accepted
        }
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              urls.count == 1, let file = urls.first, file.isFileURL else { return false }
        return receive(file, access: FolderAccess(url: file, scoped: file.startAccessingSecurityScopedResource()), root: root, child: child)
    }

    @discardableResult private func receive(_ file: URL, access: FolderAccess, root: FolderAccess, child: String?) -> Bool {
        guard !busy, let panel, panel.isVisible, panel.attachedSheet == nil, model.folderAccess === root else { return false }
        busy = true
        clearNotice?.cancel()
        model.copyNotice = "Copying " + file.lastPathComponent + "…"
        Task { @MainActor in
            defer { busy = false }
            do {
                let write: FolderAccess?
                if model.isSample { write = root }
                else { write = try await model.copyPermission.access(to: root.url, in: panel) }
                guard model.folderAccess === root else { return }
                guard let write else { notice("Copy cancelled"); return }
                let saved = try await Task.detached(priority: .userInitiated) {
                    try withExtendedLifetime((access, write, root)) {
                        try FanFileCopy.copy(file, into: write.url, child: child)
                    }
                }.value
                if model.folderAccess === root {
                    model.refresh()
                    notice("Copied " + saved.lastPathComponent + " to " + (child ?? model.folderName))
                }
            } catch {
                guard model.folderAccess === root else { return }
                notice("Copy failed")
                let alert = NSAlert()
                alert.messageText = "Couldn't copy " + file.lastPathComponent
                alert.informativeText = error.localizedDescription
                if panel.isVisible { _ = await alert.beginSheetModal(for: panel) }
            }
        }
        return true
    }

    private func notice(_ text: String) {
        model.copyNotice = text
        clearNotice?.cancel()
        clearNotice = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.model.copyNotice = nil
        }
    }

    func appendMenu(to menu: NSMenu, file: URL, access: FolderAccess) {
        guard let root = model.folderAccess, let panel else { return }
        let name = model.launcherID == nil ? model.folderName : panel.title
        let group = menu.addItem(withTitle: name, action: nil, keyEquivalent: "")
        let choices = NSMenu()
        choices.autoenablesItems = false
        group.submenu = choices
        func add(_ title: String, child: String?) {
            let item = choices.addItem(withTitle: title, action: #selector(copyFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.isEnabled = !busy && panel.attachedSheet == nil
            item.representedObject = MenuCopy(file: file, access: access, root: root, child: child)
        }
        add("This folder (\(model.folderName))", child: nil)
        let folders = model.entries.filter { $0.kind == .folders }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if !folders.isEmpty { choices.addItem(.separator()) }
        for folder in folders { add(folder.name, child: folder.url.lastPathComponent) }
    }

    @objc private func copyFromMenu(_ item: NSMenuItem) {
        guard let choice = item.representedObject as? MenuCopy else { return }
        receive(choice.file, access: choice.access, root: choice.root, child: choice.child)
    }
}

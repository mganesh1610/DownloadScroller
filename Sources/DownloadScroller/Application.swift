import AppKit
import ColorSync
import Combine
import QuickLookUI
import SwiftUI
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

private extension NSScreen {
    var fanDisplayKey: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}

final class ShelfPanel: NSPanel {
    weak var canvas: FanCanvas?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    static var visibleFans: [ShelfPanel] {
        NSApp.windows.compactMap { $0 as? ShelfPanel }.filter(\.isVisible)
    }

    var yieldsToFileDrag = false {
        didSet {
            ignoresMouseEvents = yieldsToFileDrag
            alphaValue = yieldsToFileDrag ? 0 : 1
        }
    }
}

final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
}

@MainActor
final class ShelfController: NSWindowController, NSWindowDelegate, @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    let model: LibraryModel
    let dropTarget: FanDropTarget
    private var previewURLs: [URL] = []
    private var previewIndex = 0
    private var subscriptions = Set<AnyCancellable>()
    private var lastAnchor: ShelfAnchor?
    private var presentationDisplay: NSNumber?
    private let fanPositions: FanPositionPreferences
    private var widthForFilenames = FanMetrics.minimumWidth
    private static var layoutPending = false
    private var outsideClickMonitor: Any?
    private var dockToggle = FanDockToggle()
    private var pendingDockSwitch: DispatchWorkItem?

    init(model: LibraryModel, fanPositions: FanPositionPreferences) {
        self.model = model
        self.fanPositions = fanPositions
        let panel = ShelfPanel(contentRect: NSRect(x: 0, y: 0, width: 490, height: 690),
                               styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        dropTarget = FanDropTarget(model: model, panel: panel)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.allowsToolTipsWhenApplicationIsInactive = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.collectionBehavior.insert(.participatesInCycle)
        panel.isReleasedWhenClosed = false
        panel.title = "DownloadScroller"
        super.init(window: panel)
        panel.delegate = self
        panel.registerForDraggedTypes([.fileURL])
        panel.contentView = TransparentHostingView(rootView: RootView(model: model))
        model.onDismiss = { [weak self] in self?.dismiss() }
        model.onPreview = { [weak self] urls, index in self?.preview(urls, index: index) }
        fanPositions.objectWillChange.sink { Self.scheduleLayout() }.store(in: &subscriptions)
        model.$folder.sink { _ in Self.scheduleLayout() }.store(in: &subscriptions)
        model.$entries.map(\.count).removeDuplicates().sink { _ in Self.scheduleLayout() }.store(in: &subscriptions)
        model.$visibleEntries.map { $0.map(\.name) }.removeDuplicates().map { FanMetrics.widthToFit($0) }
            .removeDuplicates().sink { [weak self] width in
                self?.widthForFilenames = width
                Self.scheduleLayout()
            }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                      app.bundleIdentifier != "com.apple.dock" else { return }
                self?.otherApplicationActivated(app)
            }
            .store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .sink { _ in Self.scheduleLayout() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didHideNotification)
            .sink { [weak self] _ in self?.stopOutsideClickMonitor() }
            .store(in: &subscriptions)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(anchor: ShelfAnchor? = nil, screen: NSScreen? = nil) {
        guard let window else { return }
        if let chosen = screen ?? anchor.flatMap({ a in NSScreen.screens.first { $0.frame.contains(a.point) } })
            ?? (!window.isVisible ? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } : nil) {
            presentationDisplay = chosen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        }
        if model.launcherID == nil || !window.isVisible { model.prepareToShow() }
        lastAnchor = anchor
        Self.layoutVisiblePanels(including: self)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        startOutsideClickMonitor()
        model.refresh()
    }

    func showFromDock(toggle: Bool = false, at point: NSPoint = NSEvent.mouseLocation) {
        let screen = NSScreen.screens.first { $0.frame.contains(point) }
        let anchor = screen.flatMap { DockClick.anchor(at: point, on: $0) }
        if model.launcherID == nil, let anchor, let screen, let key = screen.fanDisplayKey {
            // A click that closes a previously keyboard-opened fan also teaches
            // us where to put it on the next open.
            fanPositions.rememberAppClick(anchor, display: key, screen: screen.frame)
        }
        let press = anchor == nil ? nil : DockClick.currentPress
        switch dockToggle.action(toggle: toggle, visible: window?.isVisible == true, press: press) {
        case .open: show(anchor: anchor, screen: screen)
        case .close:
            if window?.attachedSheet == nil { dismiss() }
        case .alreadyHandled: break
        }
    }

    private var targetScreen: NSScreen? {
        NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber) == presentationDisplay }
            ?? window?.screen ?? NSScreen.main
    }

    private func panelRequest(on screen: NSScreen) -> FanPlacement.Panel {
        let saved = model.launcherID == nil ? screen.fanDisplayKey.flatMap {
            fanPositions.appDockAnchor(display: $0, screen: screen.frame)
        } : nil
        let anchor: ShelfAnchor?
        if case .menuBar = lastAnchor { anchor = lastAnchor }
        else { anchor = saved ?? lastAnchor }
        let fan = model.folder != nil
        let size = fan ? NSSize(width: widthForFilenames, height: FanMetrics.windowHeight(itemCount: model.entries.count))
                       : NSSize(width: 490, height: 690)
        return FanPlacement.Panel(size: size, anchor: anchor, launcherID: model.launcherID, isFan: fan)
    }

    static func scheduleLayout() {
        guard !layoutPending else { return }
        layoutPending = true
        DispatchQueue.main.async {
            layoutPending = false
            layoutVisiblePanels()
        }
    }

    private static func layoutVisiblePanels(including opening: ShelfController? = nil) {
        var shelves = ShelfPanel.visibleFans.filter { $0.isOnActiveSpace && !$0.isMiniaturized }
            .compactMap { $0.windowController as? ShelfController }
        if let opening, !shelves.contains(where: { $0 === opening }) { shelves.append(opening) }
        for (screen, group) in Dictionary(grouping: shelves, by: \.targetScreen) {
            guard let screen, let first = group.first else { continue }
            let requests = group.map { $0.panelRequest(on: screen) }
            let placements = FanPlacement.layout(requests, in: screen.visibleFrame, rightID: first.fanPositions.rightLauncherID)
            for (shelf, placement) in zip(group, placements) {
                guard let window = shelf.window else { continue }
                window.hasShadow = shelf.model.folder == nil
                if shelf.model.fanIconSide != placement.iconSide { shelf.model.fanIconSide = placement.iconSide }
                let wrapWidth = !placement.shortenedForNeighbor && shelf.widthForFilenames > placement.frame.width
                    ? placement.frame.width : nil
                if shelf.model.filenameWrapWidth != wrapWidth { shelf.model.filenameWrapWidth = wrapWidth }
                if window.frame != placement.frame { window.setFrame(placement.frame, display: true) }
            }
        }
    }

    func dismiss() {
        stopOutsideClickMonitor()
        if QLPreviewPanel.sharedPreviewPanelExists(), QLPreviewPanel.shared().currentController as AnyObject? === self {
            QLPreviewPanel.shared().orderOut(nil)
        }
        window?.orderOut(nil)
        Self.scheduleLayout()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        if window?.isVisible == true { startOutsideClickMonitor() }
    }

    func windowDidChangeScreen(_ notification: Notification) {
        guard let number = window?.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              number != presentationDisplay else { return }
        presentationDisplay = number
        Self.scheduleLayout()
    }

    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        // System menu-bar popovers may leave our app active and our panel key.
        // Observe mouse-down events in other apps only; our menus and status
        // button retain their normal behavior. No keyboard monitoring is used.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            let point = DockClick.point(of: event)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }),
               DockClick.anchor(at: point, on: screen, event: event) != nil { return }
            self?.dismissForOutsideInteraction(during: event.type == .leftMouseDown ? DockClick.currentPress : nil)
        }
    }

    private func otherApplicationActivated(_ app: NSRunningApplication) {
        guard window?.isVisible == true else { return }
        let workspace = NSWorkspace.shared
        let pid = app.processIdentifier
        if let frontmost = workspace.frontmostApplication, frontmost.processIdentifier != pid { return }
        let point = NSEvent.mouseLocation
        let press = DockClick.currentPress
        guard let press, let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }),
              DockClick.anchor(at: point, on: screen) != nil else {
            dismissForOutsideInteraction(during: press)
            return
        }
        // A Dock click can briefly activate a different process before our
        // reopen or launcher document arrives. A genuine switch still closes
        // unpinned fans if that app stays in front and no fan handled the press.
        pendingDockSwitch?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard workspace.frontmostApplication?.processIdentifier == pid else { return }
            let shelves = NSApp.windows.compactMap { $0.windowController as? ShelfController }
            guard !shelves.contains(where: { $0.dockToggle.handledPress == press }) else { return }
            self?.dismissForOutsideInteraction(during: press)
        }
        pendingDockSwitch = work
        DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: work)
    }

    private func dismissForOutsideInteraction(during press: UInt32? = nil) {
        guard let panel = window as? ShelfPanel, panel.isVisible, !model.pinned, !model.isDraggingFile,
              !ShelfPanel.visibleFans.contains(where: { $0.yieldsToFileDrag || $0.attachedSheet != nil }) else { return }
        dockToggle.didDismissOutside(during: press)
        dismiss()
    }

    static func dismissUnpinnedFans() {
        for panel in ShelfPanel.visibleFans {
            (panel.windowController as? ShelfController)?.dismissForOutsideInteraction()
        }
    }

    private func stopOutsideClickMonitor() {
        pendingDockSwitch?.cancel()
        pendingDockSwitch = nil
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    func shutdown() { stopOutsideClickMonitor() }

    func windowWillClose(_ notification: Notification) {
        stopOutsideClickMonitor()
        Self.scheduleLayout()
    }

    private func preview(_ urls: [URL], index: Int) {
        previewURLs = urls
        previewIndex = index
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible, panel.currentController as AnyObject? === self {
            panel.orderOut(nil)
        } else {
            // End search-field editing before resolving the Quick Look responder
            // chain; NSTextView can otherwise claim the preview panel itself.
            window?.makeFirstResponder(nil)
            panel.updateController()
            panel.makeKeyAndOrderFront(nil)
            if panel.currentController as AnyObject? === self {
                panel.reloadData()
                panel.currentPreviewItemIndex = previewIndex
            }
        }
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { !previewURLs.isEmpty }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.currentPreviewItemIndex = previewIndex
    }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { previewURLs.count }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! { previewURLs[index] as NSURL }
}

extension ShelfController: NSDraggingDestination {
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { dropTarget.update(sender) }
    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { dropTarget.update(sender) }
    func draggingExited(_ sender: NSDraggingInfo?) { dropTarget.clearHover() }
    func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { dropTarget.update(sender) == .copy }
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool { dropTarget.perform(sender) }
    func concludeDragOperation(_ sender: NSDraggingInfo?) { dropTarget.clearHover() }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let model = LibraryModel()
    private let fanPositions = FanPositionPreferences()
    private var controller: ShelfController!
    private var statusItem: NSStatusItem!
    private var eventMonitor: Any?
    private var dockIcon: DockIconController?
    private let visibility = DockVisibility { NSApp.setActivationPolicy($0 ? .regular : .accessory) }
    private var settings: DockSettingsController!
    private var launchers: LauncherFans!
    private var receivedLauncher = false
    private var pendingFiles: [[String]] = []
    private var launchPoint: NSPoint?

    func applicationWillFinishLaunching(_ notification: Notification) {
        launchPoint = NSEvent.mouseLocation
        visibility.restore()
        SystemAppearance.configurePreview()
        buildMenu()
        controller = ShelfController(model: model, fanPositions: fanPositions)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DownloadScroller", isDirectory: true)
        let launcherExtension = Bundle.main.object(forInfoDictionaryKey: "DownloadScrollerLauncherExtension") as? String ?? "downloadscroller"
        let store = LauncherStore(directory: support, fileExtension: launcherExtension)
        settings = DockSettingsController(store: store, visibility: visibility, fanPositions: fanPositions)
        launchers = LauncherFans(store: store, fanPositions: fanPositions)
        launchers.onShowSettings = { [weak self] shelf in self?.presentSettings(for: shelf) }
        launchers.onFolderChanged = { [weak self] in self?.settings.model.reload() }
        settings.model.onProfilesChanged = { [weak self] in self?.launchers.synchronize($0) }
        model.onShowDockSettings = { [weak self] in
            guard let self else { return }
            presentSettings(for: controller)
        }
        settings.model.onActivate = { [weak self] profile in try self?.activateLauncher(profile) }
        dockIcon = DockIconController(model: model)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "DownloadScroller")
            button.toolTip = "Open DownloadScroller"
            button.target = self
            button.action = #selector(toggleShelf)
        }
        if !ProcessInfo.processInfo.arguments.contains("--preview-onboarding") {
            if ProcessInfo.processInfo.arguments.contains("--sample-files") { model.useSamples() }
            else { model.restore() }
        }
        settings.model.reload()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let shelf = event.window?.windowController as? ShelfController,
                  shelf.window?.isKeyWindow == true else { return event }
            if shelf.model.isDraggingFile || (event.window as? ShelfPanel)?.yieldsToFileDrag == true { return event }
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) { return event }
            if event.keyCode == 53 {
                // Leave marked-text cancellation to the input method. Otherwise,
                // handle Escape even when AppKit owns focus after arrow navigation.
                if let editor = shelf.window?.firstResponder as? NSTextView, editor.hasMarkedText() { return event }
                shelf.model.handleEscape()
                return nil
            }
            let editing = shelf.window?.firstResponder is NSTextView
            if editing {
                guard [125, 126].contains(event.keyCode) else { return event }
                shelf.window?.makeFirstResponder(shelf.window?.contentView)
            }
            switch event.keyCode {
            case 125: shelf.model.moveSelection(1)
            case 126: shelf.model.moveSelection(-1)
            case 36, 76: shelf.model.open()
            case 49: shelf.model.preview()
            default: return event
            }
            return nil
        }
        let queued = pendingFiles
        pendingFiles.removeAll()
        for files in queued { handleLauncherFiles(files) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !receivedLauncher { controller.showFromDock(at: launchPoint ?? NSEvent.mouseLocation) }
        launchPoint = nil
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) { ShelfController.scheduleLayout() }
    func applicationDidUnhide(_ notification: Notification) { ShelfController.scheduleLayout() }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        receivedLauncher = true
        guard settings != nil else { pendingFiles.append(filenames); return }
        handleLauncherFiles(filenames)
    }

    private func handleLauncherFiles(_ filenames: [String]) {
        var failure: Error?
        var opened = Set<UUID>()
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let profile = try settings.model.store.resolve(url)
                if opened.insert(profile.id).inserted { try activateLauncher(profile, toggle: true) }
            }
            catch { failure = error }
        }
        if let failure {
            showDockSettings()
            settings.model.message = failure.localizedDescription
        }
        NSApp.reply(toOpenOrPrint: failure == nil ? .success : .failure)
    }

    private func activateLauncher(_ profile: LauncherProfile, toggle: Bool = false) throws {
        try launchers.open(profile, toggle: toggle)
        settings.window?.orderOut(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller.showFromDock(toggle: true)
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        launchers.shutdown()
        controller.shutdown()
        dockIcon?.stop()
        model.shutdown()
    }

    @objc private func toggleShelf() {
        if controller.window?.isVisible == true { controller.dismiss() }
        else {
            let anchor = statusItem.button.flatMap { $0.window?.convertToScreen($0.frame) }
            controller.show(anchor: anchor.map(ShelfAnchor.menuBar))
        }
    }

    private var focusedShelf: ShelfController? { NSApp.keyWindow?.windowController as? ShelfController }
    @objc private func showShelf() { controller.show() }
    @objc private func chooseFolder() {
        let shelf = focusedShelf ?? controller!
        if shelf.window?.isVisible != true { shelf.show() }
        shelf.model.chooseFolder()
    }
    @objc private func refresh() { focusedShelf?.model.refresh() }
    @objc private func find() {
        let shelf = focusedShelf ?? controller!
        if shelf.window?.isKeyWindow != true { shelf.show() }
        shelf.model.searchFocusRequest += 1
    }
    @objc private func openSelected() { focusedShelf?.model.open() }
    @objc private func previewSelected() { focusedShelf?.model.preview() }
    @objc private func revealSelected() { focusedShelf?.model.reveal() }
    @objc private func closeShelf() {
        if settings.window?.isKeyWindow == true { settings.close() }
        else { focusedShelf?.dismiss() }
    }
    @objc private func showDockSettings() {
        presentSettings(for: focusedShelf ?? controller)
    }

    private func presentSettings(for shelf: ShelfController) {
        if !shelf.model.pinned { shelf.dismiss() }
        if let id = shelf.model.launcherID { settings.model.selectedID = id }
        settings.show(currentFolder: shelf.model.folder, isSample: shelf.model.isSample)
    }

    // Contributor-only previews change this app's appearance while it is open.
    // They never write macOS preferences or appear in the normal app menu.
    @objc private func previewAppearance(_ sender: NSMenuItem) {
        let name = sender.representedObject as? String
        NSApp.appearance = name.flatMap { NSAppearance(named: NSAppearance.Name($0)) }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let openFans = ShelfPanel.visibleFans.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        for window in openFans {
            let item = menu.addItem(withTitle: window.title, action: #selector(NSWindow.makeKeyAndOrderFront(_:)), keyEquivalent: "")
            item.target = window
            item.state = window.isKeyWindow ? .on : .off
        }
        if openFans.isEmpty { menu.addItem(withTitle: "No open fans", action: nil, keyEquivalent: "") }
    }

    private func buildMenu() {
        let main = NSMenu()
        let application = NSMenu(title: "DownloadScroller")
        application.addItem(withTitle: "About DownloadScroller", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        item("Dock & Launchers…", action: #selector(showDockSettings), key: ",", in: application)
        application.addItem(.separator())
        application.addItem(withTitle: "Hide DownloadScroller", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        application.addItem(.separator())
        application.addItem(withTitle: "Quit DownloadScroller", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem(); appItem.submenu = application; main.addItem(appItem)

        let file = NSMenu(title: "File")
        item("Show Downloads", action: #selector(showShelf), key: "1", in: file)
        item("Choose Folder…", action: #selector(chooseFolder), key: "O", in: file)
        item("Open Selected File", action: #selector(openSelected), key: "o", in: file)
        item("Quick Look", action: #selector(previewSelected), key: "y", in: file)
        item("Show in Finder", action: #selector(revealSelected), key: "R", in: file)
        file.addItem(.separator())
        item("Refresh", action: #selector(refresh), key: "r", in: file)
        item("Close Window", action: #selector(closeShelf), key: "w", in: file)
        let fileItem = NSMenuItem(); fileItem.submenu = file; main.addItem(fileItem)

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        item("Find a File", action: #selector(find), key: "f", in: edit)
        let editItem = NSMenuItem(); editItem.submenu = edit; main.addItem(editItem)
        let windows = NSMenu(title: "Window")
        windows.delegate = self
        let windowItem = NSMenuItem(); windowItem.submenu = windows; main.addItem(windowItem)
        if ProcessInfo.processInfo.arguments.contains("--preview-controls") {
            let preview = NSMenu(title: "Preview Appearance")
            let appearances: [(String, NSAppearance.Name?)] = [
                ("Follow System", nil), ("Light", .aqua), ("Dark", .darkAqua)
            ]
            for (title, appearance) in appearances {
                let item = NSMenuItem(title: title, action: #selector(previewAppearance(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = appearance?.rawValue
                preview.addItem(item)
            }
            let previewItem = NSMenuItem(); previewItem.submenu = preview; main.addItem(previewItem)
        }
        NSApp.mainMenu = main
    }

    private func item(_ title: String, action: Selector, key: String, in menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }
}

@main
enum DownloadScrollerApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

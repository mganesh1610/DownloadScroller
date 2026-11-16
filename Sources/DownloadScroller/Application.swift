import AppKit
import Combine
import QuickLookUI
import SwiftUI

final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
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
    private var previewURLs: [URL] = []
    private var previewIndex = 0
    private var subscriptions = Set<AnyCancellable>()
    private var lastAnchor: NSRect?
    private var outsideClickMonitor: Any?

    init(model: LibraryModel) {
        self.model = model
        let panel = ShelfPanel(contentRect: NSRect(x: 0, y: 0, width: 490, height: 690),
                               styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.title = "DownloadScroller"
        super.init(window: panel)
        panel.delegate = self
        panel.contentView = TransparentHostingView(rootView: RootView(model: model))
        model.onDismiss = { [weak self] in self?.dismiss() }
        model.onPreview = { [weak self] urls, index in self?.preview(urls, index: index) }
        model.$folder.sink { [weak self] _ in
            DispatchQueue.main.async { self?.positionWindow() }
        }.store(in: &subscriptions)
        model.$entries.map(\.count).removeDuplicates().dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async {
                guard self?.model.folder != nil else { return }
                self?.positionWindow()
            }
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in self?.dismissForOutsideInteraction() }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didHideNotification)
            .sink { [weak self] _ in self?.stopOutsideClickMonitor() }
            .store(in: &subscriptions)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(anchor: NSRect? = nil) {
        guard let window else { return }
        lastAnchor = anchor
        positionWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        startOutsideClickMonitor()
        model.refresh()
    }

    private func positionWindow() {
        guard let window else { return }
        let anchor = lastAnchor
        let mouse = NSEvent.mouseLocation
        let screen = window.isVisible ? window.screen : NSScreen.screens.first { $0.frame.contains(anchor?.origin ?? mouse) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let fan = model.folder != nil
        let count = CGFloat(max(1, model.entries.count))
        let fanHeight = min(820, max(260, count * 74 + min(125, max(16, (count - 1) * 14)) + 140))
        let size = NSSize(width: min(fan ? 620 : 490, visible.width - 24), height: min(fan ? fanHeight : 690, visible.height - 24))
        window.hasShadow = !fan
        let x: CGFloat
        let y: CGFloat
        if let anchor {
            x = min(max(anchor.midX - size.width / 2, visible.minX + 12), visible.maxX - size.width - 12)
            y = max(visible.minY + 12, anchor.minY - size.height - 8)
        } else {
            // Dock coordinates are not exposed publicly. Use the screen's usable edge.
            x = visible.maxX - size.width - 14
            y = visible.minY + 14
        }
        window.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }

    func dismiss() {
        stopOutsideClickMonitor()
        if QLPreviewPanel.sharedPreviewPanelExists(), QLPreviewPanel.shared().currentController as AnyObject? === self {
            QLPreviewPanel.shared().orderOut(nil)
        }
        window?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window?.isKeyWindow == false else { return }
            // A folder picker or our own Quick Look panel is part of this session.
            if QLPreviewPanel.sharedPreviewPanelExists(),
               QLPreviewPanel.shared().currentController as AnyObject? === self,
               QLPreviewPanel.shared().isVisible, NSApp.isActive { return }
            self.dismissForOutsideInteraction()
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        if window?.isVisible == true { startOutsideClickMonitor() }
    }

    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        // System menu-bar popovers may leave our app active and our panel key.
        // Observe mouse-down events in other apps only; our menus and status
        // button retain their normal behavior. No keyboard monitoring is used.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.dismissForOutsideInteraction()
        }
    }

    private func dismissForOutsideInteraction() {
        guard window?.isVisible == true, !model.pinned, window?.attachedSheet == nil else { return }
        dismiss()
    }

    private func stopOutsideClickMonitor() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    func shutdown() { stopOutsideClickMonitor() }

    func windowWillClose(_ notification: Notification) { stopOutsideClickMonitor() }

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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = LibraryModel()
    private var controller: ShelfController!
    private var statusItem: NSStatusItem!
    private var eventMonitor: Any?
    private var dockIcon: DockIconController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        controller = ShelfController(model: model)
        dockIcon = DockIconController(model: model)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "DownloadScroller")
            button.toolTip = "Open DownloadScroller"
            button.target = self
            button.action = #selector(toggleShelf)
        }
        if ProcessInfo.processInfo.arguments.contains("--sample-files") { model.useSamples() }
        else { model.restore() }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.controller.window?.isKeyWindow == true else { return event }
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) { return event }
            let editing = self.controller.window?.firstResponder is NSTextView
            if editing {
                guard [125, 126].contains(event.keyCode) else { return event }
                self.controller.window?.makeFirstResponder(self.controller.window?.contentView)
            }
            switch event.keyCode {
            case 125: self.model.moveSelection(1)
            case 126: self.model.moveSelection(-1)
            case 36, 76: self.model.open()
            case 49: self.model.preview()
            case 53: self.controller.dismiss()
            default: return event
            }
            return nil
        }
        controller.show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller.show()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        controller.shutdown()
        dockIcon?.stop()
        model.shutdown()
    }

    @objc private func toggleShelf() {
        if controller.window?.isVisible == true { controller.dismiss() }
        else {
            let anchor = statusItem.button.flatMap { $0.window?.convertToScreen($0.frame) }
            controller.show(anchor: anchor)
        }
    }

    @objc private func showShelf() { controller.show() }
    @objc private func chooseFolder() { controller.show(); model.chooseFolder() }
    @objc private func refresh() { model.refresh() }
    @objc private func find() { controller.show(); model.searchFocusRequest += 1 }
    @objc private func openSelected() { model.open() }
    @objc private func previewSelected() { model.preview() }
    @objc private func revealSelected() { model.reveal() }
    @objc private func closeShelf() { controller.dismiss() }

    private func buildMenu() {
        let main = NSMenu()
        let application = NSMenu(title: "DownloadScroller")
        application.addItem(withTitle: "About DownloadScroller", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
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

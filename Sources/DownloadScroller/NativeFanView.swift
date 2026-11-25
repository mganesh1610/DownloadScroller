import AppKit
import QuartzCore
import SwiftUI
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

struct FanScrollIdentity: Equatable {
    let folder: URL?
    let search: String
    let filter: FileKind?
    let sort: FileSort
    let openRequest: Int
}

struct NativeFanView: NSViewRepresentable {
    @ObservedObject var model: LibraryModel
    var reduceMotion: Bool

    func makeNSView(context: Context) -> FanScrollView { FanScrollView() }
    func updateNSView(_ view: FanScrollView, context: Context) {
        view.canvas.open = { [weak model, weak view] entry in
            view?.window?.makeFirstResponder(view?.canvas)
            model?.selectedID = entry.id
            model?.open(entry)
        }
        view.canvas.preview = { [weak model] in model?.preview($0) }
        view.canvas.reveal = { [weak model] in model?.reveal($0) }
        view.canvas.select = { [weak model] in model?.selectedID = $0.id }
        view.canvas.folderAccess = model.folderAccess
        view.canvas.dragStateChanged = { [weak model] in model?.isDraggingFile = $0 }
        view.canvas.dragFinished = { [weak model] operation in
            if !operation.isEmpty, model?.pinned == false { model?.onDismiss?() }
        }
        view.canvas.iconSide = model.fanIconSide
        view.reduceMotion = reduceMotion
        view.configure(entries: model.visibleEntries, selected: model.selectedID,
                       identity: FanScrollIdentity(folder: model.folder, search: model.search, filter: model.filter,
                                                   sort: model.sort, openRequest: model.fanOpenRequest),
                       selectionRequest: model.selectionScrollRequest, wrapWidth: model.filenameWrapWidth)
    }
    static func dismantleNSView(_ view: FanScrollView, coordinator: ()) { view.stopMotion() }
}

/// One fixed-height document. Only visible rows are retained, so scrolling
/// neither estimates lazy row sizes nor asks SwiftUI to lay out transformed rows.
final class FanScrollView: NSScrollView {
    let canvas = FanCanvas()
    var reduceMotion = false { didSet { canvas.reduceMotion = reduceMotion } }
    private var motion = WheelMotion()
    private var frameLink: CADisplayLink?
    private var lastFrame: CFTimeInterval = 0
    private var identity: FanScrollIdentity?
    private var selectionRequest = 0
    private var clipObserver: NSObjectProtocol?
    private let edgeFade = CAGradientLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        drawsBackground = false
        hasVerticalScroller = false
        hasHorizontalScroller = false
        horizontalScrollElasticity = .none
        verticalScrollElasticity = .none
        usesPredominantAxisScrolling = true
        wantsLayer = true
        // Fade cropped rows into the desktop instead of ending at a hard line.
        edgeFade.colors = [NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]
        edgeFade.startPoint = CGPoint(x: 0.5, y: 0)
        edgeFade.endPoint = CGPoint(x: 0.5, y: 1)
        layer?.mask = edgeFade
        documentView = canvas
        contentView.postsBoundsChangedNotifications = true
        clipObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
                                                              object: contentView, queue: .main) { [weak self] _ in
            self?.canvas.updateVisibleRows()
        }
        setAccessibilityLabel("Scrollable file fan")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { if let clipObserver { NotificationCenter.default.removeObserver(clipObserver) } }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        edgeFade.frame = bounds
        let fade = min(0.2, 18 / max(1, bounds.height))
        edgeFade.locations = [0, NSNumber(value: Double(fade)), NSNumber(value: Double(1 - fade)), 1]
        CATransaction.commit()
        canvas.resize(to: contentView.bounds.size)
    }

    func configure(entries: [FileEntry], selected: String?, identity: FanScrollIdentity, selectionRequest: Int, wrapWidth: CGFloat? = nil) {
        let reset = self.identity != identity
        self.identity = identity
        if reset { canvas.resetHighlight() }
        if reset || canvas.entries != entries || canvas.wrapWidth != wrapWidth { stopMotion() }
        canvas.replace(entries: entries, reset: reset, wrapWidth: wrapWidth)
        canvas.resize(to: contentView.bounds.size)
        canvas.selectedID = selected
        if self.selectionRequest != selectionRequest {
            stopMotion()
            self.selectionRequest = selectionRequest
            canvas.showsKeyboardSelection = true
            canvas.revealSelection()
        }
        canvas.updateVisibleRows()
    }

    override func scrollWheel(with event: NSEvent) {
        // AppKit handles precise devices, including their existing momentum stream.
        guard !event.hasPreciseScrollingDeltas, !reduceMotion else {
            stopMotion()
            super.scrollWheel(with: event)
            return
        }
        guard event.scrollingDeltaY != 0 else { return }
        if frameLink == nil { motion.reset(to: contentView.bounds.minY) }
        motion.push(-event.scrollingDeltaY * 16, maximum: maximumOffset)
        guard motion.isMoving else { return }
        if frameLink == nil {
            lastFrame = CACurrentMediaTime()
            let link = displayLink(target: self, selector: #selector(animateWheel(_:)))
            link.add(to: .main, forMode: .common)
            frameLink = link
        }
    }

    private var maximumOffset: Double { max(0, canvas.bounds.height - contentView.bounds.height) }

    @objc private func animateWheel(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        let y = motion.advance(seconds: min(now - lastFrame, 1.0 / 15), maximum: maximumOffset)
        lastFrame = now
        contentView.scroll(to: NSPoint(x: 0, y: y))
        reflectScrolledClipView(contentView)
        if !motion.isMoving { stopMotion() }
    }

    func stopMotion() { frameLink?.invalidate(); frameLink = nil }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { stopMotion() }
        super.viewWillMove(toWindow: newWindow)
    }
}

final class FanCanvas: NSView, NSDraggingSource {
    private(set) var entries: [FileEntry] = []
    var selectedID: String?
    var showsKeyboardSelection = false {
        didSet { if showsKeyboardSelection { hoverPointInWindow = nil } }
    }
    var reduceMotion = false
    var iconSide = FanIconSide.right
    var open: ((FileEntry) -> Void)?
    var preview: ((FileEntry) -> Void)?
    var reveal: ((FileEntry) -> Void)?
    var select: ((FileEntry) -> Void)?
    var dragStateChanged: ((Bool) -> Void)?
    var dragFinished: ((NSDragOperation) -> Void)?
    weak var folderAccess: FolderAccess?
    private var press: FanFilePress?
    private var draggingFile = false
    var acceptedByFan = false
    var draggedFile: FanFilePress? { draggingFile ? press : nil }
    private var sourcePanel: ShelfPanel?
    private var receivingPanels: [ShelfPanel] = []
    var dropFolderID: String? {
        didSet { if oldValue != dropFolderID { updateVisibleRows() } }
    }
    private var rows: [String: FanRowView] = [:]
    private var hoverPointInWindow: NSPoint?
    private var tracking: NSTrackingArea?
    private var viewport = NSSize.zero
    private var contextEntry: FileEntry?
    private var accessibleIDs: [String] = []
    private var updating = false
    private(set) var wrapWidth: CGFloat?
    private var wrappedTextHeights: [String: CGFloat] = [:]
    private var stride = FanMetrics.rowStride
    private var needsBottomPosition = true
    private var topInset: CGFloat {
        let clearance = FanMetrics.topClearance(itemCount: entries.count, reduceMotion: reduceMotion)
        return max(clearance, viewport.height - CGFloat(entries.count) * stride - 12)
    }
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        // Fully transparent window pixels otherwise pass scrolling to the app behind.
        layer?.backgroundColor = NSColor.black.withAlphaComponent(1.0 / 255).cgColor
        setAccessibilityElement(true)
        setAccessibilityRole(.list)
        setAccessibilityLabel("Files")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        (window as? ShelfPanel)?.canvas = self
    }

    func replace(entries: [FileEntry], reset: Bool, wrapWidth: CGFloat?) {
        guard self.entries != entries || self.wrapWidth != wrapWidth || reset else { return }
        let offset = enclosingScrollView?.contentView.bounds.minY ?? 0
        let wasAtBottom = offset >= max(0, bounds.height - viewport.height) - 1
        let anchorIndex = min(max(Int((offset - topInset) / stride), 0), max(self.entries.count - 1, 0))
        let anchor = self.entries.indices.contains(anchorIndex) ? self.entries[anchorIndex].id : nil
        let relative = offset - (topInset + CGFloat(anchorIndex) * stride)
        let followBottom = reset || self.entries.isEmpty || wasAtBottom
        self.entries = entries
        self.wrapWidth = wrapWidth
        wrappedTextHeights = wrapWidth.map { FanMetrics.wrappedTextHeights(for: entries.lazy.map(\.name), panelWidth: $0) } ?? [:]
        stride = max(FanMetrics.rowStride, (wrappedTextHeights.values.max() ?? 18) + 24)
        needsBottomPosition = followBottom
        resize(to: enclosingScrollView?.contentView.bounds.size ?? viewport)
        if !followBottom, let clip = enclosingScrollView?.contentView {
            var y = offset
            if let anchor, let index = entries.firstIndex(where: { $0.id == anchor }) {
                y = topInset + CGFloat(index) * stride + relative
            }
            clip.scroll(to: NSPoint(x: 0, y: min(max(y, 0), max(0, bounds.height - clip.bounds.height))))
        }
        updateVisibleRows()
    }

    func resize(to size: NSSize) {
        let clip = enclosingScrollView?.contentView
        if viewport.height != size.height, let clip,
           clip.bounds.minY >= max(0, bounds.height - viewport.height) - 1 {
            needsBottomPosition = true
        }
        viewport = size
        let height = max(size.height, topInset + CGFloat(entries.count) * stride + 12)
        if frame.size != NSSize(width: size.width, height: height) {
            setFrameSize(NSSize(width: size.width, height: height))
        }
        if needsBottomPosition, size.height > 0, size.width > 0, let clip {
            clip.scroll(to: NSPoint(x: 0, y: max(0, height - size.height)))
            enclosingScrollView?.reflectScrolledClipView(clip)
            needsBottomPosition = false
        }
        updateVisibleRows()
    }

    // Native material and image subviews are decorative; the canvas owns the
    // rotated hit regions and the full scroll surface, including empty space.
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    func updateVisibleRows() {
        guard !updating, viewport.width > 0, layer != nil else { return }
        updating = true
        defer { updating = false }
        let visible = enclosingScrollView?.contentView.bounds ?? bounds
        let start = min(entries.count, max(0, Int(floor((visible.minY - topInset - 80) / stride))))
        let end = min(entries.count, max(start, Int(ceil((visible.maxY - topInset + 190) / stride))))
        let keep = Set(entries[start..<end].map(\.id))
        var accessibilityChanged = false
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for id in Array(rows.keys) where !keep.contains(id) { rows.removeValue(forKey: id)?.removeFromSuperview() }
        for index in start..<end {
            let entry = entries[index]
            let row: FanRowView
            if let existing = rows[entry.id], existing.entry == entry { row = existing }
            else {
                rows.removeValue(forKey: entry.id)?.removeFromSuperview()
                row = FanRowView(entry: entry, parent: self)
                rows[entry.id] = row
                accessibilityChanged = true
                addSubview(row)
            }
            let extraInset = (stride - FanMetrics.rowStride) / 2
            let center = topInset + CGFloat(index) * stride + 24 + extraInset
            let amount = min(1, CGFloat(max(0, entries.count - 1)) / 8)
            let progress = 1 - (1 - min(max((center - visible.minY) / max(1, visible.height - FanMetrics.bottomRowCenterInset - extraInset), 0), 1)) * amount
            let angle = reduceMotion ? 0 : 16 * pow(1 - progress, 1.15) * .pi / 180
            let inset = FanMetrics.iconInset - 22 - 34 * (1 - pow(progress, 1.7))
            let edge = iconSide == .left ? inset : viewport.width - inset
            row.arrange(edge: edge, center: center, angle: angle, iconSide: iconSide,
                        maxLabelWidth: FanMetrics.maximumLabelWidth(in: viewport.width), wrappedTextHeight: wrappedTextHeights[entry.name])
        }
        // A stationary pointer can move onto another file as rows scroll underneath it.
        updateHighlights(for: hoverPointInWindow.flatMap { row(atWindowPoint: $0) })
        CATransaction.commit()
        let ids = (start..<end).map { entries[$0].id }
        if accessibleIDs != ids || accessibilityChanged {
            accessibleIDs = ids
            setAccessibilityChildren(ids.compactMap { rows[$0]?.accessibility })
        }
    }

    func revealSelection() {
        guard let id = selectedID, let index = entries.firstIndex(where: { $0.id == id }), let scroll = enclosingScrollView else { return }
        let clip = scroll.contentView
        let top = topInset + CGFloat(index) * stride - (reduceMotion ? 0 : 110)
        let bottom = topInset + CGFloat(index) * stride + stride - 6
        var y = clip.bounds.minY
        if top < y { y = max(0, top) }
        else if bottom > clip.bounds.maxY { y = bottom - clip.bounds.height }
        clip.scroll(to: NSPoint(x: 0, y: min(y, max(0, bounds.height - clip.bounds.height))))
        scroll.reflectScrolledClipView(clip)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let tracking = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(tracking)
        self.tracking = tracking
    }

    private func row(at event: NSEvent) -> FanRowView? {
        row(atWindowPoint: event.locationInWindow)
    }
    private func row(atWindowPoint location: NSPoint) -> FanRowView? {
        let point = convert(location, from: nil)
        guard visibleRect.contains(point) else { return nil }
        return rows.values.first { $0.contains(pointInCanvas: point) }
    }
    func folderRow(atWindowPoint location: NSPoint) -> FileEntry? {
        guard let entry = row(atWindowPoint: location)?.entry, entry.kind == .folders else { return nil }
        return entry
    }
    private func updateHighlights(for hovered: FanRowView?) {
        if toolTip != hovered?.entry.name { toolTip = hovered?.entry.name }
        for row in rows.values {
            row.updateHighlight(hovered === row || dropFolderID == row.entry.id,
                                selected: showsKeyboardSelection && selectedID == row.entry.id)
        }
    }

    func resetHighlight() {
        hoverPointInWindow = nil
        showsKeyboardSelection = false
        toolTip = nil
    }
    override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
    override func mouseMoved(with event: NSEvent) {
        guard !draggingFile else { return }
        hoverPointInWindow = event.locationInWindow
        let hovered = row(at: event)
        guard showsKeyboardSelection || toolTip != hovered?.entry.name else { return }
        showsKeyboardSelection = false
        updateHighlights(for: hovered)
    }
    override func mouseExited(with event: NSEvent) {
        hoverPointInWindow = nil
        updateHighlights(for: nil)
    }
    override func mouseDown(with event: NSEvent) {
        (enclosingScrollView as? FanScrollView)?.stopMotion()
        guard !draggingFile else { return }
        press = nil
        guard let entry = row(at: event)?.entry else {
            ShelfController.dismissUnpinnedFans()
            return
        }
        guard let folderAccess else { return }
        window?.makeFirstResponder(self)
        press = FanFilePress(entry: entry, mouseDown: event, access: folderAccess)
        select?(entry)
    }
    override func mouseUp(with event: NSEvent) {
        guard !draggingFile else { return }
        defer { press = nil }
        guard let press, row(at: event)?.entry.id == press.entry.id else { return }
        open?(press.entry)
    }
    override func mouseDragged(with event: NSEvent) {
        guard !draggingFile, let press, press.crossedDragThreshold(at: event.locationInWindow) else { return }
        draggingFile = true
        hoverPointInWindow = nil
        updateHighlights(for: nil)
        acceptedByFan = false
        dragStateChanged?(true)
        let store = ThumbnailStore.shared
        let item = press.draggingItem(in: self, image: store.cached(for: press.entry) ?? store.icon(for: press.entry))
        let session = beginDraggingSession(with: [item], event: press.mouseDown, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        // Uncover Finder under the source. The other fans remain destinations,
        // including the otherwise transparent space in an empty fan.
        sourcePanel = window as? ShelfPanel
        sourcePanel?.yieldsToFileDrag = true
        receivingPanels = ShelfPanel.visibleFans.filter { $0 !== sourcePanel && ($0.windowController as? ShelfController)?.model.folder != nil }
        for panel in receivingPanels {
            panel.backgroundColor = .controlAccentColor.withAlphaComponent(0.05)
            (panel.windowController as? ShelfController)?.model.availableForFanDrop = true
        }
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        sourcePanel?.yieldsToFileDrag = false
        sourcePanel = nil
        for panel in receivingPanels {
            panel.backgroundColor = .clear
            if let shelf = panel.windowController as? ShelfController {
                shelf.model.availableForFanDrop = false
                shelf.dropTarget.clearHover()
            }
        }
        receivingPanels.removeAll()
        press = nil
        draggingFile = false
        dragStateChanged?(false)
        resetHighlight()
        updateVisibleRows()
        if !acceptedByFan { dragFinished?(operation) }
        acceptedByFan = false
    }
    override func menu(for event: NSEvent) -> NSMenu? {
        guard let row = row(at: event) else { return nil }
        contextEntry = row.entry
        let menu = NSMenu()
        for (title, action) in [("Open", #selector(openContext)), ("Quick Look", #selector(previewContext)), ("Show in Finder", #selector(revealContext))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        if let access = folderAccess {
            let destinations = NSMenu()
            for panel in ShelfPanel.visibleFans where panel !== window {
                (panel.windowController as? ShelfController)?.dropTarget.appendMenu(to: destinations, file: row.entry.url, access: access)
            }
            if destinations.numberOfItems > 0 {
                menu.addItem(.separator())
                menu.addItem(withTitle: "Copy to Open Fan", action: nil, keyEquivalent: "").submenu = destinations
            }
        }
        return menu
    }
    @objc private func openContext() { if let contextEntry { open?(contextEntry) } }
    @objc private func previewContext() { if let contextEntry { preview?(contextEntry) } }
    @objc private func revealContext() { if let contextEntry { reveal?(contextEntry) } }
}

@MainActor
private final class FanFileAccessibility: NSAccessibilityElement {
    weak var canvas: FanCanvas?
    weak var row: FanRowView?
    override func accessibilityFrame() -> NSRect {
        guard let canvas, let row, let window = canvas.window else { return .zero }
        return window.convertToScreen(canvas.convert(row.visualFrame, to: nil))
    }
    override func accessibilityPerformPress() -> Bool {
        guard let row, let canvas else { return false }
        canvas.open?(row.entry)
        return true
    }
}

@MainActor
private final class FanRowView: NSView {
    let entry: FileEntry
    let accessibility = FanFileAccessibility()
    private let capsule = FanLabelSurface()
    private let label: NSTextField
    private let icon = NSImageView()
    private var thumbnailTask: Task<Void, Never>?
    private var colorObserver: NSObjectProtocol?
    private var labelWidth: CGFloat = 0
    private var naturalWidth: CGFloat = 0
    private var highlighted = false
    override var isFlipped: Bool { true }
    override func makeBackingLayer() -> CALayer {
        let shape = CAShapeLayer()
        shape.fillColor = nil
        shape.actions = ["fillColor": NSNull()]
        return shape
    }

    init(entry: FileEntry, parent: FanCanvas) {
        self.entry = entry
        label = FanMetrics.filenameLabel(entry.name)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.allowsEdgeAntialiasing = true
        setAccessibilityElement(false)
        label.setAccessibilityElement(false)
        naturalWidth = ceil(label.fittingSize.width) + FanMetrics.labelPadding
        capsule.content.addSubview(label)
        addSubview(capsule)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.wantsLayer = true
        icon.layer?.allowsEdgeAntialiasing = true
        icon.layer?.minificationFilter = .trilinear
        icon.layer?.magnificationFilter = .linear
        icon.setAccessibilityElement(false)
        addSubview(icon)
        accessibility.canvas = parent
        accessibility.row = self
        accessibility.setAccessibilityParent(parent)
        accessibility.setAccessibilityRole(.button)
        accessibility.setAccessibilityEnabled(true)
        accessibility.setAccessibilityLabel(entry.name)
        accessibility.setAccessibilityValue(entry.kind.title)
        accessibility.setAccessibilityHelp("Click to open, or drag the file into a folder or another app. Use Space for Quick Look or the context menu to reveal in Finder.")
        colorObserver = NotificationCenter.default.addObserver(forName: NSColor.systemColorsDidChangeNotification,
                                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.updateColors() }
        }
        let store = ThumbnailStore.shared
        icon.image = store.cached(for: entry) ?? store.icon(for: entry)
        thumbnailTask = Task { @MainActor [weak self] in
            let image = await store.image(for: entry)
            guard !Task.isCancelled else { return }
            self?.icon.image = image
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        thumbnailTask?.cancel()
        if let colorObserver { NotificationCenter.default.removeObserver(colorObserver) }
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); updateColors() }

    private func updateColors() {
        capsule.highlighted = highlighted
        effectiveAppearance.performAsCurrentDrawingAppearance {
            (layer as? CAShapeLayer)?.fillColor = highlighted ? NSColor.selectedContentBackgroundColor.cgColor : nil
        }
        label.textColor = highlighted ? .selectedMenuItemTextColor : .labelColor
    }

    func arrange(edge: CGFloat, center: CGFloat, angle: CGFloat, iconSide: FanIconSide,
                 maxLabelWidth: CGFloat, wrappedTextHeight: CGFloat?) {
        labelWidth = min(naturalWidth, maxLabelWidth)
        let textHeight = wrappedTextHeight ?? 18
        let capsuleHeight = textHeight + 6
        let wraps = wrappedTextHeight != nil
        if wraps != (label.maximumNumberOfLines == 0) { FanMetrics.setWrapping(wraps, on: label) }
        // Use AppKit's view transform so native text and backdrop geometry stay
        // in sync. Directly transforming an AppKit-managed layer loses geometry
        // when the view lays out its material and text subviews.
        let size = NSSize(width: labelWidth + FanMetrics.fileIconAndGap, height: max(48, capsuleHeight + 8))
        if bounds.size != size {
            frameRotation = 0
            setFrameSize(size)
            setBoundsSize(size)
        }
        let onLeft = iconSide == .left
        // Keep the raised end of a long name within the fan's vertical clearance.
        let usualRowWidth = FanMetrics.defaultWidth - FanMetrics.canvasGutter
        let tilt = size.width > usualRowWidth ? asin(sin(angle) * usualRowWidth / size.width) : angle
        frameRotation = (onLeft ? -tilt : tilt) * 180 / .pi
        let anchor = convert(NSPoint(x: onLeft ? 0 : bounds.width, y: bounds.midY), to: superview)
        setFrameOrigin(NSPoint(x: frame.origin.x + edge - anchor.x, y: frame.origin.y + center - anchor.y))
        let labelFrame = CGRect(x: onLeft ? FanMetrics.fileIconAndGap : 0, y: bounds.midY - capsuleHeight / 2,
                                width: labelWidth, height: capsuleHeight)
        if capsule.frame != labelFrame {
            capsule.frame = labelFrame
            // Draw the angled edge inside the taller row, clear of the glass's clipping boundary.
            let rect = convertToLayer(labelFrame)
            let radius = min(12, rect.height / 2)
            (layer as? CAShapeLayer)?.path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        }
        label.frame = CGRect(x: FanMetrics.textInset, y: 3, width: labelWidth - 2 * FanMetrics.textInset, height: textHeight)
        icon.frame = CGRect(x: onLeft ? 0 : labelWidth + 10, y: bounds.midY - 22, width: 44, height: 44)
    }

    func updateHighlight(_ highlighted: Bool, selected: Bool) {
        if self.highlighted != (highlighted || selected) {
            self.highlighted = highlighted || selected
            updateColors()
        }
        if accessibility.isAccessibilitySelected() != selected { accessibility.setAccessibilitySelected(selected) }
    }

    var visualFrame: NSRect { convert(bounds, to: superview) }

    func contains(pointInCanvas point: CGPoint) -> Bool {
        let local = convert(point, from: superview)
        return capsule.frame.union(icon.frame).contains(local)
    }
}

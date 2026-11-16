import AppKit
import QuartzCore
import SwiftUI
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

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
        view.reduceMotion = reduceMotion
        view.configure(entries: model.visibleEntries, selected: model.selectedID,
                       query: "\(model.folder?.path ?? "")|\(model.search)|\(model.filter?.rawValue ?? "")|\(model.sort.rawValue)|\(model.fanOpenRequest)",
                       selectionRequest: model.selectionScrollRequest)
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
    private var query = ""
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

    func configure(entries: [FileEntry], selected: String?, query: String, selectionRequest: Int) {
        let reset = self.query != query
        self.query = query
        if reset { canvas.resetHighlight() }
        if reset || canvas.entries != entries { stopMotion() }
        canvas.replace(entries: entries, reset: reset)
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

final class FanCanvas: NSView {
    private(set) var entries: [FileEntry] = []
    var selectedID: String?
    var showsKeyboardSelection = false
    var reduceMotion = false
    var open: ((FileEntry) -> Void)?
    var preview: ((FileEntry) -> Void)?
    var reveal: ((FileEntry) -> Void)?
    private var rows: [String: FanRowView] = [:]
    private var hoveredID: String?
    private var tracking: NSTrackingArea?
    private var viewport = NSSize.zero
    private var contextEntry: FileEntry?
    private var accessibleIDs: [String] = []
    private var updating = false
    private let stride: CGFloat = 58
    private var needsBottomPosition = true
    private var topInset: CGFloat {
        let clearance: CGFloat = reduceMotion ? 20 : min(112, max(20, CGFloat(entries.count - 1) * 14))
        return max(clearance, viewport.height - CGFloat(entries.count) * stride - 12)
    }
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

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

    func replace(entries: [FileEntry], reset: Bool) {
        guard self.entries != entries || reset else { return }
        let offset = enclosingScrollView?.contentView.bounds.minY ?? 0
        let wasAtBottom = offset >= max(0, bounds.height - viewport.height) - 1
        let anchorIndex = min(max(Int((offset - topInset) / stride), 0), max(self.entries.count - 1, 0))
        let anchor = self.entries.indices.contains(anchorIndex) ? self.entries[anchorIndex].id : nil
        let relative = offset - (topInset + CGFloat(anchorIndex) * stride)
        let followBottom = reset || self.entries.isEmpty || wasAtBottom
        self.entries = entries
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
            let center = topInset + CGFloat(index) * stride + 24
            let amount = min(1, CGFloat(max(0, entries.count - 1)) / 8)
            let progress = 1 - (1 - min(max((center - visible.minY) / max(1, visible.height), 0), 1)) * amount
            let angle = reduceMotion ? 0 : 16 * pow(1 - progress, 1.15) * .pi / 180
            let edge = viewport.width - 46 + 34 * (1 - pow(progress, 1.7))
            row.arrange(right: edge, center: center, angle: angle, maxWidth: max(120, viewport.width - 88),
                        highlighted: hoveredID == entry.id, selected: showsKeyboardSelection && selectedID == entry.id)
        }
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
        let bottom = topInset + CGFloat(index) * stride + 52
        var y = clip.bounds.minY
        if top < y { y = max(0, top) }
        else if bottom > clip.bounds.maxY { y = bottom - clip.bounds.height }
        clip.scroll(to: NSPoint(x: 0, y: min(y, max(0, bounds.height - clip.bounds.height))))
        scroll.reflectScrolledClipView(clip)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let tracking = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(tracking)
        self.tracking = tracking
    }

    private func row(at event: NSEvent) -> FanRowView? {
        let point = convert(event.locationInWindow, from: nil)
        return rows.values.first { $0.contains(pointInCanvas: point) }
    }
    func resetHighlight() { hoveredID = nil; showsKeyboardSelection = false }
    override func mouseMoved(with event: NSEvent) {
        let id = row(at: event)?.entry.id
        if id != hoveredID || showsKeyboardSelection {
            hoveredID = id
            showsKeyboardSelection = false
            updateVisibleRows()
        }
    }
    override func mouseExited(with event: NSEvent) { hoveredID = nil; updateVisibleRows() }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if let row = row(at: event) { open?(row.entry) }
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

    init(entry: FileEntry, parent: FanCanvas) {
        self.entry = entry
        label = NSTextField(labelWithString: entry.name)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.allowsEdgeAntialiasing = true
        setAccessibilityElement(false)
        label.font = .systemFont(ofSize: 12.5)
        label.lineBreakMode = .byTruncatingMiddle
        label.maximumNumberOfLines = 1
        label.cell?.usesSingleLineMode = true
        label.alignment = .center
        label.setAccessibilityElement(false)
        naturalWidth = ceil(label.fittingSize.width) + 24
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
        accessibility.setAccessibilityHelp("Open file. Use Space for Quick Look or the context menu to reveal in Finder.")
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
        label.textColor = highlighted ? .selectedMenuItemTextColor : .labelColor
    }

    func arrange(right: CGFloat, center: CGFloat, angle: CGFloat, maxWidth: CGFloat, highlighted: Bool, selected: Bool) {
        labelWidth = min(naturalWidth, maxWidth - 54)
        // Use AppKit's view transform so native text and backdrop geometry stay
        // in sync. Directly transforming an AppKit-managed layer loses geometry
        // when the view lays out its material and text subviews.
        let size = NSSize(width: labelWidth + 54, height: 48)
        if bounds.size != size {
            frameRotation = 0
            setFrameSize(size)
            setBoundsSize(size)
        }
        frameRotation = angle * 180 / .pi
        let anchor = convert(NSPoint(x: bounds.width, y: 24), to: superview)
        setFrameOrigin(NSPoint(x: frame.origin.x + right - anchor.x, y: frame.origin.y + center - anchor.y))
        capsule.frame = CGRect(x: 0, y: 12, width: labelWidth, height: 24)
        label.frame = CGRect(x: 11, y: 3, width: labelWidth - 22, height: 18)
        icon.frame = CGRect(x: labelWidth + 10, y: 2, width: 44, height: 44)
        if self.highlighted != (highlighted || selected) {
            self.highlighted = highlighted || selected
            updateColors()
        }
        accessibility.setAccessibilitySelected(selected)
    }

    var visualFrame: NSRect { convert(bounds, to: superview) }

    func contains(pointInCanvas point: CGPoint) -> Bool {
        let local = convert(point, from: superview)
        return capsule.frame.contains(local) || icon.frame.contains(local)
    }
}

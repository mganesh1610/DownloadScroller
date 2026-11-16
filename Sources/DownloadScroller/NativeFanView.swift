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
                       query: "\(model.folder?.path ?? "")|\(model.search)|\(model.filter?.rawValue ?? "")|\(model.sort.rawValue)",
                       selectionRequest: model.selectionScrollRequest)
    }
    static func dismantleNSView(_ view: FanScrollView, coordinator: ()) { view.stopMotion() }
}

/// One fixed-height document. Only visible layers are retained, so scrolling
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

    override init(frame: NSRect) {
        super.init(frame: frame)
        drawsBackground = false
        hasVerticalScroller = false
        hasHorizontalScroller = false
        horizontalScrollElasticity = .none
        verticalScrollElasticity = .none
        usesPredominantAxisScrolling = true
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
        canvas.resize(to: contentView.bounds.size)
    }

    func configure(entries: [FileEntry], selected: String?, query: String, selectionRequest: Int) {
        let reset = self.query != query
        self.query = query
        if reset || canvas.entries != entries { stopMotion() }
        canvas.replace(entries: entries, reset: reset)
        canvas.resize(to: contentView.bounds.size)
        canvas.selectedID = selected
        if self.selectionRequest != selectionRequest {
            stopMotion()
            self.selectionRequest = selectionRequest
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
    var reduceMotion = false
    var open: ((FileEntry) -> Void)?
    var preview: ((FileEntry) -> Void)?
    var reveal: ((FileEntry) -> Void)?
    private var rows: [String: FanRowLayer] = [:]
    private var hoveredID: String?
    private var tracking: NSTrackingArea?
    private var viewport = NSSize.zero
    private var contextEntry: FileEntry?
    private var accessibleIDs: [String] = []
    private var updating = false
    private let stride: CGFloat = 74
    private var topInset: CGFloat {
        let clearance: CGFloat = reduceMotion ? 20 : min(128, max(20, CGFloat(entries.count - 1) * 16))
        return max(clearance, viewport.height - CGFloat(entries.count) * stride - 22)
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
        let anchorIndex = min(max(Int((offset - topInset) / stride), 0), max(self.entries.count - 1, 0))
        let anchor = self.entries.indices.contains(anchorIndex) ? self.entries[anchorIndex].id : nil
        let relative = offset - (topInset + CGFloat(anchorIndex) * stride)
        self.entries = entries
        resize(to: enclosingScrollView?.contentView.bounds.size ?? viewport)
        if let clip = enclosingScrollView?.contentView {
            var y: CGFloat = 0
            if !reset, offset > 0, let anchor, let index = entries.firstIndex(where: { $0.id == anchor }) {
                y = topInset + CGFloat(index) * stride + relative
            }
            clip.scroll(to: NSPoint(x: 0, y: min(max(y, 0), max(0, bounds.height - clip.bounds.height))))
        }
        updateVisibleRows()
    }

    func resize(to size: NSSize) {
        viewport = size
        let height = max(size.height, topInset + CGFloat(entries.count) * stride + 22)
        if frame.size != NSSize(width: size.width, height: height) {
            setFrameSize(NSSize(width: size.width, height: height))
        }
        updateVisibleRows()
    }

    func updateVisibleRows() {
        guard !updating, viewport.width > 0, let host = layer else { return }
        updating = true
        defer { updating = false }
        let visible = enclosingScrollView?.contentView.bounds ?? bounds
        let start = min(entries.count, max(0, Int(floor((visible.minY - topInset - 80) / stride))))
        let end = min(entries.count, max(start, Int(ceil((visible.maxY - topInset + 190) / stride))))
        let keep = Set(entries[start..<end].map(\.id))
        var accessibilityChanged = false
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for id in Array(rows.keys) where !keep.contains(id) { rows.removeValue(forKey: id)?.removeFromSuperlayer() }
        for index in start..<end {
            let entry = entries[index]
            let row: FanRowLayer
            if let existing = rows[entry.id], existing.entry == entry { row = existing }
            else {
                rows.removeValue(forKey: entry.id)?.removeFromSuperlayer()
                row = FanRowLayer(entry: entry, parent: self)
                rows[entry.id] = row
                accessibilityChanged = true
                host.addSublayer(row)
            }
            let center = topInset + CGFloat(index) * stride + 32
            let amount = min(1, CGFloat(max(0, entries.count - 1)) / 8)
            let progress = 1 - (1 - min(max((center - visible.minY) / max(1, visible.height), 0), 1)) * amount
            let angle = reduceMotion ? 0 : 16 * pow(1 - progress, 1.15) * .pi / 180
            let edge = viewport.width - 62 + 46 * (1 - pow(progress, 1.7))
            row.arrange(right: edge, center: center, angle: angle, maxWidth: max(120, viewport.width - 108),
                        scale: window?.backingScaleFactor ?? 2, highlighted: hoveredID == entry.id, selected: selectedID == entry.id)
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
        let bottom = topInset + CGFloat(index) * stride + 70
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

    private func row(at event: NSEvent) -> FanRowLayer? {
        let point = convert(event.locationInWindow, from: nil)
        return rows.values.first { $0.contains(pointInCanvas: point) }
    }
    override func mouseMoved(with event: NSEvent) {
        let id = row(at: event)?.entry.id
        if id != hoveredID { hoveredID = id; updateVisibleRows() }
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
    weak var row: FanRowLayer?
    override func accessibilityFrame() -> NSRect {
        guard let canvas, let row, let window = canvas.window else { return .zero }
        return window.convertToScreen(canvas.convert(row.frame, to: nil))
    }
    override func accessibilityPerformPress() -> Bool {
        guard let row, let canvas else { return false }
        canvas.open?(row.entry)
        return true
    }
}

@MainActor
private final class FanRowLayer: CALayer {
    let entry: FileEntry
    let accessibility = FanFileAccessibility()
    private let capsule = CALayer()
    private let label = CATextLayer()
    private let icon = CALayer()
    private var thumbnailTask: Task<Void, Never>?
    private var angle: CGFloat = 0
    private var labelWidth: CGFloat = 0
    private var naturalWidth: CGFloat = 0

    init(entry: FileEntry, parent: FanCanvas) {
        self.entry = entry
        super.init()
        anchorPoint = CGPoint(x: 1, y: 0.5)
        capsule.cornerRadius = 13
        capsule.borderWidth = 0.5
        capsule.shadowColor = NSColor.black.cgColor
        capsule.shadowOpacity = 0.18
        capsule.shadowRadius = 2
        capsule.shadowOffset = CGSize(width: 0, height: 1)
        label.string = entry.name
        label.font = NSFont.systemFont(ofSize: 13)
        label.fontSize = 13
        label.foregroundColor = NSColor.white.withAlphaComponent(0.94).cgColor
        label.truncationMode = .middle
        label.alignmentMode = .center
        naturalWidth = ceil((entry.name as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width) + 24
        capsule.addSublayer(label)
        addSublayer(capsule)
        icon.contentsGravity = .resizeAspect
        icon.minificationFilter = .trilinear
        icon.magnificationFilter = .linear
        icon.shadowColor = NSColor.black.cgColor
        icon.shadowOpacity = 0.25
        icon.shadowRadius = 2
        icon.shadowOffset = CGSize(width: 0, height: 2)
        addSublayer(icon)
        accessibility.canvas = parent
        accessibility.row = self
        accessibility.setAccessibilityParent(parent)
        accessibility.setAccessibilityRole(.button)
        accessibility.setAccessibilityEnabled(true)
        accessibility.setAccessibilityLabel(entry.name)
        accessibility.setAccessibilityValue(entry.kind.title)
        accessibility.setAccessibilityHelp("Open file. Use Space for Quick Look or the context menu to reveal in Finder.")
        let store = ThumbnailStore.shared
        setImage(store.cached(for: entry) ?? store.icon(for: entry))
        thumbnailTask = Task { @MainActor [weak self] in
            let image = await store.image(for: entry)
            guard !Task.isCancelled else { return }
            self?.setImage(image)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override init(layer: Any) {
        entry = (layer as! FanRowLayer).entry
        super.init(layer: layer)
    }
    deinit { thumbnailTask?.cancel() }

    private func setImage(_ image: NSImage) {
        var rect = NSRect(x: 0, y: 0, width: 256, height: 256)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        icon.contents = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        CATransaction.commit()
    }

    func arrange(right: CGFloat, center: CGFloat, angle: CGFloat, maxWidth: CGFloat, scale: CGFloat, highlighted: Bool, selected: Bool) {
        labelWidth = min(naturalWidth, maxWidth - 75)
        bounds = CGRect(x: 0, y: 0, width: labelWidth + 75, height: 64)
        position = CGPoint(x: right, y: center)
        self.angle = angle
        setAffineTransform(CGAffineTransform(rotationAngle: angle))
        capsule.frame = CGRect(x: 0, y: 19, width: labelWidth, height: 26)
        capsule.backgroundColor = highlighted ? NSColor.controlAccentColor.withAlphaComponent(0.95).cgColor : NSColor(white: selected ? 0.32 : 0.25, alpha: 0.92).cgColor
        capsule.borderColor = NSColor.white.withAlphaComponent(highlighted || selected ? 0.25 : 0.16).cgColor
        label.frame = CGRect(x: 12, y: 4, width: labelWidth - 24, height: 18)
        label.contentsScale = scale
        icon.frame = CGRect(x: labelWidth + 11, y: 0, width: 64, height: 64)
        icon.contentsScale = scale
        accessibility.setAccessibilitySelected(selected)
    }

    func contains(pointInCanvas point: CGPoint) -> Bool {
        let dx = point.x - position.x, dy = point.y - position.y
        let local = CGPoint(x: cos(angle) * dx + sin(angle) * dy + bounds.width,
                            y: -sin(angle) * dx + cos(angle) * dy + bounds.height / 2)
        return capsule.frame.contains(local) || icon.frame.contains(local)
    }
}

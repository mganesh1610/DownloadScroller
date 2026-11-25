import Combine
import CoreGraphics
import Foundation

@MainActor
final class FanPositionPreferences: ObservableObject {
    @Published private(set) var rightLauncherID: UUID?
    private struct SavedClick: Codable, Equatable {
        let edge: DockEdge
        let fraction: CGFloat
        let inset: CGFloat
    }

    private let defaults: UserDefaults
    private let rightKey = "rightDockLauncherID"
    private let clicksKey = "regularFanDockClicks"
    private var clicks: [String: SavedClick]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        rightLauncherID = defaults.string(forKey: rightKey).flatMap(UUID.init(uuidString:))
        clicks = defaults.data(forKey: clicksKey).flatMap {
            try? PropertyListDecoder().decode([String: SavedClick].self, from: $0)
        } ?? [:]
    }

    func fixOnRight(_ id: UUID) {
        guard rightLauncherID != id else { return }
        defaults.set(id.uuidString, forKey: rightKey)
        rightLauncherID = id
    }

    func rememberAppClick(_ anchor: ShelfAnchor, display: String, screen: CGRect) {
        guard case .dock(let point, let edge) = anchor, screen.contains(point) else { return }
        let click: SavedClick
        switch edge {
        case .bottom:
            click = SavedClick(edge: edge, fraction: (point.x - screen.minX) / screen.width, inset: point.y - screen.minY)
        case .left, .right:
            click = SavedClick(edge: edge, fraction: (point.y - screen.minY) / screen.height,
                               inset: edge == .left ? point.x - screen.minX : screen.maxX - point.x)
        }
        guard clicks[display] != click else { return }
        objectWillChange.send()
        clicks[display] = click
        if let data = try? PropertyListEncoder().encode(clicks) { defaults.set(data, forKey: clicksKey) }
    }

    func appDockAnchor(display: String, screen: CGRect) -> ShelfAnchor? {
        guard let click = clicks[display], (0...1).contains(click.fraction), click.inset >= 0 else { return nil }
        let point: CGPoint
        switch click.edge {
        case .bottom:
            point = CGPoint(x: screen.minX + screen.width * click.fraction, y: screen.minY + click.inset)
        case .left, .right:
            point = CGPoint(x: click.edge == .left ? screen.minX + click.inset : screen.maxX - click.inset,
                            y: screen.minY + screen.height * click.fraction)
        }
        return screen.contains(point) ? .dock(point: point, edge: click.edge) : nil
    }
}

enum FanIconSide { case left, right }
enum DockEdge: String, Codable { case bottom, left, right }

enum ShelfAnchor: Equatable {
    case dock(point: CGPoint, edge: DockEdge)
    case menuBar(CGRect)

    var point: CGPoint {
        switch self {
        case .dock(let point, _): return point
        case .menuBar(let rect): return CGPoint(x: rect.midX, y: rect.midY)
        }
    }
}

/// Uses the Dock click location, without inspecting the Dock or asking for
/// Accessibility permission. All coordinates are in AppKit's screen space.
struct FanPlacement {
    let frame: CGRect
    let iconSide: FanIconSide
    private(set) var shortenedForNeighbor = false

    struct Panel {
        /// Width required by the filenames, before adding spare browsing space.
        let size: CGSize
        let anchor: ShelfAnchor?
        let launcherID: UUID?
        let isFan: Bool
    }

    private static let margin: CGFloat = 12
    private static let gap: CGFloat = 8

    /// Lay out one display from the desired sizes of its open panels. Start from
    /// those sizes on every pass so closing a neighbor immediately gives its space back.
    static func layout(_ panels: [Panel], in visible: CGRect, rightID: UUID?) -> [FanPlacement] {
        let fixed = rightID.flatMap { id in panels.firstIndex { $0.isFan && $0.launcherID == id } }
        let main = panels.firstIndex { $0.isFan && $0.launcherID == nil }
        let others = panels.indices.filter { $0 != fixed && $0 != main }.sorted {
            (panels[$0].launcherID?.uuidString ?? "~") < (panels[$1].launcherID?.uuidString ?? "~")
        }
        let order = [fixed, main].compactMap { $0 } + others

        func arrange(_ widths: [CGFloat]) -> [FanPlacement] {
            var placements = panels.indices.map { i in
                resolve(size: CGSize(width: widths[i], height: panels[i].size.height), visible: visible,
                        anchor: i == fixed ? nil : panels[i].anchor, fan: panels[i].isFan)
            }
            var occupied: [CGRect] = []
            for i in order {
                // The fixed launcher and the regular Dock tile keep their icon columns.
                var canMove = i != fixed
                if i == main, case .dock = panels[i].anchor { canMove = false }
                if canMove { placements[i] = placements[i].avoiding(occupied, in: visible) }
                if panels[i].isFan { occupied.append(placements[i].frame) }
            }
            return placements
        }

        let full = arrange(panels.map { $0.isFan ? max(FanMetrics.defaultWidth, $0.size.width) : $0.size.width })
        let fans = order.filter { panels[$0].isFan }
        let pairs = fans.indices.flatMap { i in fans.dropFirst(i + 1).map { (fans[i], $0) } }
        let collisions = pairs.filter { overlap(full[$0.0].frame, full[$0.1].frame) > 0 }
        guard !collisions.isEmpty else { return full }

        let crowded = Set(collisions.flatMap { [$0.0, $0.1] })
        let preferred = full.map { $0.frame.width }
        let content = panels.indices.map { min(max(FanMetrics.minimumWidth, panels[$0].size.width), preferred[$0]) }
        var widths = preferred
        for i in crowded { widths[i] = min(preferred[i], FanMetrics.minimumWidth) }
        func totalOverlap() -> CGFloat {
            let trial = arrange(widths)
            return pairs.reduce(0) { $0 + overlap(trial[$1.0].frame, trial[$1.1].frame) }
        }
        // Very close Dock tiles can overlap even at the minimum usable width.
        let unavoidable = totalOverlap()
        func grow(_ indices: [Int], toward limits: [CGFloat]) {
            var low = Int(floor(indices.map { widths[$0] }.min()!))
            var high = Int(ceil(indices.map { limits[$0] }.max()!))
            func setLimit(_ limit: Int) {
                for i in indices { widths[i] = min(limits[i], CGFloat(limit)) }
            }
            setLimit(high)
            if totalOverlap() <= unavoidable { return }
            while low < high {
                let mid = low + (high - low + 1) / 2
                setLimit(mid)
                if totalOverlap() <= unavoidable { low = mid } else { high = mid - 1 }
            }
            setLimit(low)
        }
        let affected = order.filter(crowded.contains)
        // Give competing names an equal width first. A fan whose labels grow
        // away from its neighbor can then reclaim the rest of its preferred width.
        grow(affected, toward: content)
        for i in affected where widths[i] < content[i] { grow([i], toward: content) }
        // Restore spare browsing space only after fitting the filenames.
        for i in affected where widths[i] < preferred[i] { grow([i], toward: preferred) }
        var result = arrange(widths)
        for i in affected { result[i].shortenedForNeighbor = result[i].frame.width < content[i] }
        return result
    }

    private static func overlap(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let shared = first.insetBy(dx: -gap / 2, dy: -gap / 2)
            .intersection(second.insetBy(dx: -gap / 2, dy: -gap / 2))
        return shared.isNull ? 0 : shared.width * shared.height
    }

    /// Keep the clicked anchor when space allows. On a crowded display choose
    /// the closest position that covers the least of the already open fans.
    func avoiding(_ others: [CGRect], in visible: CGRect) -> FanPlacement {
        let bounds = visible.insetBy(dx: Self.margin, dy: Self.margin)
        let neighbors = others.filter { $0.intersects(visible) }
        guard neighbors.contains(where: { Self.overlap($0, frame) > 0 }) else { return self }
        let gap = Self.gap
        var xs = [frame.minX, bounds.minX, bounds.maxX - frame.width]
        var ys = [frame.minY, bounds.minY, bounds.maxY - frame.height]
        for rect in neighbors {
            xs += [rect.minX - gap - frame.width, rect.maxX + gap]
            ys += [rect.minY - gap - frame.height, rect.maxY + gap]
        }
        var best = frame
        var leastOverlap = CGFloat.infinity
        var shortest = CGFloat.infinity
        for x in xs {
            for y in ys {
                let origin = CGPoint(x: max(bounds.minX, min(x, bounds.maxX - frame.width)),
                                     y: max(bounds.minY, min(y, bounds.maxY - frame.height)))
                let candidate = CGRect(origin: origin, size: frame.size)
                let overlap = neighbors.reduce(CGFloat.zero) { $0 + Self.overlap(candidate, $1) }
                let distance = hypot(origin.x - frame.minX, origin.y - frame.minY)
                if overlap < leastOverlap || (overlap == leastOverlap && distance < shortest) {
                    best = candidate
                    leastOverlap = overlap
                    shortest = distance
                }
            }
        }
        return FanPlacement(frame: best, iconSide: iconSide)
    }

    static func dockAnchor(at point: CGPoint, screen: CGRect, visible: CGRect) -> ShelfAnchor? {
        guard screen.contains(point) else { return nil }
        // Auto-hidden Docks can leave visibleFrame unchanged while revealed.
        // Only consider an edge strip, and choose the closest edge at corners.
        let edges: [(edge: DockEdge, distance: CGFloat, inset: CGFloat)] = [
            (.bottom, point.y - screen.minY, visible.minY - screen.minY),
            (.left, point.x - screen.minX, visible.minX - screen.minX),
            (.right, screen.maxX - point.x, screen.maxX - visible.maxX)
        ]
        let known = edges.filter { $0.inset > 4 }
        let candidates = (known.isEmpty ? edges : known).filter { $0.distance <= max(96, $0.inset) + 8 }
        guard let closest = candidates.min(by: { $0.distance < $1.distance }) else { return nil }
        return .dock(point: point, edge: closest.edge)
    }

    static func resolve(size: CGSize, visible: CGRect, anchor: ShelfAnchor?, fan: Bool) -> FanPlacement {
        var size = CGSize(width: min(size.width, max(1, visible.width - 2 * margin)),
                          height: min(size.height, max(1, visible.height - 2 * margin)))
        var side = FanIconSide.right
        var x = visible.maxX - size.width - margin
        var y = visible.minY + margin
        switch anchor {
        case .dock(let point, let edge):
            side = edge == .left || (edge == .bottom && point.x < visible.midX) ? .left : .right
            switch edge {
            case .bottom:
                if fan {
                    let room = side == .left ? visible.maxX - margin - (point.x - FanMetrics.iconInset)
                        : point.x + FanMetrics.iconInset - (visible.minX + margin)
                    size.width = min(size.width, max(1, room))
                }
                let iconX = side == .left ? FanMetrics.iconInset : size.width - FanMetrics.iconInset
                x = point.x - (fan ? iconX : size.width / 2)
                // Keep clear of a revealed auto-hidden Dock as well.
                y = max(y, point.y + 32)
            case .left:
                x = max(visible.minX + margin, point.x + 32)
                if fan { size.width = min(size.width, max(1, visible.maxX - margin - x)) }
                y = point.y - 100
            case .right:
                let right = min(visible.maxX - margin, point.x - 32)
                if fan { size.width = min(size.width, max(1, right - visible.minX - margin)) }
                x = right - size.width
                y = point.y - 100
            }
        case .menuBar(let rect):
            x = rect.midX - size.width / 2
            y = rect.minY - size.height - 8
        case nil: break
        }
        x = min(max(x, visible.minX + margin), visible.maxX - size.width - margin)
        y = min(max(y, visible.minY + margin), visible.maxY - size.height - margin)
        return FanPlacement(frame: CGRect(origin: CGPoint(x: x, y: y), size: size), iconSide: side)
    }
}

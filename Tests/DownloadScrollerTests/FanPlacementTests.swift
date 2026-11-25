import Foundation
#if !STANDALONE_CHECKS
import XCTest
@testable import DownloadScroller
#endif

final class FanPlacementTests: XCTestCase {
    private let visible = CGRect(x: 0, y: 70, width: 1512, height: 880)
    private let size = CGSize(width: 560, height: 780)

    func testRightLauncherStaysPutInEitherOpeningOrderAndWhileContentsChange() {
        let fixed = UUID()
        let right = FanPlacement.Panel(size: size, anchor: nil, launcherID: fixed, isFan: true)
        for screen in [visible, CGRect(x: -1220, y: -40, width: 850, height: 760)] {
            let click = ShelfAnchor.dock(point: CGPoint(x: screen.maxX - 40, y: screen.minY), edge: .bottom)
            let other = FanPlacement.Panel(size: size, anchor: click, launcherID: UUID(), isFan: true)
            let alone = FanPlacement.layout([right], in: screen, rightID: fixed)[0]
            XCTAssertEqual(alone.frame.width, size.width)
            let both = FanPlacement.layout([right, other], in: screen, rightID: fixed)
            let reversed = FanPlacement.layout([other, right], in: screen, rightID: fixed)
            XCTAssertEqual(both[0].frame, reversed[1].frame)
            XCTAssertEqual(both[1].frame, reversed[0].frame)
            XCTAssertEqual(both[0].iconSide, .right)
            XCTAssertEqual(both[0].frame.maxX, screen.maxX - 12)
            XCTAssertEqual(both[0].frame.minY, alone.frame.minY)
            XCTAssertFalse(both[0].frame.intersects(both[1].frame))
            // Wide display fits two whole windows. The small display shares the available width.
            let width = min(size.width, floor((screen.width - 24 - 8) / 2))
            XCTAssertEqual(both[0].frame.width, width)
            XCTAssertEqual(both[1].frame.width, width)
            let shorter = FanPlacement.Panel(size: CGSize(width: size.width, height: 260), anchor: nil, launcherID: fixed, isFan: true)
            let refreshed = FanPlacement.layout([other, shorter], in: screen, rightID: fixed)[1]
            XCTAssertEqual(refreshed.frame.maxX, alone.frame.maxX)
            XCTAssertEqual(refreshed.frame.minY, alone.frame.minY)
            XCTAssertEqual(FanPlacement.layout([other], in: screen, rightID: fixed)[0].frame.width, size.width)
        }
    }

    func testRegularDockClickKeepsItsFileColumnAndTheRightLauncherAccessible() {
        let fixed = UUID()
        let right = FanPlacement.Panel(size: size, anchor: nil, launcherID: fixed, isFan: true)
        for origin: CGFloat in [1920, -1920] {
            let screen = CGRect(x: origin, y: 120, width: 1920, height: 1080)
            let x = screen.minX + 1496.95703125
            let click = ShelfAnchor.dock(point: CGPoint(x: x, y: screen.minY + 22), edge: .bottom)
            let regular = FanPlacement.Panel(size: size, anchor: click, launcherID: nil, isFan: true)
            let both = FanPlacement.layout([regular, right], in: screen, rightID: fixed)
            let reverse = FanPlacement.layout([right, regular], in: screen, rightID: fixed)
            XCTAssertEqual(both[0].frame, reverse[1].frame)
            XCTAssertEqual(both[1].frame, reverse[0].frame)
            XCTAssertEqual(both[0].frame.maxX - FanMetrics.iconInset, x)
            XCTAssertEqual(both[0].frame.width, 560)
            XCTAssertEqual(both[1].frame.width, 335)
            XCTAssertFalse(both[0].shortenedForNeighbor)
            XCTAssertEqual(both[1].shortenedForNeighbor, true)
            XCTAssertFalse(both[0].frame.intersects(both[1].frame))
            let solo = FanPlacement.layout([right], in: screen, rightID: fixed)[0]
            XCTAssertEqual(solo.frame.width, 560)
            XCTAssertFalse(solo.shortenedForNeighbor)
            XCTAssertEqual(solo.frame.maxX, both[1].frame.maxX)
            let distant = FanPlacement.Panel(size: size, anchor: .dock(point: CGPoint(x: origin + 300, y: 122), edge: .bottom),
                                            launcherID: nil, isFan: true)
            XCTAssertEqual(FanPlacement.layout([distant, right], in: screen, rightID: fixed).map { $0.frame.width }, [560, 560])
        }
    }

    func testRegularTileNearTheFixedLauncherOrASideDockKeepsItsOwnAnchor() {
        let fixed = UUID()
        let screen = CGRect(x: 0, y: 60, width: 1440, height: 840)
        let points: [(DockEdge, CGPoint)] = [(.bottom, CGPoint(x: 1300, y: 30)),
                                              (.left, CGPoint(x: 15, y: 430)),
                                              (.right, CGPoint(x: 1420, y: 430))]
        let right = FanPlacement.Panel(size: size, anchor: nil, launcherID: fixed, isFan: true)
        for (edge, point) in points {
            let anchor = ShelfAnchor.dock(point: point, edge: edge)
            let regular = FanPlacement.Panel(size: size, anchor: anchor, launcherID: nil, isFan: true)
            let both = FanPlacement.layout([right, regular], in: screen, rightID: fixed)
            let expected = FanPlacement.resolve(size: size, visible: screen, anchor: anchor, fan: true)
            XCTAssertEqual(both[1].frame, expected.frame)
            XCTAssertEqual(both[0].frame.maxX, screen.maxX - 12)
            XCTAssertFalse(both[0].frame.width < 280)
        }
    }

    func testOnlyVisibleCompetingFansConsumeLabelSpace() {
        let fixed = UUID()
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let wide = CGSize(width: 800, height: 290)
        let right = FanPlacement.Panel(size: wide, anchor: nil, launcherID: fixed, isFan: true)
        let top = ShelfAnchor.menuBar(CGRect(x: 900, y: 900, width: 30, height: 25))
        let regular = FanPlacement.Panel(size: wide, anchor: top, launcherID: nil, isFan: true)
        XCTAssertEqual(FanPlacement.layout([right, regular], in: screen, rightID: fixed).map { $0.frame.width }, [800, 800])
        let welcome = FanPlacement.Panel(size: CGSize(width: 490, height: 690), anchor: nil, launcherID: nil, isFan: false)
        XCTAssertEqual(FanPlacement.layout([right, welcome], in: screen, rightID: fixed)[0].frame.width, 800)
        let first = FanPlacement.Panel(size: size, anchor: nil, launcherID: UUID(), isFan: true)
        let second = FanPlacement.Panel(size: size, anchor: nil, launcherID: UUID(), isFan: true)
        let narrow = CGRect(x: 0, y: 0, width: 850, height: 750)
        let peers = FanPlacement.layout([first, second], in: narrow, rightID: fixed)
        XCTAssertEqual(peers.map { $0.frame.width }, [409, 409])
        XCTAssertFalse(peers[0].frame.intersects(peers[1].frame))
        XCTAssertEqual(FanPlacement.layout([second], in: narrow, rightID: fixed)[0].frame.width, 560)
    }

    @MainActor func testLongNamesUseTheirMeasuredWidthAndKeepDockAlignment() {
        let name = String(repeating: "Résumé 旅行 W — ", count: 10) + "final.xlsx"
        let field = FanMetrics.filenameLabel(name)
        let width = FanMetrics.widthToFit(["short.txt", name])
        XCTAssertEqual(width, ceil(field.fittingSize.width) + FanMetrics.labelPadding + FanMetrics.fileIconAndGap + FanMetrics.canvasGutter)
        XCTAssertFalse(width <= 560)
        let extraLong = String(repeating: "W", count: 245) + ".txt"
        let heights = FanMetrics.wrappedTextHeights(for: [extraLong, "short.txt"], panelWidth: 1200)
        XCTAssertFalse((heights[extraLong] ?? 0) <= 18)
        XCTAssertEqual(heights["short.txt"], nil)
        let screen = CGRect(x: 1920, y: 120, width: 1920, height: 1080)
        for offset: CGFloat in [920, 1000] {
            let x = screen.minX + offset
            let anchor = ShelfAnchor.dock(point: CGPoint(x: x, y: 138), edge: .bottom)
            let wide = FanPlacement.Panel(size: CGSize(width: 2400, height: 780), anchor: anchor, launcherID: nil, isFan: true)
            let placed = FanPlacement.layout([wide], in: screen, rightID: UUID())[0]
            let icon = placed.iconSide == .right ? placed.frame.maxX - FanMetrics.iconInset : placed.frame.minX + FanMetrics.iconInset
            XCTAssertEqual(icon, x)
            XCTAssertFalse(!screen.contains(placed.frame))
        }
    }

    func testShortNamesGiveUpSpareWidthBeforeLongNamesAreShortened() {
        let fixed = UUID()
        let screen = CGRect(x: 1920, y: 120, width: 1920, height: 1080)
        let right = FanPlacement.Panel(size: CGSize(width: 1530, height: 780), anchor: nil, launcherID: fixed, isFan: true)
        let other = FanPlacement.Panel(size: CGSize(width: 280, height: 780), anchor: nil, launcherID: UUID(), isFan: true)
        XCTAssertEqual(FanPlacement.layout([other], in: screen, rightID: fixed)[0].frame.width, 560)
        let both = FanPlacement.layout([other, right], in: screen, rightID: fixed)
        XCTAssertEqual(both[1].frame.width, 1530)
        XCTAssertEqual(both[0].frame.width, 358)
        XCTAssertFalse(both.contains(where: \.shortenedForNeighbor))
        XCTAssertFalse(both[0].frame.intersects(both[1].frame))
    }

    @MainActor func testAppClickPersistsPerDisplayAndMenuBarOpeningDoesNotReplaceIt() {
        let key = "DockClickTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: key)!
        defer { defaults.removePersistentDomain(forName: key) }
        let store = FanPositionPreferences(defaults: defaults)
        let display = CGRect(x: -1600, y: 80, width: 1600, height: 1000)
        let first = ShelfAnchor.dock(point: CGPoint(x: -320, y: 110), edge: .bottom)
        let other = ShelfAnchor.dock(point: CGPoint(x: 25, y: 250), edge: .left)
        let secondDisplay = CGRect(x: 0, y: 0, width: 1000, height: 800)
        store.rememberAppClick(first, display: "external", screen: display)
        store.rememberAppClick(other, display: "internal", screen: secondDisplay)
        store.rememberAppClick(.menuBar(display), display: "external", screen: display)
        let restored = FanPositionPreferences(defaults: defaults)
        XCTAssertEqual(restored.appDockAnchor(display: "external", screen: display), first)
        XCTAssertEqual(restored.appDockAnchor(display: "internal", screen: secondDisplay), other)
        XCTAssertEqual(restored.appDockAnchor(display: "unknown", screen: display), nil)
        let resized = CGRect(x: 120, y: -30, width: 1200, height: 800)
        XCTAssertEqual(restored.appDockAnchor(display: "external", screen: resized),
                       .dock(point: CGPoint(x: 1080, y: 0), edge: .bottom))
        let moved = ShelfAnchor.dock(point: CGPoint(x: -1100, y: 114), edge: .bottom)
        restored.rememberAppClick(moved, display: "external", screen: display)
        XCTAssertEqual(FanPositionPreferences(defaults: defaults).appDockAnchor(display: "external", screen: display), moved)
    }

    @MainActor func testFixedLauncherIsSavedByIdentityAndCanBeReassigned() {
        let key = "RightFanTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: key)!
        defer { defaults.removePersistentDomain(forName: key) }
        let first = UUID(), second = UUID()
        let setting = FanPositionPreferences(defaults: defaults)
        XCTAssertEqual(setting.rightLauncherID, nil)
        setting.fixOnRight(first)
        XCTAssertEqual(FanPositionPreferences(defaults: defaults).rightLauncherID, first)
        setting.fixOnRight(second)
        XCTAssertEqual(FanPositionPreferences(defaults: defaults).rightLauncherID, second)
    }

    func testBottomDockClickAlignsFileColumnOnEitherSide() {
        for (x, side) in [(CGFloat(120), FanIconSide.left), (CGFloat(1300), .right)] {
            let placement = FanPlacement.resolve(size: size, visible: visible,
                anchor: .dock(point: CGPoint(x: x, y: 35), edge: .bottom), fan: true)
            XCTAssertEqual(placement.iconSide, side)
            let iconX = side == .left ? placement.frame.minX + FanMetrics.iconInset : placement.frame.maxX - FanMetrics.iconInset
            XCTAssertEqual(iconX, x)
            XCTAssertFalse(!visible.contains(placement.frame))
        }
    }

    func testShortFanKeepsItsDockAnchorWhenFilesChange() {
        let anchor = ShelfAnchor.dock(point: CGPoint(x: 120, y: 35), edge: .bottom)
        let full = FanPlacement.resolve(size: size, visible: visible, anchor: anchor, fan: true)
        let short = FanPlacement.resolve(size: CGSize(width: 560, height: 300), visible: visible, anchor: anchor, fan: true)
        XCTAssertEqual(short.frame.origin, full.frame.origin)
        XCTAssertEqual(short.iconSide, full.iconSide)
    }

    func testDockNearScreenEdgeStaysOnScreen() {
        for x: CGFloat in [10, 1500] {
            let placement = FanPlacement.resolve(size: size, visible: visible,
                anchor: .dock(point: CGPoint(x: x, y: 35), edge: .bottom), fan: true)
            XCTAssertFalse(!visible.contains(placement.frame))
            let iconX = placement.iconSide == .left ? placement.frame.minX + FanMetrics.iconInset : placement.frame.maxX - FanMetrics.iconInset
            XCTAssertFalse(abs(iconX - x) > 80)
        }
    }

    func testTwoAdjacentDockLaunchersGetUsableSeparateFrames() {
        let first = FanPlacement.resolve(size: size, visible: visible,
            anchor: .dock(point: CGPoint(x: 1400, y: 35), edge: .bottom), fan: true)
        let second = FanPlacement.resolve(size: size, visible: visible,
            anchor: .dock(point: CGPoint(x: 1440, y: 35), edge: .bottom), fan: true)
        let adjusted = second.avoiding([first.frame], in: visible)
        XCTAssertFalse(first.frame.intersects(adjusted.frame))
        XCTAssertFalse(!visible.contains(adjusted.frame))
        // A fan on a different monitor should not move this one off its icon.
        XCTAssertEqual(second.avoiding([first.frame.offsetBy(dx: -2000, dy: 0)], in: visible).frame, second.frame)
    }

    func testSecondaryDisplayAndSideDocks() {
        let display = CGRect(x: -1600, y: -200, width: 1600, height: 1000)
        for (edge, x, side) in [(DockEdge.left, CGFloat(-1590), FanIconSide.left), (.right, CGFloat(-10), .right)] {
            let placement = FanPlacement.resolve(size: size, visible: display,
                anchor: .dock(point: CGPoint(x: x, y: 200), edge: edge), fan: true)
            XCTAssertEqual(placement.iconSide, side)
            XCTAssertFalse(!display.contains(placement.frame))
        }
    }

    func testMenuBarAndSmallDisplayAreClamped() {
        let display = CGRect(x: 0, y: 0, width: 500, height: 600)
        let placement = FanPlacement.resolve(size: size, visible: display,
            anchor: .menuBar(CGRect(x: 480, y: 600, width: 20, height: 24)), fan: true)
        XCTAssertFalse(!display.contains(placement.frame))
        XCTAssertEqual(placement.frame.size, CGSize(width: 476, height: 576))
    }

    func testRevealedAutoHiddenDockAndNonDockReopen() {
        let display = CGRect(x: -1600, y: 0, width: 1600, height: 1000)
        let point = CGPoint(x: -900, y: 35)
        guard case .dock(let anchor, .bottom) = FanPlacement.dockAnchor(at: point, screen: display, visible: display) else {
            preconditionFailure("Expected a Dock anchor even when auto-hide leaves visibleFrame unchanged")
        }
        XCTAssertEqual(anchor, point)
        let placement = FanPlacement.resolve(size: size, visible: display,
            anchor: .dock(point: point, edge: .bottom), fan: true)
        XCTAssertFalse(placement.frame.minY < point.y + 32)
        XCTAssertFalse(FanPlacement.dockAnchor(at: CGPoint(x: -800, y: 500), screen: display, visible: display) != nil)
        let bottomDock = CGRect(x: -1600, y: 60, width: 1600, height: 920)
        let corner = CGPoint(x: -1590, y: 30)
        XCTAssertEqual(FanPlacement.dockAnchor(at: corner, screen: display, visible: bottomDock), .dock(point: corner, edge: .bottom))
    }
}

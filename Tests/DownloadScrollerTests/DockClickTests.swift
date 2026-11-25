import AppKit
#if !STANDALONE_CHECKS
import XCTest
@testable import DownloadScroller
#endif

final class DockClickTests: XCTestCase {
    func testMouseDownInReservedDockWinsOverReceivingProcessOnEveryEdge() {
        let screen = CGRect(x: -1920, y: -120, width: 1920, height: 1080)
        let bottom = screen.divided(atDistance: 60, from: .minYEdge).remainder
        let left = screen.divided(atDistance: 60, from: .minXEdge).remainder
        let right = screen.divided(atDistance: 60, from: .maxXEdge).remainder
        for (visible, point, edge) in [(bottom, CGPoint(x: -420, y: -90), DockEdge.bottom),
                                       (left, CGPoint(x: -1900, y: 440), .left),
                                       (right, CGPoint(x: -20, y: 440), .right)] {
            XCTAssertEqual(DockClick.anchor(at: point, screen: screen, visible: visible,
                                            eventTargetIsDock: false, windowIsDock: false), .dock(point: point, edge: edge))
        }
        let outside = CGPoint(x: -420, y: bottom.minY + 12)
        XCTAssertEqual(DockClick.anchor(at: outside, screen: screen, visible: bottom,
                                        eventTargetIsDock: false, windowIsDock: false), nil)
    }

    func testMouseDownUsesRecordedLocationAndRecognizesRevealedDock() {
        let quartz = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                             mouseCursorPosition: CGPoint(x: 630, y: 970), mouseButton: .left)!
        let recorded = DockClick.point(of: NSEvent(cgEvent: quartz)!)
        XCTAssertEqual(recorded, quartz.unflippedLocation)
        let screen = CGRect(x: recorded.x - 630, y: recorded.y - 30, width: 1280, height: 1000)
        XCTAssertEqual(DockClick.anchor(at: recorded, screen: screen, visible: screen,
                                        eventTargetIsDock: false, windowIsDock: true), .dock(point: recorded, edge: .bottom))
        XCTAssertEqual(DockClick.anchor(at: recorded, screen: screen, visible: screen,
                                        eventTargetIsDock: false, windowIsDock: false), nil)
    }

    func testRepeatDockPressClosesOnceEvenIfOutsideDismissalArrivesFirst() {
        for outsideFirst in [true, false] {
            var main = FanDockToggle()
            var fixed = FanDockToggle()
            XCTAssertEqual(main.action(toggle: true, visible: false, press: 51), .open)
            XCTAssertEqual(fixed.action(toggle: true, visible: false, press: 52), .open)
            if outsideFirst { main.didDismissOutside(during: 53) }
            XCTAssertEqual(main.action(toggle: true, visible: !outsideFirst, press: 53), .close)
            XCTAssertEqual(main.action(toggle: true, visible: false, press: 53), .alreadyHandled)
            XCTAssertEqual(fixed.handledPress, 52)
            XCTAssertEqual(main.action(toggle: true, visible: false, press: 54), .open)
            XCTAssertEqual(fixed.action(toggle: true, visible: true, press: 55), .close)
        }
    }

    func testOutsideClickAndNonMouseReopensRemainIndependent() {
        var main = FanDockToggle()
        XCTAssertEqual(main.action(toggle: false, visible: false, press: 12), .open)
        XCTAssertEqual(main.action(toggle: true, visible: true, press: 12), .alreadyHandled)
        main.didDismissOutside(during: 13)
        XCTAssertEqual(main.action(toggle: true, visible: false, press: 14), .open)
        main.didDismissOutside(during: nil)
        XCTAssertEqual(main.action(toggle: true, visible: false, press: nil), .open)
        XCTAssertEqual(main.action(toggle: true, visible: true, press: nil), .close)
        XCTAssertEqual(main.action(toggle: true, visible: false, press: nil), .open)
    }
}

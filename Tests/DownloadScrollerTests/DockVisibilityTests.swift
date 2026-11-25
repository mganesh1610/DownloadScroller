import Foundation
#if !STANDALONE_CHECKS
import XCTest
@testable import DownloadScroller
#endif

final class DockVisibilityTests: XCTestCase {
    func testNewInstallShowsDockIconAndAppliesThePolicy() async {
        await MainActor.run {
            let suite = "DownloadScrollerTests.\(UUID())"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            var requests: [Bool] = []
            let visibility = DockVisibility(defaults: defaults) { requests.append($0); return true }
            XCTAssertEqual(visibility.isVisible, true)
            visibility.restore()
            XCTAssertEqual(requests, [true])
        }
    }

    func testSuccessfulVisibilityChoiceSurvivesRelaunch() async {
        await MainActor.run {
            let suite = "DownloadScrollerTests.\(UUID())"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let visibility = DockVisibility(defaults: defaults) { _ in true }
            XCTAssertEqual(visibility.setVisible(false), true)
            let relaunched = DockVisibility(defaults: defaults) { _ in true }
            relaunched.restore()
            XCTAssertFalse(relaunched.isVisible)
            XCTAssertEqual(relaunched.setVisible(true), true)
            XCTAssertEqual(DockVisibility(defaults: defaults) { _ in true }.isVisible, true)
        }
    }

    func testRejectedPolicyChangeDoesNotChangeTheSavedChoice() async {
        await MainActor.run {
            let suite = "DownloadScrollerTests.\(UUID())"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let visibility = DockVisibility(defaults: defaults) { $0 }
            visibility.restore()
            XCTAssertFalse(visibility.setVisible(false))
            XCTAssertEqual(visibility.isVisible, true)
            XCTAssertEqual(DockVisibility(defaults: defaults) { _ in true }.isVisible, true)
        }
    }

    func testFailedAccessoryRestoreFallsBackToAnAccessibleDockApp() async {
        await MainActor.run {
            let suite = "DownloadScrollerTests.\(UUID())"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let initial = DockVisibility(defaults: defaults) { _ in true }
            _ = initial.setVisible(false)
            var requests: [Bool] = []
            let relaunched = DockVisibility(defaults: defaults) { requests.append($0); return $0 }
            relaunched.restore()
            XCTAssertEqual(requests, [false, true])
            XCTAssertEqual(relaunched.isVisible, true)
        }
    }
}

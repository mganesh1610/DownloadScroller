#if !STANDALONE_CHECKS
import XCTest
@testable import DownloadScroller
#endif

final class SearchEscapeTests: XCTestCase {
    func testEscapeClearsQueryThenClosesSearchBeforeDismissing() async {
        await MainActor.run {
            let model = LibraryModel()
            var dismissals = 0
            model.onDismiss = { dismissals += 1 }
            model.isSearchPresented = true
            model.search = "report"

            model.handleEscape()
            XCTAssertEqual(model.search, "")
            XCTAssertEqual(model.isSearchPresented, true)
            XCTAssertEqual(dismissals, 0)

            model.handleEscape()
            XCTAssertFalse(model.isSearchPresented)
            XCTAssertEqual(dismissals, 0)

            model.handleEscape()
            XCTAssertEqual(dismissals, 1)
        }
    }

    func testEscapeStillClearsQueryWhenSearchToggleIsOff() async {
        await MainActor.run {
            let model = LibraryModel()
            var dismissals = 0
            model.onDismiss = { dismissals += 1 }
            // A nonempty query keeps the field visible even if its toggle is off.
            model.search = "no matching file"
            model.isSearchPresented = false

            model.handleEscape()
            XCTAssertEqual(model.search, "")
            XCTAssertFalse(model.isSearchPresented)
            XCTAssertEqual(dismissals, 0)

            model.handleEscape()
            XCTAssertEqual(dismissals, 1)
        }
    }
}

#if STANDALONE_CHECKS
@main
enum CLTAppTestRunner {
    static func main() async throws {
        let tests = SearchEscapeTests()
        await tests.testEscapeClearsQueryThenClosesSearchBeforeDismissing()
        await tests.testEscapeStillClearsQueryWhenSearchToggleIsOff()
        let placement = FanPlacementTests()
        placement.testRightLauncherStaysPutInEitherOpeningOrderAndWhileContentsChange()
        placement.testRegularDockClickKeepsItsFileColumnAndTheRightLauncherAccessible()
        placement.testRegularTileNearTheFixedLauncherOrASideDockKeepsItsOwnAnchor()
        placement.testOnlyVisibleCompetingFansConsumeLabelSpace()
        placement.testShortNamesGiveUpSpareWidthBeforeLongNamesAreShortened()
        await MainActor.run { placement.testLongNamesUseTheirMeasuredWidthAndKeepDockAlignment() }
        await MainActor.run { placement.testAppClickPersistsPerDisplayAndMenuBarOpeningDoesNotReplaceIt() }
        await MainActor.run { placement.testFixedLauncherIsSavedByIdentityAndCanBeReassigned() }
        placement.testBottomDockClickAlignsFileColumnOnEitherSide()
        placement.testShortFanKeepsItsDockAnchorWhenFilesChange()
        placement.testDockNearScreenEdgeStaysOnScreen()
        placement.testTwoAdjacentDockLaunchersGetUsableSeparateFrames()
        placement.testSecondaryDisplayAndSideDocks()
        placement.testMenuBarAndSmallDisplayAreClamped()
        placement.testRevealedAutoHiddenDockAndNonDockReopen()
        let dock = DockClickTests()
        dock.testMouseDownInReservedDockWinsOverReceivingProcessOnEveryEdge()
        dock.testMouseDownUsesRecordedLocationAndRecognizesRevealedDock()
        dock.testRepeatDockPressClosesOnceEvenIfOutsideDismissalArrivesFirst()
        dock.testOutsideClickAndNonMouseReopensRemainIndependent()
        let visibility = DockVisibilityTests()
        await visibility.testNewInstallShowsDockIconAndAppliesThePolicy()
        await visibility.testSuccessfulVisibilityChoiceSurvivesRelaunch()
        await visibility.testRejectedPolicyChangeDoesNotChangeTheSavedChoice()
        await visibility.testFailedAccessoryRestoreFallsBackToAnAccessibleDockApp()
        try await MainActor.run { try FolderContentsTests().testReconnectingAtTheSamePathAfterReplacementNeedsANewWatcher() }
        await MainActor.run { FolderContentsTests().testKeepWindowOpenIsRememberedSeparatelyForMainAndEachLauncher() }
        try await MainActor.run {
            let drag = FanFileDragTests()
            try drag.testFastDraggingExportsThePressedFileFromEitherFolder()
            drag.testEscapeDuringDragPreservesTheSearchAndWindow()
        }
        print("PASS: 29 app scenarios (file drag, Escape, independent windows, repeated Dock clicks, placement, folder identity and Dock visibility)")
    }
}
#endif

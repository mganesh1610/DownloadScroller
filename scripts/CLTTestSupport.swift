// Runs the same core test methods on Macs with Command Line Tools but no XCTest.
// Full Xcode/CI uses XCTest; this small adapter deliberately fails the process on failure.
import Foundation

class XCTestCase {}
func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: StaticString = #file, line: UInt = #line) {
    precondition(lhs == rhs, "Expected \(lhs) to equal \(rhs)", file: file, line: line)
}
func XCTAssertFalse(_ expression: Bool, file: StaticString = #file, line: UInt = #line) {
    precondition(!expression, "Expected false", file: file, line: line)
}
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) {
    do { _ = try expression() }
    catch { return }
    preconditionFailure("Expected an error", file: file, line: line)
}

@main
enum CLTTestRunner {
    static func main() throws {
        let tests = FileLibraryTests()
        tests.testSearchCombinesWordsAndKindIgnoringCaseAndAccents()
        tests.testEachSortAndStableNaturalNameTies()
        tests.testKindsDoNotTreatApplicationPackagesAsFolders()
        try tests.testFolderScanIncludesEveryVisibleItemWithoutRecursing()
        tests.testMissingFolderPropagatesAnError()
        tests.testDockUsesNewestCompletedFileIndependentOfDisplayOrder()
        tests.testFanUnfoldsFromNewestAtBottomTowardOlderFiles()
        tests.testFilteredFanKeepsRecentResultAtBottom()
        tests.testWheelMotionIsContinuousAndIndependentOfRefreshRate()
        tests.testWheelReversalAndBoundsDoNotLeaveQueuedDrift()
        print("PASS: 10 core scenarios (file queries, scan, bottom-first fan order, Dock file selection, wheel motion and bounds)")
    }
}

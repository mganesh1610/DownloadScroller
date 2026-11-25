// Shared assertions for core and app-state checks with Command Line Tools but no XCTest.
// Full Xcode/CI uses XCTest; this small adapter deliberately fails the process on failure.
import Foundation

class XCTestCase {}
func XCTFail(_ message: String, file: StaticString = #file, line: UInt = #line) {
    preconditionFailure(message, file: file, line: line)
}
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

#if !APP_CHECKS
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
        let launchers = LauncherStoreTests()
        try launchers.testCreateReloadAndCopyResolveToTheSamePrivateProfile()
        try launchers.testDuplicatesHaveIndependentFoldersAndEnabledStates()
        try launchers.testNameCollisionsNeverOverwriteExistingLaunchers()
        try launchers.testArtworkOnlyTargetsTheMatchingManagedDocument()
        try launchers.testNamesCannotEscapeTheManagedFolderOrExceedFilenameLimit()
        try launchers.testMalformedUnknownAndFutureDocumentsAreRejected()
        try launchers.testWrongExtensionDirectoriesAndSymlinksAreRejected()
        try launchers.testCorruptRegistryIsReportedAndNeverReplaced()
        try launchers.testEmptyBookmarksAreRejectedWithoutChangingProfiles()
        try launchers.testDocumentWriteFailurePreservesExistingRegistry()
        try launchers.testRegistryWriteFailureRollsBackOnlyTheNewDocument()
        let copy = FanFileCopyTests()
        try copy.testCopiesBothDirectionsToRootAndFolderWithoutOverwriting()
        try copy.testFolderTreesCanBeCopiedButNotIntoThemselvesOrOutsideViaASymlink()
        try copy.testConcurrentCopiesWithTheSameNamePreserveEveryPayload()
        print("PASS: 24 core scenarios (file library, fan motion, launchers and file copies)")
    }
}
#endif

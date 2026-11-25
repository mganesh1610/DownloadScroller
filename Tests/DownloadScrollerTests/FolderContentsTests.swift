import Foundation
#if !STANDALONE_CHECKS
import XCTest
@testable import DownloadScroller
#endif

final class FolderContentsTests: XCTestCase {
    @MainActor
    func testKeepWindowOpenIsRememberedSeparatelyForMainAndEachLauncher() {
        let suite = "FanWindowsTest." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let id = UUID()
        let main = LibraryModel(defaults: defaults)
        let first = LibraryModel(launcherID: id, defaults: defaults)
        XCTAssertFalse(main.pinned)
        XCTAssertFalse(first.pinned)
        first.pinned = true
        XCTAssertFalse(LibraryModel(defaults: defaults).pinned)
        XCTAssertEqual(LibraryModel(launcherID: id, defaults: defaults).pinned, true)
        XCTAssertFalse(LibraryModel(launcherID: UUID(), defaults: defaults).pinned)
        main.pinned = true
        first.pinned = false
        XCTAssertEqual(LibraryModel(defaults: defaults).pinned, true)
        XCTAssertFalse(LibraryModel(launcherID: id, defaults: defaults).pinned)
    }

    @MainActor
    func testReconnectingAtTheSamePathAfterReplacementNeedsANewWatcher() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = root.appendingPathComponent("Downloads")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let source = FolderContents(access: FolderAccess(url: folder, scoped: false))
        XCTAssertEqual(source.represents(folder), true)
        try fm.moveItem(at: folder, to: root.appendingPathComponent("Previous Downloads"))
        try fm.createDirectory(at: folder, withIntermediateDirectories: false)
        XCTAssertFalse(source.represents(folder))
    }
}

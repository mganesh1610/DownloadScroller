#if !STANDALONE_CHECKS
import XCTest
#else
import Foundation
#endif
@testable import DownloadScrollerCore

final class FileLibraryTests: XCTestCase {
    private func entry(_ name: String, kind: FileKind = .documents, size: Int64 = 1, time: TimeInterval = 100) -> FileEntry {
        FileEntry(url: URL(fileURLWithPath: "/fixture/\(name)"), name: name, kind: kind, size: size,
                  addedAt: Date(timeIntervalSince1970: time), modifiedAt: Date(timeIntervalSince1970: time))
    }

    func testSearchCombinesWordsAndKindIgnoringCaseAndAccents() {
        let files = [entry("Résumé draft.pdf"), entry("Resume final.pdf"), entry("Résumé draft.png", kind: .images)]
        XCTAssertEqual(FileQuery.apply(files, search: "  RESUME draft  ", kind: .documents).map(\.name), ["Résumé draft.pdf"])
        XCTAssertEqual(FileQuery.apply(files, search: "missing").count, 0)
    }

    func testEachSortAndStableNaturalNameTies() {
        let files = [entry("File 10.pdf", size: 40, time: 100), entry("File 2.pdf", size: 90, time: 100),
                     entry("Archive.zip", kind: .archives, size: 2, time: 200)]
        XCTAssertEqual(FileQuery.apply(files).map(\.name), ["Archive.zip", "File 2.pdf", "File 10.pdf"])
        XCTAssertEqual(FileQuery.apply(files, sort: .oldest).last?.name, "Archive.zip")
        XCTAssertEqual(FileQuery.apply(files, sort: .size).first?.name, "File 2.pdf")
        XCTAssertEqual(FileQuery.apply(files, sort: .kind).first?.kind, .archives)
        XCTAssertEqual(FileQuery.apply(files, sort: .name).last?.name, "File 10.pdf")
    }

    func testKindsDoNotTreatApplicationPackagesAsFolders() {
        XCTAssertEqual(FileKind.classify(extension: "app", isDirectory: true, isPackage: true), .other)
        XCTAssertEqual(FileKind.classify(extension: "", isDirectory: true), .folders)
        XCTAssertEqual(FileKind.classify(extension: "PDF", isDirectory: false), .documents)
        XCTAssertEqual(FileKind.classify(extension: "PNG", isDirectory: false), .images)
        XCTAssertEqual(FileKind.classify(extension: "mp4", isDirectory: false), .videos)
        XCTAssertEqual(FileKind.classify(extension: "m4a", isDirectory: false), .audio)
        XCTAssertEqual(FileKind.classify(extension: "tar", isDirectory: false), .archives)
    }

    func testFolderScanIncludesEveryVisibleItemWithoutRecursing() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for index in 0..<240 {
            try Data("sample".utf8).write(to: root.appendingPathComponent("File \(index).txt"))
        }
        try Data().write(to: root.appendingPathComponent(".hidden"))
        let child = root.appendingPathComponent("Subfolder")
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try Data().write(to: child.appendingPathComponent("Nested.txt"))
        let files = try FolderScanner.scan(root)
        XCTAssertEqual(files.count, 241)
        XCTAssertFalse(files.contains { $0.name == ".hidden" || $0.name == "Nested.txt" })
        XCTAssertEqual(files.first { $0.name == "Subfolder" }?.kind, .folders)
    }

    func testMissingFolderPropagatesAnError() {
        XCTAssertThrowsError(try FolderScanner.scan(URL(fileURLWithPath: "/nonexistent-\(UUID())")))
    }

    func testDockUsesNewestCompletedFileIndependentOfDisplayOrder() {
        let files = [entry("Newest folder", kind: .folders, time: 900), entry("Incoming.CRDOWNLOAD", time: 800),
                     entry("Draft.pdf.part", time: 700), entry("Newest.pdf", time: 600), entry("Older.png", kind: .images, time: 500)]
        XCTAssertEqual(DockFile.newest(in: files)?.name, "Newest.pdf")
        XCTAssertEqual(DockFile.newest(in: files.reversed())?.name, "Newest.pdf")
        XCTAssertEqual(DockFile.newest(in: Array(files.prefix(3))), nil)
        XCTAssertEqual(DockFile.newest(in: []), nil)
    }

    func testFanUnfoldsFromNewestAtBottomTowardOlderFiles() {
        let files = [entry("Old.pdf", time: 10), entry("New.pdf", time: 30), entry("Middle.pdf", time: 20)]
        XCTAssertEqual(FileQuery.fanOrder(files).map(\.name), ["Old.pdf", "Middle.pdf", "New.pdf"])
        XCTAssertEqual(FileQuery.fanOrder(files, sort: .oldest).last?.name, "Old.pdf")
        XCTAssertEqual(FileQuery.fanOrder(files, sort: .name).last?.name, "Middle.pdf")
        XCTAssertEqual(FileQuery.fanOrder(files + [entry("Just arrived.pdf", time: 40)]).last?.name, "Just arrived.pdf")
    }

    func testFilteredFanKeepsRecentResultAtBottom() {
        let files = [entry("Notes old.pdf", time: 10), entry("Notes new.pdf", time: 30),
                     entry("Notes.png", kind: .images, time: 40), entry("Other.pdf", time: 50)]
        XCTAssertEqual(FileQuery.fanOrder(files, search: "notes", kind: .documents).map(\.name), ["Notes old.pdf", "Notes new.pdf"])
        XCTAssertEqual(FileQuery.fanOrder(files, search: "new").map(\.name), ["Notes new.pdf"])
        XCTAssertEqual(FileQuery.fanOrder(files, search: "missing"), [])
    }

    func testWheelMotionIsContinuousAndIndependentOfRefreshRate() {
        var sixty = WheelMotion(), oneTwenty = WheelMotion()
        sixty.push(96, maximum: 1000)
        oneTwenty.push(96, maximum: 1000)
        var previous = 0.0
        for _ in 0..<12 {
            let next = sixty.advance(seconds: 1.0 / 60, maximum: 1000)
            XCTAssertFalse(next <= previous || next >= 96)
            // A wheel notch must be spread over frames, not applied in one jump.
            XCTAssertFalse(next - previous > 26)
            previous = next
        }
        for _ in 0..<24 { oneTwenty.advance(seconds: 1.0 / 120, maximum: 1000) }
        XCTAssertFalse(abs(sixty.position - oneTwenty.position) > 0.0001)
        for _ in 0..<60 { sixty.advance(seconds: 1.0 / 60, maximum: 1000) }
        XCTAssertEqual(sixty.position, 96)
        XCTAssertFalse(sixty.isMoving)
    }

    func testWheelReversalAndBoundsDoNotLeaveQueuedDrift() {
        var wheel = WheelMotion()
        wheel.reset(to: 200)
        for _ in 0..<20 { wheel.push(48, maximum: 1000) }
        XCTAssertEqual(wheel.target, 480)
        wheel.advance(seconds: 1.0 / 60, maximum: 1000)
        let beforeReversal = wheel.position
        wheel.push(-48, maximum: 1000)
        XCTAssertFalse(wheel.advance(seconds: 1.0 / 60, maximum: 1000) >= beforeReversal)
        wheel.reset(to: 995)
        wheel.push(48, maximum: 1000)
        XCTAssertEqual(wheel.target, 1000)
        for _ in 0..<60 { wheel.advance(seconds: 1.0 / 60, maximum: 1000) }
        XCTAssertEqual(wheel.position, 1000)
        wheel.advance(seconds: 1, maximum: 80)
        XCTAssertEqual(wheel.position, 80)
        wheel.reset(to: 0)
        wheel.push(-48, maximum: 80)
        XCTAssertFalse(wheel.isMoving)
    }
}

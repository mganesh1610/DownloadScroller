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
}

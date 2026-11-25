import Foundation
#if !STANDALONE_CHECKS
import XCTest
#endif
@testable import DownloadScrollerCore

final class FanFileCopyTests: XCTestCase {
    private func withFolders(_ body: (URL, URL, URL) throws -> Void) throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let source = root.appendingPathComponent("Left")
        let target = root.appendingPathComponent("Right")
        let child = target.appendingPathComponent("Invoices")
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        try fm.createDirectory(at: child, withIntermediateDirectories: true)
        try body(source, target, child)
    }

    func testCopiesBothDirectionsToRootAndFolderWithoutOverwriting() throws {
        try withFolders { left, right, child in
            let file = left.appendingPathComponent("Résumé #1.txt")
            let old = right.appendingPathComponent(file.lastPathComponent)
            let bytes = Data([1, 7, 12])
            try bytes.write(to: file)
            try Data([9]).write(to: old)
            let rootCopy = try FanFileCopy.copy(file, into: right, child: nil)
            XCTAssertEqual(rootCopy.lastPathComponent, "Résumé #1 copy.txt")
            XCTAssertEqual(try Data(contentsOf: old), Data([9]))
            XCTAssertEqual(try Data(contentsOf: rootCopy), bytes)
            let nestedCopy = try FanFileCopy.copy(file, into: right, child: child.lastPathComponent)
            XCTAssertEqual(nestedCopy.standardizedFileURL, child.appendingPathComponent(file.lastPathComponent).standardizedFileURL)
            let returned = try FanFileCopy.copy(nestedCopy, into: left, child: nil)
            XCTAssertEqual(try Data(contentsOf: returned), bytes)
            XCTAssertEqual(try Data(contentsOf: file), bytes)
        }
    }

    func testFolderTreesCanBeCopiedButNotIntoThemselvesOrOutsideViaASymlink() throws {
        try withFolders { left, right, child in
            let file = left.appendingPathComponent("entry.txt")
            try Data([2]).write(to: file)
            let tree = try FanFileCopy.copy(left, into: right, child: child.lastPathComponent)
            XCTAssertEqual(try Data(contentsOf: tree.appendingPathComponent("entry.txt")), Data([2]))
            let link = right.appendingPathComponent("Link")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: left)
            XCTAssertThrowsError(try FanFileCopy.copy(file, into: right, child: "Link"))
            XCTAssertThrowsError(try FanFileCopy.copy(file, into: right, child: "../Left"))
            XCTAssertThrowsError(try FanFileCopy.copy(right, into: right, child: "Invoices"))
            XCTAssertThrowsError(try FanFileCopy.copy(right, into: right, child: nil))
            XCTAssertThrowsError(try FanFileCopy.copy(file, into: right, child: "Missing"))
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: left.path), ["entry.txt"])
        }
    }

    func testConcurrentCopiesWithTheSameNamePreserveEveryPayload() throws {
        try withFolders { left, right, _ in
            let fm = FileManager.default
            let urls = try (0..<4).map { index in
                let dir = left.appendingPathComponent(String(index))
                try fm.createDirectory(at: dir, withIntermediateDirectories: false)
                let url = dir.appendingPathComponent("clip.txt")
                try Data([UInt8(index)]).write(to: url)
                return url
            }
            DispatchQueue.concurrentPerform(iterations: urls.count) { i in
                do { _ = try FanFileCopy.copy(urls[i], into: right, child: nil) }
                catch { XCTFail(error.localizedDescription) }
            }
            let results = try fm.contentsOfDirectory(at: right, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "txt" }
            XCTAssertEqual(Set(try results.map { try Data(contentsOf: $0) }), Set((0..<4).map { Data([UInt8($0)]) }))
            XCTAssertFalse(try fm.contentsOfDirectory(atPath: right.path).contains { $0.hasPrefix(".downloadscroller-") })
        }
    }
}

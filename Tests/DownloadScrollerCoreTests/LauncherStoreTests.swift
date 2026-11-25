import Foundation
#if !STANDALONE_CHECKS
import XCTest
#endif
@testable import DownloadScrollerCore

final class LauncherStoreTests: XCTestCase {
    private let downloads = LauncherFolder(name: "Downloads", bookmark: Data("private-folder-bookmark".utf8))

    private func withStore(_ run: (LauncherStore, URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LauncherChecks-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try run(LauncherStore(directory: root), root)
    }

    func testCreateReloadAndCopyResolveToTheSamePrivateProfile() throws {
        try withStore { store, root in
            let profile = try store.create(name: "Downloads", folder: downloads)
            let url = try store.documentURL(for: profile.id)
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
            XCTAssertEqual(Set(json.keys), Set(["version", "profileID"]))
            XCTAssertEqual(json["version"] as? Int, 1)
            XCTAssertEqual(json["profileID"] as? String, profile.id.uuidString)
            let copy = root.appendingPathComponent("Copy.downloadscroller")
            try FileManager.default.copyItem(at: url, to: copy)
            let reloaded = LauncherStore(directory: root)
            XCTAssertEqual(try reloaded.resolve(copy), profile)
            XCTAssertEqual(try reloaded.list(), [profile])
        }
    }

    func testDuplicatesHaveIndependentFoldersAndEnabledStates() throws {
        try withStore { store, _ in
            let original = try store.create(name: "Downloads", folder: downloads)
            let duplicate = try store.duplicate(original.id)
            XCTAssertFalse(original.id == duplicate.id)
            XCTAssertFalse(original.filename == duplicate.filename)
            let projects = LauncherFolder(name: "Projects", bookmark: Data("second-bookmark".utf8))
            try store.update(duplicate.id, folder: projects, isEnabled: false)
            XCTAssertEqual(try store.resolve(store.documentURL(for: original.id)).folder, downloads)
            do {
                _ = try store.resolve(store.documentURL(for: duplicate.id))
                XCTFail("A disabled launcher must not activate its folder")
            } catch { XCTAssertEqual(error as? LauncherError, .disabled(duplicate.name)) }
            try store.update(duplicate.id, isEnabled: true)
            XCTAssertEqual(try store.resolve(store.documentURL(for: duplicate.id)).folder, projects)
        }
    }

    func testNameCollisionsNeverOverwriteExistingLaunchers() throws {
        try withStore { store, _ in
            let first = try store.create(name: "Downloads", folder: downloads)
            let before = try Data(contentsOf: store.documentURL(for: first.id))
            let second = try store.create(name: "Downloads", folder: downloads)
            XCTAssertEqual(second.name, "Downloads 2")
            XCTAssertEqual(try Data(contentsOf: store.documentURL(for: first.id)), before)
            XCTAssertEqual(try store.resolve(store.documentURL(for: first.id)), first)
        }
    }

    func testArtworkOnlyTargetsTheMatchingManagedDocument() throws {
        try withStore { store, root in
            let profile = try store.create(name: "First", folder: downloads)
            let other = try store.duplicate(profile.id)
            let url = try store.iconDestination(for: profile)
            let original = try Data(contentsOf: url)
            let second = try store.documentURL(for: other.id)
            try Data(contentsOf: second).write(to: url)
            XCTAssertThrowsError(try store.iconDestination(for: profile))
            try original.write(to: url)
            let link = root.appendingPathComponent("Linked outside the launchers folder")
            try FileManager.default.linkItem(at: url, to: link)
            XCTAssertThrowsError(try store.iconDestination(for: profile))
            try FileManager.default.removeItem(at: url)
            try FileManager.default.createSymbolicLink(at: url, withDestinationURL: link)
            XCTAssertThrowsError(try store.iconDestination(for: profile))
            XCTAssertEqual(try Data(contentsOf: link), original)
        }
    }

    func testNamesCannotEscapeTheManagedFolderOrExceedFilenameLimit() throws {
        try withStore { store, _ in
            let traversal = try store.create(name: "../../Outside:/\nFolder", folder: downloads)
            let long = try store.create(name: String(repeating: "🗂️", count: 200), folder: downloads)
            for profile in [traversal, long] {
                let url = try store.documentURL(for: profile.id)
                XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL, store.documentsDirectory.standardizedFileURL)
                XCTAssertFalse(url.lastPathComponent.utf8.count > 255)
                XCTAssertEqual(try store.resolve(url), profile)
            }
            XCTAssertEqual(try store.create(name: "...", folder: downloads).name, "DownloadScroller")
        }
    }

    func testMalformedUnknownAndFutureDocumentsAreRejected() throws {
        try withStore { store, root in
            let url = root.appendingPathComponent("Untrusted.downloadscroller")
            try Data("not-json".utf8).write(to: url)
            XCTAssertThrowsError(try store.resolve(url))
            for (version, expected) in [(1, LauncherError.missingProfile), (900, .unsupportedVersion)] {
                let data = try JSONSerialization.data(withJSONObject: ["version": version, "profileID": UUID().uuidString])
                try data.write(to: url)
                do { _ = try store.resolve(url); XCTFail("Unrecognized launcher accepted") }
                catch { XCTAssertEqual(error as? LauncherError, expected) }
            }
            try Data(repeating: 65, count: 4097).write(to: url)
            XCTAssertThrowsError(try store.resolve(url))
        }
    }

    func testWrongExtensionDirectoriesAndSymlinksAreRejected() throws {
        try withStore { store, root in
            let profile = try store.create(name: "Downloads", folder: downloads)
            let original = try store.documentURL(for: profile.id)
            let wrong = root.appendingPathComponent("NotALauncher.txt")
            try FileManager.default.copyItem(at: original, to: wrong)
            XCTAssertThrowsError(try store.resolve(wrong))
            let link = root.appendingPathComponent("Linked.downloadscroller")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: original)
            XCTAssertThrowsError(try store.resolve(link))
            let directory = root.appendingPathComponent("Folder.downloadscroller")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            XCTAssertThrowsError(try store.resolve(directory))
        }
    }

    func testCorruptRegistryIsReportedAndNeverReplaced() throws {
        try withStore { store, root in
            _ = try store.create(name: "Downloads", folder: downloads)
            let registry = root.appendingPathComponent("launchers.json")
            let damaged = Data("damaged registry fixture".utf8)
            try damaged.write(to: registry)
            XCTAssertThrowsError(try store.list())
            XCTAssertThrowsError(try store.create(name: "Another", folder: downloads))
            XCTAssertEqual(try Data(contentsOf: registry), damaged)
        }
    }

    func testEmptyBookmarksAreRejectedWithoutChangingProfiles() throws {
        try withStore { store, _ in
            let original = try store.create(name: "Downloads", folder: downloads)
            let invalid = LauncherFolder(name: "Invalid", bookmark: Data())
            XCTAssertThrowsError(try store.create(name: "Invalid", folder: invalid))
            XCTAssertThrowsError(try store.update(original.id, folder: invalid))
            XCTAssertEqual(try store.list(), [original])
        }
    }

    func testDocumentWriteFailurePreservesExistingRegistry() throws {
        try withStore { store, root in
            let original = try store.create(name: "Downloads", folder: downloads)
            let registry = root.appendingPathComponent("launchers.json")
            let before = try Data(contentsOf: registry)
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: store.documentsDirectory.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: store.documentsDirectory.path) }
            XCTAssertThrowsError(try store.create(name: "Blocked", folder: downloads))
            XCTAssertEqual(try Data(contentsOf: registry), before)
            XCTAssertEqual(try store.list(), [original])
        }
    }

    func testRegistryWriteFailureRollsBackOnlyTheNewDocument() throws {
        try withStore { store, root in
            let original = try store.create(name: "Downloads", folder: downloads)
            let originalURL = try store.documentURL(for: original.id)
            let registry = root.appendingPathComponent("launchers.json")
            let before = try Data(contentsOf: registry)
            let documentBefore = try Data(contentsOf: originalURL)
            // Existing registry remains readable; atomic writes in its parent fail.
            // The separate document directory remains writable.
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: root.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path) }
            XCTAssertThrowsError(try store.create(name: "Rolled back", folder: downloads))
            XCTAssertThrowsError(try store.update(original.id, isEnabled: false))
            XCTAssertEqual(try Data(contentsOf: registry), before)
            XCTAssertEqual(try Data(contentsOf: originalURL), documentBefore)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: store.documentsDirectory.path), [original.filename])
            XCTAssertEqual(try store.resolve(originalURL), original)
        }
    }
}

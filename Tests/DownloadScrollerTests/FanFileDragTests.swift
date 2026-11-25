import AppKit
import DownloadScrollerCore
#if !STANDALONE_CHECKS
import XCTest
@testable import DownloadScroller
#endif

final class FanFileDragTests: XCTestCase {
    @MainActor
    func testFastDraggingExportsThePressedFileFromEitherFolder() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let name = "Résumé #1 & notes.txt"
        for folder in ["Documents", "Downloads"] {
            let source = root.appendingPathComponent(folder)
            try fm.createDirectory(at: source, withIntermediateDirectories: true)
            let contents = Data(folder.utf8)
            try contents.write(to: source.appendingPathComponent(name))
            guard let entry = try FolderScanner.scan(source).first else {
                return XCTFail("Missing generated file in \(folder)")
            }
            let start = NSPoint(x: 190, y: 82)
            let event = NSEvent.mouseEvent(with: .leftMouseDown, location: start, modifierFlags: [],
                                          timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1,
                                          clickCount: 1, pressure: 1)!
            let access = FolderAccess(url: source, scoped: false)
            let press = FanFilePress(entry: entry, mouseDown: event, access: access)
            XCTAssertFalse(press.crossedDragThreshold(at: NSPoint(x: 193, y: 83)))
            XCTAssertEqual(press.crossedDragThreshold(at: NSPoint(x: 32, y: 10)), true)
            XCTAssertEqual(press.mouseDown === event, true)
            let view = NSView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
            let item = press.draggingItem(in: view, image: NSImage(size: NSSize(width: 44, height: 44)))
            let origin = view.convert(start, from: nil)
            XCTAssertEqual(NSPoint(x: item.draggingFrame.midX, y: item.draggingFrame.midY), origin)
            let board = NSPasteboard.withUniqueName()
            defer { board.releaseGlobally() }
            guard let url = item.item as? NSURL else { return XCTFail("Expected a native file URL") }
            XCTAssertEqual(board.writeObjects([url]), true)
            guard let files = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
                  let received = files.first else { return XCTFail("No readable file URL on the drag pasteboard") }
            XCTAssertEqual(files, [entry.url])
            XCTAssertEqual(try Data(contentsOf: received), contents)
        }
    }

    @MainActor
    func testEscapeDuringDragPreservesTheSearchAndWindow() {
        let model = LibraryModel()
        var dismissals = 0
        model.onDismiss = { dismissals += 1 }
        model.search = "report"
        model.isDraggingFile = true
        model.handleEscape()
        XCTAssertEqual(model.search, "report")
        model.search = ""
        model.handleEscape()
        XCTAssertEqual(dismissals, 0)
        model.isDraggingFile = false
        model.handleEscape()
        XCTAssertEqual(dismissals, 1)
    }
}

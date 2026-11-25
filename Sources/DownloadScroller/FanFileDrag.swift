import AppKit
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

/// The original press anchors AppKit's drag image. Keep the source folder's
/// read access alive until AppKit finishes handing the URL to the destination.
@MainActor
struct FanFilePress {
    let entry: FileEntry
    let mouseDown: NSEvent
    let access: FolderAccess

    func crossedDragThreshold(at point: NSPoint) -> Bool {
        let start = mouseDown.locationInWindow
        return hypot(point.x - start.x, point.y - start.y) >= 5
    }

    func draggingItem(in view: NSView, image: NSImage) -> NSDraggingItem {
        let item = NSDraggingItem(pasteboardWriter: entry.url as NSURL)
        let point = view.convert(mouseDown.locationInWindow, from: nil)
        item.setDraggingFrame(NSRect(x: point.x - 22, y: point.y - 22, width: 44, height: 44), contents: image)
        return item
    }
}

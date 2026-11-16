import AppKit
import QuickLookThumbnailing
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

@MainActor
final class ThumbnailStore {
    static let shared = ThumbnailStore()
    private let previews = NSCache<NSString, NSImage>()
    private let icons = NSCache<NSString, NSImage>()
    private var pending: [String: Task<NSImage, Never>] = [:]

    init() { previews.countLimit = 350; icons.countLimit = 350 }

    func key(for entry: FileEntry) -> String {
        "\(entry.id):\(entry.modifiedAt.timeIntervalSince1970):\(entry.size)"
    }

    func cached(for entry: FileEntry) -> NSImage? { previews.object(forKey: key(for: entry) as NSString) }

    func icon(for entry: FileEntry) -> NSImage {
        let key = key(for: entry) as NSString
        if let image = icons.object(forKey: key) { return image }
        let image = NSWorkspace.shared.icon(forFile: entry.url.path)
        icons.setObject(image, forKey: key)
        return image
    }

    func image(for entry: FileEntry) async -> NSImage {
        let key = key(for: entry)
        if let image = previews.object(forKey: key as NSString) { return image }
        if let task = pending[key] { return await task.value }
        let fallback = icon(for: entry)
        // Finder's native app/folder/archive icons already have the right artwork.
        guard [.documents, .images, .videos, .audio].contains(entry.kind) else { return fallback }
        let task = Task { @MainActor in
            let request = QLThumbnailGenerator.Request(fileAt: entry.url, size: CGSize(width: 128, height: 128),
                                                       scale: 2, representationTypes: .all)
            // Ask Quick Look for the system's file-icon treatment, including
            // document framing, rounded edges, and shadows, rather than a raw page.
            request.iconMode = true
            do { return try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage }
            catch { return fallback }
        }
        pending[key] = task
        let image = await task.value
        pending[key] = nil
        previews.setObject(image, forKey: key as NSString)
        return image
    }
}

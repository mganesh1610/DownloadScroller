import AppKit
import QuickLookThumbnailing
import SwiftUI
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

@MainActor
final class ThumbnailStore {
    static let shared = ThumbnailStore()
    let cache = NSCache<NSString, NSImage>()
    init() { cache.countLimit = 250 }

    func image(for entry: FileEntry) async -> NSImage {
        let key = "\(entry.id):\(entry.modifiedAt.timeIntervalSince1970):\(entry.size)" as NSString
        if let image = cache.object(forKey: key) { return image }
        let request = QLThumbnailGenerator.Request(fileAt: entry.url, size: CGSize(width: 56, height: 56),
                                                   scale: NSScreen.main?.backingScaleFactor ?? 2, representationTypes: .all)
        let image: NSImage
        do { image = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage }
        catch { image = NSWorkspace.shared.icon(forFile: entry.url.path) }
        guard !Task.isCancelled else { return image }
        cache.setObject(image, forKey: key)
        return image
    }
}

struct FileThumbnail: View {
    let entry: FileEntry
    var size: CGFloat = 42
    @ViewState private var image: NSImage?

    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFit() }
            else { Image(systemName: entry.kind.symbol).font(.system(size: 26, weight: .light)).foregroundStyle(Palette.mint) }
        }
        .frame(width: size, height: size + 4)
        .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
        .task(id: "\(entry.id):\(entry.modifiedAt):\(entry.size)") {
            let result = await ThumbnailStore.shared.image(for: entry)
            if !Task.isCancelled { image = result }
        }
        .accessibilityHidden(true)
    }
}

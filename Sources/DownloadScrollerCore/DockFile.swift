import Foundation

public enum DockFile {
    /// The Dock represents the newest completed file, independent of fan filters.
    public static func newest(in entries: [FileEntry]) -> FileEntry? {
        let partialExtensions: Set<String> = ["crdownload", "download", "part", "partial", "tmp", "filepart"]
        return entries.filter {
            $0.kind != .folders && !partialExtensions.contains($0.url.pathExtension.lowercased())
        }.min {
            if $0.addedAt != $1.addedAt { return $0.addedAt > $1.addedAt }
            return $0.id < $1.id
        }
    }
}

import Foundation

public enum FolderScanner {
    /// Enumerates only immediate children. No recursion, content indexing, or file count cap.
    public static func scan(_ folder: URL) throws -> [FileEntry] {
        let keys: Set<URLResourceKey> = [
            .nameKey, .isDirectoryKey, .isPackageKey, .fileSizeKey,
            .creationDateKey, .contentModificationDateKey, .addedToDirectoryDateKey
        ]
        let urls = try FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]
        )
        return try urls.compactMap { url in
            try Task.checkCancellation()
            // A file can disappear while the directory is being read.
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            let modified = values.contentModificationDate ?? .distantPast
            return FileEntry(
                url: url,
                name: values.name ?? url.lastPathComponent,
                kind: .classify(extension: url.pathExtension, isDirectory: values.isDirectory == true, isPackage: values.isPackage == true),
                size: Int64(values.fileSize ?? 0),
                addedAt: values.addedToDirectoryDate ?? values.creationDate ?? modified,
                modifiedAt: modified
            )
        }
    }
}

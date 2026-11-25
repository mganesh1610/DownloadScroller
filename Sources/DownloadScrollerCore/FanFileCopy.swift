import Darwin
import Foundation

/// A drop addresses the receiving fan's root or one real directory row.
public enum FanFileCopy {
    public enum CopyError: LocalizedError {
        case invalidFolder, recursiveCopy

        public var errorDescription: String? {
            switch self {
            case .invalidFolder: return "The receiving folder is no longer available. Choose it again."
            case .recursiveCopy: return "Choose a destination outside the folder you are copying."
            }
        }
    }

    public static func sameDirectory(_ first: URL, _ second: URL) -> Bool {
        var a = stat(), b = stat()
        return stat(first.path, &a) == 0 && stat(second.path, &b) == 0 &&
            a.st_dev == b.st_dev && a.st_ino == b.st_ino && (a.st_mode & S_IFMT) == S_IFDIR
    }

    static func destination(root: URL, child: String?) throws -> URL {
        let parent = root.resolvingSymlinksInPath().standardizedFileURL
        guard try parent.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw CopyError.invalidFolder }
        guard let child else { return parent }
        guard !child.isEmpty, !child.contains("/"), child != ".", child != ".." else { throw CopyError.invalidFolder }
        let target = parent.appendingPathComponent(child, isDirectory: true)
        let values = try target.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isAliasFileKey, .isPackageKey])
        guard values.isDirectory == true, values.isSymbolicLink != true,
              values.isAliasFile != true, values.isPackage != true else { throw CopyError.invalidFolder }
        return target
    }

    public static func copy(_ source: URL, into root: URL, child: String?) throws -> URL {
        let target = try destination(root: root, child: child)
        guard !source.lastPathComponent.isEmpty, source.standardizedFileURL.path != "/" else { throw CopyError.recursiveCopy }
        // Check before taking file-coordination locks, including aliases of an
        // enclosing directory and case-insensitive volumes.
        var ancestor = target
        while true {
            if sameDirectory(source, ancestor) { throw CopyError.recursiveCopy }
            let parent = ancestor.deletingLastPathComponent()
            if parent.path == ancestor.path || ancestor.path == "/" { break }
            ancestor = parent
        }
        var coordinationError: NSError?
        var result: Result<URL, Error> = .failure(CopyError.invalidFolder)
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], writingItemAt: target,
                                       options: .forMerging, error: &coordinationError) { from, to in
            result = Result {
                guard sameDirectory(try destination(root: root, child: child), to) else { throw CopyError.invalidFolder }
                return try publishCopy(from: from, named: source.lastPathComponent, into: to)
            }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    private static func publishCopy(from source: URL, named name: String, into folder: URL) throws -> URL {
        let fm = FileManager.default
        let stage = folder.appendingPathComponent(".downloadscroller-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: stage, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: stage) }
        let payload = stage.appendingPathComponent("item")
        try fm.copyItem(at: source, to: payload)
        let original = folder.appendingPathComponent(name)
        var candidate = original
        var number = 1
        while true {
            if renamex_np(payload.path, candidate.path, UInt32(RENAME_EXCL)) == 0 { return candidate }
            let code = errno
            guard code == EEXIST || code == ENOTEMPTY else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: [NSFilePathErrorKey: candidate.path])
            }
            let suffix = number == 1 ? " copy" : " copy \(number)"
            var stem = original.deletingPathExtension().lastPathComponent
            var ext = original.pathExtension.isEmpty ? "" : "." + original.pathExtension
            while (stem + suffix + ext).utf8.count > 255 {
                if !stem.isEmpty { stem.removeLast() } else { ext.removeLast() }
            }
            candidate = folder.appendingPathComponent(stem + suffix + ext)
            number += 1
        }
    }
}

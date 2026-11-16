import Foundation
import UniformTypeIdentifiers

public enum FileKind: String, CaseIterable, Sendable, Identifiable {
    case documents, images, videos, audio, archives, folders, other
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .documents: return "Documents"
        case .images: return "Images"
        case .videos: return "Videos"
        case .audio: return "Audio"
        case .archives: return "Archives"
        case .folders: return "Folders"
        case .other: return "Other"
        }
    }

    public var symbol: String {
        switch self {
        case .documents: return "doc.text"
        case .images: return "photo"
        case .videos: return "film"
        case .audio: return "waveform"
        case .archives: return "archivebox"
        case .folders: return "folder"
        case .other: return "doc"
        }
    }

    public static func classify(extension ext: String, isDirectory: Bool, isPackage: Bool = false) -> FileKind {
        if isDirectory && !isPackage { return .folders }
        let ext = ext.lowercased()
        if ["zip", "gz", "tgz", "bz2", "xz", "7z", "rar", "tar", "dmg", "iso"].contains(ext) { return .archives }
        guard let type = UTType(filenameExtension: ext) else { return .other }
        if type.conforms(to: .image) { return .images }
        if type.conforms(to: .movie) { return .videos }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .text) || type.conforms(to: .pdf) || type.conforms(to: .spreadsheet)
            || type.conforms(to: .presentation) || ["doc", "docx", "pages", "numbers", "key", "epub"].contains(ext) {
            return .documents
        }
        return .other
    }
}

public struct FileEntry: Identifiable, Equatable, Sendable {
    public let url: URL
    public let name: String
    public let kind: FileKind
    public let size: Int64
    public let addedAt: Date
    public let modifiedAt: Date
    public var id: String { url.path }

    public init(url: URL, name: String, kind: FileKind, size: Int64, addedAt: Date, modifiedAt: Date) {
        self.url = url
        self.name = name
        self.kind = kind
        self.size = size
        self.addedAt = addedAt
        self.modifiedAt = modifiedAt
    }
}

public enum FileSort: String, CaseIterable, Identifiable, Sendable {
    case newest, oldest, name, size, kind
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .newest: return "Newest near Dock"
        case .oldest: return "Oldest near Dock"
        case .name: return "Name (A–Z from Dock)"
        case .size: return "Largest near Dock"
        case .kind: return "Kind"
        }
    }
}

public enum FileQuery {
    /// A fan starts at the Dock and unfolds upward. The highest-priority item
    /// is therefore last in the document's top-to-bottom visual order.
    public static func fanOrder(_ entries: [FileEntry], search: String = "", kind: FileKind? = nil, sort: FileSort = .newest) -> [FileEntry] {
        Array(apply(entries, search: search, kind: kind, sort: sort).reversed())
    }

    public static func apply(_ entries: [FileEntry], search: String = "", kind: FileKind? = nil, sort: FileSort = .newest) -> [FileEntry] {
        let terms = search.split(whereSeparator: \.isWhitespace).map(String.init)
        return entries.filter { entry in
            (kind == nil || kind == entry.kind) && terms.allSatisfy { entry.name.localizedStandardContains($0) }
        }.sorted { lhs, rhs in
            switch sort {
            case .newest where lhs.addedAt != rhs.addedAt: return lhs.addedAt > rhs.addedAt
            case .oldest where lhs.addedAt != rhs.addedAt: return lhs.addedAt < rhs.addedAt
            case .size where lhs.size != rhs.size: return lhs.size > rhs.size
            case .kind where lhs.kind != rhs.kind: return lhs.kind.title < rhs.kind.title
            default:
                let comparison = lhs.name.localizedStandardCompare(rhs.name)
                return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
            }
        }
    }
}

import Foundation

public struct LauncherFolder: Codable, Equatable, Sendable {
    public let name: String
    public let bookmark: Data

    public init(name: String, bookmark: Data) {
        self.name = name
        self.bookmark = bookmark
    }
}

public struct LauncherProfile: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public var folder: LauncherFolder
    public var isEnabled: Bool
    public let filename: String
}

public enum LauncherError: LocalizedError, Equatable {
    case invalidDocument, unsupportedVersion, missingProfile, disabled(String), invalidRegistry, invalidFolder

    public var errorDescription: String? {
        switch self {
        case .invalidDocument: return "This is not a valid DownloadScroller launcher. Create a new launcher in Dock & Launchers."
        case .unsupportedVersion: return "This launcher needs a newer version of DownloadScroller."
        case .missingProfile: return "This launcher is not connected on this Mac. Create a launcher in Dock & Launchers."
        case .disabled(let name): return "\(name) is disabled. Turn on Enabled in Dock & Launchers to use it again."
        case .invalidRegistry: return "Saved launchers could not be read. They have been left unchanged."
        case .invalidFolder: return "Choose a folder before creating this launcher."
        }
    }
}

/// Owns the private profiles and the movable, ID-only launcher documents.
/// Call from one serial owner; there is one app process managing this store.
public final class LauncherStore {
    private struct Registry: Codable {
        var version = 1
        var profiles: [LauncherProfile] = []
    }
    private struct Document: Codable {
        let version: Int
        let profileID: UUID
    }

    public let documentsDirectory: URL
    public let fileExtension: String
    private let registryURL: URL
    private let fileManager = FileManager.default
    private static let documentLimit = 4096
    private static let registryLimit = 16 * 1024 * 1024

    public init(directory: URL, fileExtension: String = "downloadscroller") {
        self.fileExtension = fileExtension
        documentsDirectory = directory.appendingPathComponent("Dock Launchers", isDirectory: true)
        registryURL = directory.appendingPathComponent("launchers.json")
    }

    public func list() throws -> [LauncherProfile] { try readRegistry().profiles }

    @discardableResult
    public func create(name: String, folder: LauncherFolder) throws -> LauncherProfile {
        guard !folder.bookmark.isEmpty else { throw LauncherError.invalidFolder }
        var registry = try readRegistry()
        try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        let base = Self.safeName(name)
        var displayName = base
        var suffix = 2
        var url = documentsDirectory.appendingPathComponent(displayName).appendingPathExtension(fileExtension)
        while fileManager.fileExists(atPath: url.path) || registry.profiles.contains(where: { $0.filename == url.lastPathComponent }) {
            displayName = "\(base) \(suffix)"
            suffix += 1
            url = documentsDirectory.appendingPathComponent(displayName).appendingPathExtension(fileExtension)
        }
        let profile = LauncherProfile(id: UUID(), name: displayName, folder: folder, isEnabled: true,
                                      filename: url.lastPathComponent)
        let document = try JSONEncoder().encode(Document(version: 1, profileID: profile.id))
        // Without-overwriting makes the collision check safe even if Finder
        // creates a file between choosing the name and writing the document.
        try document.write(to: url, options: .withoutOverwriting)
        registry.profiles.append(profile)
        do { try save(registry) }
        catch {
            try? fileManager.removeItem(at: url)
            throw error
        }
        return profile
    }

    @discardableResult
    public func duplicate(_ id: UUID) throws -> LauncherProfile {
        let profile = try lookup(id, in: readRegistry())
        return try create(name: profile.name + " copy", folder: profile.folder)
    }

    public func update(_ id: UUID, folder: LauncherFolder? = nil, isEnabled: Bool? = nil) throws {
        var registry = try readRegistry()
        guard let index = registry.profiles.firstIndex(where: { $0.id == id }) else { throw LauncherError.missingProfile }
        if let folder {
            guard !folder.bookmark.isEmpty else { throw LauncherError.invalidFolder }
            registry.profiles[index].folder = folder
        }
        if let isEnabled { registry.profiles[index].isEnabled = isEnabled }
        try save(registry)
    }

    public func documentURL(for id: UUID) throws -> URL {
        let profile = try lookup(id, in: readRegistry())
        return documentsDirectory.appendingPathComponent(profile.filename)
    }

    /// A file at the old path may have been replaced in Finder. Only decorate
    /// the managed document that still identifies this particular profile.
    public func iconDestination(for profile: LauncherProfile) throws -> URL {
        let url = documentsDirectory.appendingPathComponent(profile.filename)
        guard try documentsDirectory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true,
              url.deletingLastPathComponent().standardizedFileURL == documentsDirectory.standardizedFileURL,
              try readDocument(url).profileID == profile.id,
              (try fileManager.attributesOfItem(atPath: url.path)[.referenceCount] as? NSNumber)?.intValue == 1
        else { throw LauncherError.invalidDocument }
        return url
    }

    public func resolve(_ url: URL) throws -> LauncherProfile {
        let document = try readDocument(url)
        let profile = try lookup(document.profileID, in: readRegistry())
        guard profile.isEnabled else { throw LauncherError.disabled(profile.name) }
        return profile
    }

    private func readDocument(_ url: URL) throws -> Document {
        guard url.isFileURL, url.pathExtension.lowercased() == fileExtension.lowercased() else {
            throw LauncherError.invalidDocument
        }
        let document: Document
        do {
            let data = try readBoundedFile(url, limit: Self.documentLimit)
            document = try JSONDecoder().decode(Document.self, from: data)
        } catch { throw LauncherError.invalidDocument }
        guard document.version == 1 else { throw LauncherError.unsupportedVersion }
        return document
    }

    private func lookup(_ id: UUID, in registry: Registry) throws -> LauncherProfile {
        guard let profile = registry.profiles.first(where: { $0.id == id }) else { throw LauncherError.missingProfile }
        return profile
    }

    private func readRegistry() throws -> Registry {
        guard fileManager.fileExists(atPath: registryURL.path) else { return Registry() }
        do {
            let registry = try JSONDecoder().decode(Registry.self, from: readBoundedFile(registryURL, limit: Self.registryLimit))
            guard registry.version == 1,
                  Set(registry.profiles.map(\.id)).count == registry.profiles.count,
                  Set(registry.profiles.map(\.filename)).count == registry.profiles.count,
                  registry.profiles.allSatisfy({
                      !$0.name.isEmpty && !$0.folder.bookmark.isEmpty &&
                      $0.filename == ($0.filename as NSString).lastPathComponent &&
                      ($0.filename as NSString).pathExtension == fileExtension && !$0.filename.hasPrefix(".")
                  }) else { throw LauncherError.invalidRegistry }
            return registry
        } catch { throw LauncherError.invalidRegistry }
    }

    private func save(_ registry: Registry) throws {
        let data = try JSONEncoder().encode(registry)
        guard data.count <= Self.registryLimit else { throw LauncherError.invalidRegistry }
        try data.write(to: registryURL, options: .atomic)
    }

    private func readBoundedFile(_ url: URL, limit: Int) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= limit else { throw LauncherError.invalidDocument }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: limit + 1) ?? Data()
        guard data.count <= limit else { throw LauncherError.invalidDocument }
        return data
    }

    private static func safeName(_ proposed: String) -> String {
        let forbidden = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/:\\"))
        let cleaned = proposed.components(separatedBy: forbidden).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        var result = ""
        for character in cleaned {
            if (result + String(character)).utf8.count > 160 { break }
            result.append(character)
        }
        return result.isEmpty ? "DownloadScroller" : result
    }
}

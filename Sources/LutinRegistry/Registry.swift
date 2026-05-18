import Foundation
import LutinCore

/// One remembered project. `lutin.yml` is the source of truth; this is a cache.
public struct RegistryEntry: Codable, Equatable {
    public var name: String
    public var configPath: String
    public var appPath: String
    public var lastDetectedVersion: String?
    public var lastReleaseStatus: String?
    public var createdDate: Date
    public var lastOpenedDate: Date

    public init(name: String, configPath: String, appPath: String,
                lastDetectedVersion: String?, lastReleaseStatus: String?,
                createdDate: Date, lastOpenedDate: Date) {
        self.name = name
        self.configPath = configPath
        self.appPath = appPath
        self.lastDetectedVersion = lastDetectedVersion
        self.lastReleaseStatus = lastReleaseStatus
        self.createdDate = createdDate
        self.lastOpenedDate = lastOpenedDate
    }
}

/// A registry entry plus its on-disk status, computed at read time.
public struct RegistryEntryStatus: Equatable {
    public enum Status: String { case ok, missing }
    public let entry: RegistryEntry
    public let status: Status
}

private struct RegistryFile: Codable {
    var schemaVersion: Int
    var projects: [RegistryEntry]
}

public final class Registry {
    public let storeURL: URL

    /// Default store: `~/Library/Application Support/Lutin/projects.json`.
    public static func defaultStoreURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Lutin").appendingPathComponent("projects.json")
    }

    public init(storeURL: URL) {
        self.storeURL = storeURL
    }

    public convenience init() {
        self.init(storeURL: Registry.defaultStoreURL())
    }

    private func read() throws -> RegistryFile {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return RegistryFile(schemaVersion: 1, projects: [])
        }
        let data = try Data(contentsOf: storeURL)
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(RegistryFile.self, from: data)
        } catch {
            throw LutinError(
                code: "registry_corrupt",
                message: "projects.json at \(storeURL.path) is unreadable. Fix or delete it.",
                details: ["path": storeURL.path]
            )
        }
    }

    private func write(_ file: RegistryFile) throws {
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)
        // Atomic: write to a temp file, then replace.
        let tmp = storeURL.appendingPathExtension("tmp-\(UUID().uuidString)")
        try data.write(to: tmp)
        _ = try FileManager.default.replaceItemAt(storeURL, withItemAt: tmp)
    }

    /// All entries, in stored order.
    public func allEntries() throws -> [RegistryEntry] {
        try read().projects
    }

    /// Inserts a new entry or replaces an existing one with the same name.
    public func upsert(_ entry: RegistryEntry) throws {
        var file = try read()
        file.projects.removeAll { $0.name == entry.name }
        file.projects.append(entry)
        try write(file)
    }
}

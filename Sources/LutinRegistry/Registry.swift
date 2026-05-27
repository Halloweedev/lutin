import Foundation
import LutinCore

/// Outcome of the most recent build the user ran for this project.
/// Surfaced as the build-status pill on the welcome page.
public enum BuildOutcome: String, Codable, Equatable {
    case succeeded
    case failed
    case unsigned
}

/// One remembered project. `lutin.yml` is the source of truth; this is a cache.
public struct RegistryEntry: Codable, Equatable {
    public var name: String
    public var configPath: String
    public var appPath: String
    public var lastDetectedVersion: String?
    public var lastReleaseStatus: String?
    public var lastBuildOutcome: BuildOutcome?
    public var createdDate: Date
    public var lastOpenedDate: Date

    public init(name: String, configPath: String, appPath: String,
                lastDetectedVersion: String?, lastReleaseStatus: String?,
                lastBuildOutcome: BuildOutcome? = nil,
                createdDate: Date, lastOpenedDate: Date) {
        self.name = name
        self.configPath = configPath
        self.appPath = appPath
        self.lastDetectedVersion = lastDetectedVersion
        self.lastReleaseStatus = lastReleaseStatus
        self.lastBuildOutcome = lastBuildOutcome
        self.createdDate = createdDate
        self.lastOpenedDate = lastOpenedDate
    }
}

/// A registry entry plus its on-disk status, computed at read time.
public struct RegistryEntryStatus: Equatable {
    public enum Status: String { case ok, missing }
    public let entry: RegistryEntry
    public let status: Status
    public init(entry: RegistryEntry, status: Status) {
        self.entry = entry
        self.status = status
    }
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
        do {
            let data = try Data(contentsOf: storeURL)
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

    /// Returns the entry with `name`, or nil.
    public func find(name: String) throws -> RegistryEntry? {
        try read().projects.first { $0.name == name }
    }

    /// Removes the entry with `name`; throws if it is not registered.
    public func remove(name: String) throws {
        var file = try read()
        guard file.projects.contains(where: { $0.name == name }) else {
            throw LutinError(
                code: "project_not_in_registry",
                message: "No project named '\(name)' is registered.",
                details: ["name": name]
            )
        }
        file.projects.removeAll { $0.name == name }
        try write(file)
    }

    /// All entries with their on-disk status (`ok` / `missing`). Never prunes.
    public func list() throws -> [RegistryEntryStatus] {
        try read().projects.map { entry in
            let exists = FileManager.default.fileExists(atPath: entry.configPath)
            return RegistryEntryStatus(entry: entry, status: exists ? .ok : .missing)
        }
    }

    /// Updates `lastOpenedDate` for an entry; throws if not registered.
    public func touchOpened(name: String, date: Date = Date()) throws {
        var file = try read()
        guard let index = file.projects.firstIndex(where: { $0.name == name }) else {
            throw LutinError(
                code: "project_not_in_registry",
                message: "No project named '\(name)' is registered.",
                details: ["name": name]
            )
        }
        file.projects[index].lastOpenedDate = date
        try write(file)
    }
}

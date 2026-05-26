import Foundation
import Observation
import LutinCore
import LutinConfig
import LutinRegistry

/// App-wide observable wrapper over the on-disk `LutinRegistry`. The sidebar
/// reads `entries`; `reload()` re-reads from disk; `remove` and `add` go
/// through the same code paths the CLI uses.
@Observable
public final class RegistryStore {
    public private(set) var entries: [RegistryEntryStatus] = []
    public private(set) var lastError: LutinError?

    @ObservationIgnored
    private let registry: Registry

    public init(registry: Registry = Registry()) {
        self.registry = registry
    }

    public func reload() throws {
        do {
            entries = try registry.list()
            lastError = nil
        } catch let error as LutinError {
            lastError = error
            throw error
        }
    }

    public func remove(name: String) throws {
        try registry.remove(name: name)
        try reload()
    }

    public func touchOpened(name: String, date: Date = Date()) throws {
        try registry.touchOpened(name: name, date: date)
        try reload()
    }

    public func upsert(_ entry: RegistryEntry) throws {
        try registry.upsert(entry)
        try reload()
    }

    /// Updates the recorded build outcome for a registered project.
    /// Silently no-ops when the project is not in the registry.
    public func recordBuildOutcome(name: String, outcome: BuildOutcome) throws {
        guard var entry = try registry.find(name: name) else { return }
        entry.lastBuildOutcome = outcome
        try registry.upsert(entry)
        try reload()
    }

    /// Convenience: add a project from a `lutin.yml` URL. Mirrors the CLI
    /// `add` command by reading the project name and resolving the app path
    /// from the config.
    public func add(configURL: URL) throws {
        let config = try LutinConfig.load(from: configURL)
        let projectDir = configURL.deletingLastPathComponent()
        let appURL = URL(fileURLWithPath: config.app.path, relativeTo: projectDir)
        let entry = RegistryEntry(
            name: config.project.name,
            configPath: configURL.path,
            appPath: appURL.path,
            lastDetectedVersion: nil,
            lastReleaseStatus: nil,
            createdDate: Date(),
            lastOpenedDate: Date()
        )
        try upsert(entry)
    }
}

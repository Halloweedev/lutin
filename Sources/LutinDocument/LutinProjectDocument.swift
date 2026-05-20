import Foundation
import Observation
import LutinCore
import LutinConfig

/// Per-project state. Phase 1 form: read-only — exposes the parsed
/// `LutinConfig` and the project directory. Phase 2 (task 2.1) promotes this
/// to mutable with dirty tracking, undo, atomic save, and FSEvents.
@Observable
public final class LutinProjectDocument: Identifiable {
    public let id = UUID()
    public private(set) var config: LutinConfig
    public let configURL: URL
    public let projectDirectory: URL
    public private(set) var isDirty: Bool = false

    public init(configURL: URL) throws {
        self.configURL = configURL.standardizedFileURL
        self.projectDirectory = configURL.deletingLastPathComponent().standardizedFileURL
        do {
            self.config = try LutinConfig.load(from: configURL)
        } catch let error as LutinError {
            throw error
        } catch {
            throw LutinError(code: "config_load_failed",
                             message: "Could not load \(configURL.path): \(error.localizedDescription)")
        }
    }
}

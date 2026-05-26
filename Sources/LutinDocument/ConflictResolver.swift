import Foundation
import LutinCore
import LutinConfig

/// Resolves the situation where the GUI is dirty AND the on-disk file changed.
/// Exposes the three user choices and a computed unified diff for the UI.
public final class ConflictResolver {
    public let document: LutinProjectDocument

    public init(document: LutinProjectDocument) {
        self.document = document
    }

    /// Discard the on-disk file's contents. Next save overwrites disk.
    public func keepMine() throws {
        // No-op on the in-memory state. The doc is still dirty; ⌘S will overwrite disk.
        document.clearPendingConflict()
    }

    /// Replace the in-memory config with the on-disk version. Marks clean.
    public func takeDisk() throws {
        try document.forceReloadFromDisk()
    }

    /// Returns a UnifiedDiff comparing the on-disk YAML to the in-memory YAML.
    public func computeDiff() throws -> UnifiedDiff {
        let diskBytes = try Data(contentsOf: document.configURL)
        let diskText = String(decoding: diskBytes, as: UTF8.self)
        let memoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutin-conflict-\(UUID().uuidString).yml")
        try document.config.save(to: memoryURL)
        defer { try? FileManager.default.removeItem(at: memoryURL) }
        let memoryText = String(decoding: try Data(contentsOf: memoryURL), as: UTF8.self)
        return UnifiedDiff.diff(left: diskText, right: memoryText)
    }
}

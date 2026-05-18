import Foundation

public struct ConfigIssue: Equatable, Codable {
    public enum Severity: String, Codable { case error, warning }
    public let severity: Severity
    public let path: String
    public let message: String
}

/// Structural + semantic validation, separate from YAML parsing.
/// Returns every issue found rather than throwing on the first.
public enum ConfigValidator {
    public static func validate(_ config: LutinConfig) -> [ConfigIssue] {
        var issues: [ConfigIssue] = []

        func error(_ path: String, _ message: String) {
            issues.append(ConfigIssue(severity: .error, path: path, message: message))
        }

        if config.project.name.trimmingCharacters(in: .whitespaces).isEmpty {
            error("project.name", "Project name must not be empty.")
        }
        if config.project.bundleId.trimmingCharacters(in: .whitespaces).isEmpty {
            error("project.bundleId", "Bundle identifier must not be empty.")
        }
        if config.app.path.trimmingCharacters(in: .whitespaces).isEmpty {
            error("app.path", "App path must not be empty.")
        }
        if config.output.directory.trimmingCharacters(in: .whitespaces).isEmpty {
            error("output.directory", "Output directory must not be empty.")
        }
        if config.output.dmgName.trimmingCharacters(in: .whitespaces).isEmpty {
            error("output.dmgName", "DMG name must not be empty.")
        }

        let items = config.items ?? []
        var seenIds = Set<String>()
        for item in items {
            if !["app", "applications"].contains(item.type) {
                error("items[].type", "Unknown item type '\(item.type)'.")
            }
            if !seenIds.insert(item.id).inserted {
                error("items[].id", "Duplicate item id '\(item.id)'.")
            }
        }

        for decoration in config.decorations ?? [] {
            if decoration.type != "arrow" {
                error("decorations[].type", "Unknown decoration type '\(decoration.type)'.")
            }
            if !seenIds.contains(decoration.from) {
                error("decorations[].from", "Decoration references unknown item id '\(decoration.from)'.")
            }
            if !seenIds.contains(decoration.to) {
                error("decorations[].to", "Decoration references unknown item id '\(decoration.to)'.")
            }
        }
        return issues
    }
}

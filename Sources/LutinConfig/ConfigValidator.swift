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

        for (idx, decoration) in (config.decorations ?? []).enumerated() {
            switch decoration.type {
            case "arrow":
                if let from = decoration.from, !from.isEmpty {
                    if !seenIds.contains(from) {
                        error("decorations[\(idx)].from",
                              "Decoration references unknown item id '\(from)'.")
                    }
                } else {
                    error("decorations[\(idx)].from",
                          "An arrow decoration requires a 'from' item id.")
                }
                if let to = decoration.to, !to.isEmpty {
                    if !seenIds.contains(to) {
                        error("decorations[\(idx)].to",
                              "Decoration references unknown item id '\(to)'.")
                    }
                } else {
                    error("decorations[\(idx)].to",
                          "An arrow decoration requires a 'to' item id.")
                }
            case "image":
                if (decoration.path ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
                    error("decorations[\(idx)].path",
                          "An image decoration requires a 'path' to the overlay file.")
                }
                if decoration.x == nil {
                    error("decorations[\(idx)].x",
                          "An image decoration requires an 'x' position.")
                }
                if decoration.y == nil {
                    error("decorations[\(idx)].y",
                          "An image decoration requires a 'y' position.")
                }
            default:
                error("decorations[\(idx)].type",
                      "Unknown decoration type '\(decoration.type)'. Use 'arrow' or 'image'.")
            }
        }
        return issues
    }
}

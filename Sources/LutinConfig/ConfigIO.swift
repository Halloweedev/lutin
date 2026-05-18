import Foundation
import Yams
import LutinCore

extension LutinConfig {
    /// Loads and decodes a `lutin.yml` file.
    public static func load(from url: URL) throws -> LutinConfig {
        guard let data = try? Data(contentsOf: url) else {
            throw LutinError(
                code: "config_not_found",
                message: "No lutin.yml found at \(url.path).",
                details: ["path": url.path]
            )
        }
        do {
            return try YAMLDecoder().decode(LutinConfig.self, from: data)
        } catch {
            throw LutinError(
                code: "invalid_config",
                message: "lutin.yml at \(url.path) could not be parsed: \(error).",
                details: ["path": url.path]
            )
        }
    }
}

extension LutinConfig {
    /// Serializes to YAML with a stable header comment and writes atomically.
    public func save(to url: URL) throws {
        let encoder = YAMLEncoder()
        encoder.options.sortKeys = false
        let body: String
        do {
            body = try encoder.encode(self)
        } catch {
            throw LutinError(
                code: "invalid_config",
                message: "Could not serialize lutin.yml: \(error).")
        }
        let header = "# lutin.yml — managed by Lutin. Edit freely; this file is the source of truth.\n"
        let text = header + body
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw LutinError(
                code: "write_failed",
                message: "Could not write lutin.yml to \(url.path): \(error.localizedDescription).",
                details: ["path": url.path]
            )
        }
    }
}

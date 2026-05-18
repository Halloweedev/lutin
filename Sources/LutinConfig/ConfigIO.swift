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

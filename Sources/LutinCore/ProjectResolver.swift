import Foundation

/// Resolves which `lutin.yml` a command targets.
/// Precedence: explicit `--config` > named registry argument > current directory.
public enum ProjectResolver {
    public static func resolve(
        explicitConfig: String?,
        projectName: String?,
        currentDirectory: URL,
        registryLookup: (String) throws -> URL?
    ) throws -> URL {
        // 1. Explicit --config wins.
        if let explicitConfig {
            let url = URL(fileURLWithPath: explicitConfig)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw LutinError(
                    code: "config_not_found",
                    message: "No lutin.yml found at \(url.path).",
                    details: ["path": url.path]
                )
            }
            return url
        }

        // 2. Named registry argument.
        if let projectName {
            guard let url = try registryLookup(projectName) else {
                throw LutinError(
                    code: "project_not_in_registry",
                    message: "No project named '\(projectName)' is registered. Run `lutin projects`.",
                    details: ["name": projectName]
                )
            }
            return url
        }

        // 3. ./lutin.yml in the current directory.
        let cwdConfig = currentDirectory.appendingPathComponent("lutin.yml")
        guard FileManager.default.fileExists(atPath: cwdConfig.path) else {
            throw LutinError(
                code: "no_project_in_cwd",
                message: "No lutin.yml in the current directory. "
                       + "Pass --config, a project name, or run `lutin init`."
            )
        }
        return cwdConfig
    }
}

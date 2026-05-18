import Foundation
import ArgumentParser
import LutinCore
import LutinConfig
import LutinRegistry
import LutinBuilder

// MARK: - Shared options

struct CommonOptions: ParsableArguments {
    @Flag(name: .long, help: "Emit machine-readable JSON.")
    var json = false
    @Flag(name: .long, help: "Print extra detail.")
    var verbose = false
    @Flag(name: .long, help: "Show what would happen without making changes.")
    var dryRun = false
}

// MARK: - Pure command logic (testable without a process)

/// Pure functions behind each command. The `ParsableCommand.run()` methods and
/// the unit tests both call these, so behaviour is verified without spawning a process.
enum CommandLogic {
    struct InitResult: Encodable {
        let projectName: String
        let bundleId: String
        let configPath: String
        let dryRun: Bool
    }

    /// Creates a `lutin.yml` in `directory`, auto-detecting fields from the app bundle,
    /// and registers the project. Version stays as the `${version}` token.
    static func initProject(directory: URL, appPath: String?, template: String,
                            registry: Registry, dryRun: Bool) throws -> InitResult {
        _ = try Templates.named(template)   // validates the template name

        var name = "App"
        var bundleId = "com.example.app"
        var relativeAppPath = appPath ?? "./App.app"

        if let appPath {
            let appURL = URL(fileURLWithPath: appPath)
            let info = try InfoPlistReader.read(appBundle: appURL)
            if !info.bundleName.isEmpty { name = info.bundleName }
            if !info.bundleIdentifier.isEmpty { bundleId = info.bundleIdentifier }
            relativeAppPath = "./" + appURL.lastPathComponent
        }

        let config = LutinConfig(
            project: .init(name: name, bundleId: bundleId),
            app: .init(path: relativeAppPath),
            output: .init(directory: "./release",
                          dmgName: "\(name)-${version}.dmg", volumeName: name),
            window: nil,
            background: LutinConfig.BackgroundInfo(
                type: nil, template: template, scale: nil, colorA: nil,
                colorB: nil, grid: nil, noise: nil, cornerRadius: nil),
            items: nil, decorations: nil, signing: nil, notarization: nil, sparkle: nil)

        let configURL = directory.appendingPathComponent("lutin.yml")
        if !dryRun {
            try config.save(to: configURL)
            let now = Date()
            try registry.upsert(RegistryEntry(
                name: name, configPath: configURL.path,
                appPath: directory.appendingPathComponent(
                    URL(fileURLWithPath: relativeAppPath).lastPathComponent).path,
                lastDetectedVersion: nil, lastReleaseStatus: nil,
                createdDate: now, lastOpenedDate: now))
        }
        return InitResult(projectName: name, bundleId: bundleId,
                          configPath: configURL.path, dryRun: dryRun)
    }

    struct AddResult: Encodable { let name: String; let configPath: String }

    /// Registers an existing `lutin.yml`. Fails on a duplicate name.
    @discardableResult
    static func addProject(configPath: String, overrideName: String?,
                           registry: Registry) throws -> AddResult {
        let configURL = URL(fileURLWithPath: configPath)
        let config = try LutinConfig.load(from: configURL)
        let name = overrideName ?? config.project.name

        if try registry.find(name: name) != nil {
            throw LutinError(
                code: "duplicate_project",
                message: "A project named '\(name)' is already registered. "
                       + "Use `lutin add \(configPath) --name \(name)-2` to register it "
                       + "under a different name.",
                details: ["name": name]
            )
        }
        let appURL = URL(fileURLWithPath: config.app.path,
                         relativeTo: configURL.deletingLastPathComponent())
        let now = Date()
        try registry.upsert(RegistryEntry(
            name: name, configPath: configURL.path, appPath: appURL.path,
            lastDetectedVersion: nil, lastReleaseStatus: nil,
            createdDate: now, lastOpenedDate: now))
        return AddResult(name: name, configPath: configURL.path)
    }

    static func removeProject(name: String, registry: Registry) throws {
        try registry.remove(name: name)
    }

    struct ProjectListItem: Encodable {
        let name: String
        let status: String
        let configPath: String
        let lastDetectedVersion: String?
        let lastReleaseStatus: String?
    }

    static func listProjects(registry: Registry) throws -> [ProjectListItem] {
        try registry.list().map {
            ProjectListItem(
                name: $0.entry.name, status: $0.status.rawValue,
                configPath: $0.entry.configPath,
                lastDetectedVersion: $0.entry.lastDetectedVersion,
                lastReleaseStatus: $0.entry.lastReleaseStatus)
        }
    }

    struct OpenResult: Encodable { let name: String; let configPath: String }

    static func openProject(name: String, registry: Registry) throws -> OpenResult {
        guard let entry = try registry.find(name: name) else {
            throw LutinError(
                code: "project_not_in_registry",
                message: "No project named '\(name)' is registered. Run `lutin projects`.",
                details: ["name": name])
        }
        try registry.touchOpened(name: name)
        return OpenResult(name: name, configPath: entry.configPath)
    }
}

import Foundation
import ArgumentParser
import LutinCore
import LutinConfig
import LutinRegistry
import LutinBuilder
import LutinRelease

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
                type: nil, template: template, path: nil, scale: nil, colorA: nil,
                colorB: nil, grid: nil, noise: nil, cornerRadius: nil),
            items: [
                LutinConfig.Item(type: "app", id: "app", x: 180, y: 220, label: name),
                LutinConfig.Item(type: "applications", id: "applications",
                                 x: 500, y: 220, label: "Applications"),
            ],
            // No default arrow — users can drag-to-connect on the canvas
            // if they want one. Keeps the CLI bootstrap aligned with
            // ProjectBootstrap (the GUI's ⌘N path).
            decorations: nil,
            signing: nil, notarization: nil, sparkle: nil)

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
                           registry: Registry, dryRun: Bool) throws -> AddResult {
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
        if !dryRun {
            let now = Date()
            try registry.upsert(RegistryEntry(
                name: name, configPath: configURL.path, appPath: appURL.path,
                lastDetectedVersion: nil, lastReleaseStatus: nil,
                createdDate: now, lastOpenedDate: now))
        }
        return AddResult(name: name, configPath: configURL.path)
    }

    static func removeProject(name: String, registry: Registry, dryRun: Bool) throws {
        if dryRun {
            guard try registry.find(name: name) != nil else {
                throw LutinError(
                    code: "project_not_in_registry",
                    message: "No project named '\(name)' is registered.",
                    details: ["name": name]
                )
            }
        } else {
            try registry.remove(name: name)
        }
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

    // MARK: validate

    static func validateConfig(configURL: URL) throws -> [ConfigIssue] {
        let config = try LutinConfig.load(from: configURL)
        return ConfigValidator.validate(config)
    }

    // MARK: doctor

    struct DoctorCheck: Encodable {
        let name: String
        let ok: Bool
        let detail: String
    }

    static func doctor(configURL: URL,
                       runner: CommandRunning = ShellCommandRunner()) throws -> [DoctorCheck] {
        var checks: [DoctorCheck] = []

        // config
        let loaded: LutinConfig?
        do {
            let config = try LutinConfig.load(from: configURL)
            let withDefaults = try Templates.applyDefaults(to: config)
            let issues = ConfigValidator.validate(withDefaults)
            let errorCount = issues.filter { $0.severity == .error }.count
            checks.append(DoctorCheck(name: "config", ok: errorCount == 0,
                detail: errorCount == 0 ? "lutin.yml is valid"
                                        : "\(errorCount) validation error(s)"))
            loaded = config
        } catch let error as LutinError {
            checks.append(DoctorCheck(name: "config", ok: false, detail: error.message))
            loaded = nil
        }

        // appBundle
        if let config = loaded {
            let appURL = URL(fileURLWithPath: config.app.path,
                             relativeTo: configURL.deletingLastPathComponent())
            let info = try? InfoPlistReader.read(appBundle: appURL)
            checks.append(DoctorCheck(name: "appBundle", ok: info != nil,
                detail: info != nil ? "app bundle and Info.plist readable"
                                     : "app bundle missing or Info.plist unreadable"))

            // outputDirectory
            let outURL = URL(fileURLWithPath: config.output.directory,
                             relativeTo: configURL.deletingLastPathComponent())
            let parent = outURL.deletingLastPathComponent()
            let writable = FileManager.default.isWritableFile(atPath: parent.path)
            checks.append(DoctorCheck(name: "outputDirectory", ok: writable,
                detail: writable ? "output directory location is writable"
                                  : "cannot write to \(parent.path)"))
        } else {
            checks.append(DoctorCheck(name: "appBundle", ok: false, detail: "skipped — config invalid"))
            checks.append(DoctorCheck(name: "outputDirectory", ok: false, detail: "skipped — config invalid"))
        }

        // tools
        let tools = ["/usr/bin/hdiutil", "/usr/bin/codesign", "/usr/bin/xcrun"]
        let missing = tools.filter { !FileManager.default.isExecutableFile(atPath: $0) }
        checks.append(DoctorCheck(name: "tools", ok: missing.isEmpty,
            detail: missing.isEmpty ? "hdiutil, codesign, xcrun available"
                                     : "missing: \(missing.joined(separator: ", "))"))

        // signingIdentity — only when signing is enabled.
        if let config = loaded, let signing = config.signing, signing.enabled {
            let identity = signing.identity ?? ""
            let found = (try? runner.runAllowingFailure(
                "/usr/bin/security",
                ["find-identity", "-v", "-p", "codesigning"]).stdout) ?? ""
            let ok = !identity.isEmpty && found.contains(identity)
            checks.append(DoctorCheck(name: "signingIdentity", ok: ok,
                detail: ok ? "signing identity found in the Keychain"
                            : "signing identity '\(identity)' not found in the Keychain"))
        }

        // notaryProfile — only when notarization is enabled.
        if let config = loaded, let notarization = config.notarization,
           notarization.enabled {
            let profile = notarization.profile ?? ""
            // `notarytool history` against the profile succeeds iff it exists.
            let result = try? runner.runAllowingFailure("/usr/bin/xcrun",
                ["notarytool", "history", "--keychain-profile", profile])
            let ok = (result?.exitCode == 0)
            checks.append(DoctorCheck(name: "notaryProfile", ok: ok,
                detail: ok ? "notary profile '\(profile)' is configured"
                            : "notary profile '\(profile)' not found — run `lutin notary setup`"))
        }

        return checks
    }

    // MARK: build / release

    static func build(configURL: URL, dryRun: Bool,
                      registry: Registry = Registry(),
                      registryEntryName: String? = nil,
                      onOutput: ((String) -> Void)? = nil) throws -> BuildResult {
        let config: LutinConfig
        do {
            let rawConfig = try LutinConfig.load(from: configURL)
            config = try Templates.applyDefaults(to: rawConfig)
        } catch {
            if !dryRun {
                recordBuildOutcome(
                    configURL: configURL,
                    registryEntryName: registryEntryName,
                    outcome: .failed,
                    registry: registry)
            }
            throw error
        }
        let projectDir = configURL.deletingLastPathComponent()

        if dryRun {
            let appURL = URL(fileURLWithPath: config.app.path, relativeTo: projectDir)
            let info = try InfoPlistReader.read(appBundle: appURL)
            let context = TokenResolver.Context(version: info.shortVersion,
                                                name: config.project.name)
            let layout = try LayoutResolver.resolve(config: config,
                                                    appFileName: appURL.lastPathComponent)
            let outURL = URL(fileURLWithPath: config.output.directory,
                             relativeTo: projectDir)
            let request = BuildRequest(
                appBundle: appURL.standardizedFileURL,
                outputDirectory: outURL.standardizedFileURL,
                dmgName: TokenResolver.resolve(config.output.dmgName, context),
                volumeName: TokenResolver.resolve(config.output.volumeName, context),
                layout: layout,
                backgroundImage: ReleasePipeline.resolveBackground(
                    config: config, projectDirectory: projectDir),
                volumeIcon: ReleasePipeline.resolveVolumeIcon(
                    projectDirectory: projectDir))
            return try DMGBuilder.build(request, dryRun: true)
        }

        do {
            let result = try ReleasePipeline.run(
                config: config, projectDirectory: projectDir,
                mode: .build, runner: ShellCommandRunner(),
                onOutput: onOutput)
            recordBuildOutcome(
                configURL: configURL,
                registryEntryName: registryEntryName,
                outcome: .unsigned,
                registry: registry)
            return BuildResult(
                dryRun: false, plannedSteps: result.plannedSteps,
                dmgPath: result.dmgPath,
                sizeBytes: result.summary.dmgSizeBytes,
                sha256: result.summary.sha256)
        } catch {
            recordBuildOutcome(
                configURL: configURL,
                registryEntryName: registryEntryName,
                outcome: .failed,
                registry: registry)
            throw error
        }
    }

    static func release(configURL: URL,
                        registry: Registry = Registry(),
                        registryEntryName: String? = nil) throws -> ReleaseSummary {
        let config: LutinConfig
        do {
            let rawConfig = try LutinConfig.load(from: configURL)
            config = try Templates.applyDefaults(to: rawConfig)
        } catch {
            recordBuildOutcome(
                configURL: configURL,
                registryEntryName: registryEntryName,
                outcome: .failed,
                registry: registry)
            throw error
        }
        let projectDir = configURL.deletingLastPathComponent()
        do {
            let result = try ReleasePipeline.run(
                config: config, projectDirectory: projectDir,
                mode: .release, runner: ShellCommandRunner())
            let outcome: BuildOutcome = result.summary.signingStatus == "signed"
                ? .succeeded
                : .unsigned
            recordBuildOutcome(
                configURL: configURL,
                registryEntryName: registryEntryName,
                outcome: outcome,
                registry: registry)
            return result.summary
        } catch {
            recordBuildOutcome(
                configURL: configURL,
                registryEntryName: registryEntryName,
                outcome: .failed,
                registry: registry)
            throw error
        }
    }

    private static func recordBuildOutcome(configURL: URL,
                                           registryEntryName: String?,
                                           outcome: BuildOutcome,
                                           registry: Registry) {
        let standardizedConfigPath = configURL.standardizedFileURL.path
        let entries = (try? registry.allEntries().filter {
            URL(fileURLWithPath: $0.configPath).standardizedFileURL.path == standardizedConfigPath
        }) ?? []
        let targets: [RegistryEntry]
        if let registryEntryName {
            targets = entries.filter { $0.name == registryEntryName }
        } else {
            targets = entries
        }

        for entry in targets {
            var updated = entry
            updated.lastBuildOutcome = outcome
            try? registry.upsert(updated)
        }
    }

    struct PreviewResult: Encodable {
        let dmgPath: String
        let mountPath: String
        let dryRun: Bool
    }

    /// Builds the DMG (no signing/notarization), mounts it, and opens it in
    /// Finder for a human visual check. The volume is left mounted on purpose.
    static func preview(configURL: URL,
                        opener: CommandRunning = ShellCommandRunner()) throws -> PreviewResult {
        let rawConfig = try LutinConfig.load(from: configURL)
        let config = try Templates.applyDefaults(to: rawConfig)
        let projectDir = configURL.deletingLastPathComponent()

        let result = try ReleasePipeline.run(
            config: config, projectDirectory: projectDir,
            mode: .preview, runner: ShellCommandRunner())

        // Detach a stale preview of the same volume, if any, then mount fresh.
        let volume = "/Volumes/" + TokenResolver.resolve(config.output.volumeName,
            TokenResolver.Context(version: "", name: config.project.name))
        _ = try? opener.runAllowingFailure("/usr/bin/hdiutil", ["detach", volume, "-force"])

        let mount = try DiskImage.mount(result.dmgPath, runner: ShellCommandRunner())
        _ = try? opener.runAllowingFailure("/usr/bin/open", [mount.mountPoint.path])
        return PreviewResult(dmgPath: result.dmgPath.path,
                             mountPath: mount.mountPoint.path, dryRun: false)
    }

    // MARK: notary

    /// Builds the `xcrun` arguments for `notarytool store-credentials`.
    /// Any flag left nil is omitted; pass all flags for non-interactive use.
    static func notarySetupArguments(profile: String, appleID: String?,
                                     teamID: String?, password: String?) -> [String] {
        var args = ["notarytool", "store-credentials", profile]
        if let appleID { args += ["--apple-id", appleID] }
        if let teamID { args += ["--team-id", teamID] }
        if let password { args += ["--password", password] }
        return args
    }

    // MARK: stubs

    static func notImplemented(verb: String) throws -> Never {
        throw LutinError(
            code: "not_implemented",
            message: "`lutin \(verb)` is not available yet — it ships in a later sub-project.",
            details: ["verb": verb])
    }
}

// MARK: - CLI commands

/// Resolves the target config URL from common options, using the registry.
private func resolveConfigURL(config: String?,
                              name: String?,
                              registry: Registry = Registry()) throws -> URL {
    return try ProjectResolver.resolve(
        explicitConfig: config,
        projectName: name,
        currentDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        registryLookup: { projectName in
            try registry.find(name: projectName)
                .map { URL(fileURLWithPath: $0.configPath) }
        })
}

public struct Lutin: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "lutin",
        abstract: "Design, build, and release beautiful DMGs for macOS apps.",
        subcommands: [Init.self, Projects.self, Add.self, Remove.self, Open.self,
                      Validate.self, Doctor.self, Build.self, Release.self, Preview.self,
                      Notary.self, ApplyIntents.self])
    public init() {}
}

struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Create a new lutin.yml.")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Path to the .app bundle.") var app: String?
    @Option(name: .long, help: "Template name.") var template: String = Templates.defaultTemplateName

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let result = try CommandLogic.initProject(
                directory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                appPath: app, template: template, registry: Registry(), dryRun: common.dryRun)
            renderer.success(result, human: result.dryRun
                ? "Would create \(result.configPath) for \(result.projectName)."
                : "Created \(result.configPath) for \(result.projectName).")
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct Projects: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List remembered projects.")
    @OptionGroup var common: CommonOptions

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let items = try CommandLogic.listProjects(registry: Registry())
            let human = items.isEmpty
                ? "No projects registered. Run `lutin init`."
                : items.map { "\($0.name)  [\($0.status)]  \($0.configPath)" }.joined(separator: "\n")
            renderer.success(items, human: human)
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Register an existing lutin.yml.")
    @OptionGroup var common: CommonOptions
    @Argument(help: "Path to a lutin.yml file.") var path: String
    @Option(name: .long, help: "Register under a different name.") var name: String?

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let result = try CommandLogic.addProject(
                configPath: path, overrideName: name, registry: Registry(),
                dryRun: common.dryRun)
            renderer.success(result, human: common.dryRun
                ? "Would register \(result.name)."
                : "Registered \(result.name).")
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct Remove: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Forget a project.")
    @OptionGroup var common: CommonOptions
    @Argument(help: "Project name.") var name: String

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            try CommandLogic.removeProject(name: name, registry: Registry(),
                                           dryRun: common.dryRun)
            renderer.success(EmptyPayload(), human: common.dryRun
                ? "Would remove \(name)."
                : "Removed \(name).")
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct Open: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show a project's location.")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Project name.") var name: String

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let result = try CommandLogic.openProject(name: name, registry: Registry())
            renderer.success(result, human: result.configPath)
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Validate a project's lutin.yml.")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Path to lutin.yml.") var config: String?
    @Option(name: .long, help: "Project name.") var name: String?

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let url = try resolveConfigURL(config: config, name: name)
            let issues = try CommandLogic.validateConfig(configURL: url)
            let errors = issues.filter { $0.severity == .error }
            let human = issues.isEmpty
                ? "lutin.yml is valid."
                : issues.map { "[\($0.severity.rawValue)] \($0.path): \($0.message)" }
                        .joined(separator: "\n")
            renderer.success(issues, human: human)
            if !errors.isEmpty { throw ExitCode(1) }
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Check a project's release readiness.")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Path to lutin.yml.") var config: String?
    @Option(name: .long, help: "Project name.") var name: String?

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let url = try resolveConfigURL(config: config, name: name)
            let checks = try CommandLogic.doctor(configURL: url)
            let human = checks.map { "\($0.ok ? "✓" : "✗") \($0.name): \($0.detail)" }
                              .joined(separator: "\n")
            renderer.success(checks, human: human)
            if checks.contains(where: { !$0.ok }) { throw ExitCode(1) }
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct Build: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Build a DMG (unsigned).")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Path to lutin.yml.") var config: String?
    @Option(name: .long, help: "Project name.") var name: String?

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        let registry = Registry()
        do {
            let url = try resolveConfigURL(config: config, name: name, registry: registry)
            let result = try CommandLogic.build(
                configURL: url, dryRun: common.dryRun,
                registry: registry,
                registryEntryName: name,
                onOutput: { renderer.verboseLine($0) })
            let human: String
            if result.dryRun {
                human = "Dry run — planned steps:\n"
                      + result.plannedSteps.map { "  • \($0)" }.joined(separator: "\n")
            } else {
                human = "Built \(result.dmgPath?.path ?? "")\n"
                      + "  size: \(result.sizeBytes ?? 0) bytes\n"
                      + "  sha256: \(result.sha256 ?? "")"
            }
            renderer.success(result, human: human)
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct Release: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Build, sign, notarize, and staple a DMG.")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Path to lutin.yml.") var config: String?
    @Option(name: .long, help: "Project name.") var name: String?

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        let registry = Registry()
        do {
            let url = try resolveConfigURL(config: config, name: name, registry: registry)
            if common.dryRun {
                renderer.success(EmptyPayload(),
                                 human: "Dry run — `release` would build, sign, "
                                      + "notarize, and staple the DMG.")
                return
            }
            let summary = try CommandLogic.release(configURL: url,
                                                   registry: registry,
                                                   registryEntryName: name)
            let human = "Released \(summary.dmgPath)\n"
                      + "  version: \(summary.version)  size: \(summary.dmgSizeBytes) bytes\n"
                      + "  signing: \(summary.signingStatus)  "
                      + "notarization: \(summary.notarizationStatus)"
            renderer.success(summary, human: human)
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct Preview: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Build the DMG and open it in Finder for a visual check.")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Path to lutin.yml.") var config: String?
    @Option(name: .long, help: "Project name.") var name: String?

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let url = try resolveConfigURL(config: config, name: name)
            if common.dryRun {
                renderer.success(EmptyPayload(),
                                 human: "Dry run — `preview` would build, mount, "
                                      + "and open the DMG in Finder.")
                return
            }
            let result = try CommandLogic.preview(configURL: url)
            renderer.success(result,
                             human: "Preview mounted at \(result.mountPath)\n"
                                  + "  DMG: \(result.dmgPath)")
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct Notary: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "notary",
        abstract: "Manage the Apple notary profile.",
        subcommands: [NotarySetup.self])
}

struct NotarySetup: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setup",
        abstract: "Store Apple notary credentials in the Keychain. Pass --apple-id/--team-id/--password for non-interactive use.")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Profile name to create.") var profile: String = "lutin-notary"
    @Option(name: .long, help: "Apple ID email.") var appleID: String?
    @Option(name: .long, help: "Apple Developer Team ID.") var teamID: String?
    @Option(name: .long, help: "App-specific password.") var password: String?

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        let args = CommandLogic.notarySetupArguments(
            profile: profile, appleID: appleID, teamID: teamID, password: password)
        if common.dryRun {
            renderer.success(EmptyPayload(),
                             human: "Dry run — would run: xcrun \(args.joined(separator: " "))")
            return
        }
        do {
            // Shell captures stdio via pipes; pass all flags for non-interactive use.
            _ = try Shell.run("/usr/bin/xcrun", args)
            renderer.success(EmptyPayload(),
                             human: "Notary profile '\(profile)' stored in the Keychain.")
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

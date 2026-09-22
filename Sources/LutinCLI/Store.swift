import Foundation
import ArgumentParser
import LutinCore
import LutinConfig
import LutinStoreConnect
import LutinStoreMetadata

// MARK: - CLI surface

struct Store: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "store",
        abstract: "App Store Connect listing: validate, plan, approve, and apply metadata.",
        subcommands: [StoreStatus.self, StoreValidate.self, StorePlan.self,
                      StoreApprove.self, StoreApply.self, StorePull.self])
}

struct StoreStatus: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show the store connection: asc, credentials, web session, and metadata.")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Path to lutin.yml.") var config: String?
    @Option(name: .long, help: "Project name.") var name: String?

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let url = try resolveConfigURL(config: config, name: name)
            let payload = try StoreLogic.status(configURL: url, runner: ShellCommandRunner())
            var lines = ["asc \(payload.ascVersion)"]
            lines.append("authenticated: \(payload.authenticated ? "yes" : "no")")
            lines.append("web session: \(payload.hasWebSession ? "yes" : "no")")
            lines.append("app: \(payload.appID ?? "not set — asc resolves it")")
            lines.append("metadata files: \(payload.fileCount)")
            renderer.success(payload, human: lines.joined(separator: "\n"))
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct StoreValidate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate the canonical metadata tree (offline when asc is not installed).")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Path to lutin.yml.") var config: String?
    @Option(name: .long, help: "Project name.") var name: String?

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let url = try resolveConfigURL(config: config, name: name)
            let report = try StoreLogic.validate(configURL: url, runner: ShellCommandRunner())
            var human: String
            if report.issues.isEmpty {
                human = "Metadata is valid (\(report.fileCount) file(s))."
                if report.offline {
                    human += " Offline check — asc not installed."
                }
            } else {
                human = report.issues
                    .map { "[\($0.severity)] \($0.file ?? ""): \($0.message)" }
                    .joined(separator: "\n")
            }
            renderer.success(report, human: human)
            if report.errorCount > 0 { throw ExitCode(1) }
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct StorePlan: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "plan",
        abstract: "Plan metadata changes and write the review artifact.")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Path to lutin.yml.") var config: String?
    @Option(name: .long, help: "Project name.") var name: String?
    @Option(name: .long, help: "Directory for metadata review artifacts (default: .asc/metadata/review).") var reviewDir: String?

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let url = try resolveConfigURL(config: config, name: name)
            let result = try StoreLogic.plan(configURL: url, reviewDir: reviewDir,
                                             runner: ShellCommandRunner())
            renderer.success(result, human: result.output)
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct StoreApprove: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "approve",
        abstract: "Approve a metadata review plan (exactly one of --all, --key, --scope).")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Path to lutin.yml.") var config: String?
    @Option(name: .long, help: "Project name.") var name: String?
    @Option(name: .long, help: "Directory for metadata review artifacts (default: .asc/metadata/review).") var reviewDir: String?
    @Flag(name: .long, help: "Approve every planned metadata change.") var all = false
    @Option(name: .long, help: "Approve specific plan key(s) (repeatable; comma-separated for asc).") var keys: [String] = []
    @Option(name: .long, help: "Approve all changes in a scope: app-info | version.") var scope: String?
    @Option(name: .long, help: "Optional reviewer note written to approved.json.") var note: String?

    /// Exactly-one enforcement is a usage error, so it lives here rather than
    /// as a new stable `store_*` code.
    func validate() throws {
        let provided = (all ? 1 : 0) + (keys.isEmpty ? 0 : 1) + (scope == nil ? 0 : 1)
        guard provided == 1 else {
            throw ValidationError("Pass exactly one of --all, --key, or --scope.")
        }
    }

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let url = try resolveConfigURL(config: config, name: name)
            let result = try StoreLogic.approve(
                configURL: url, reviewDir: reviewDir, all: all, keys: keys,
                scope: scope, note: note, runner: ShellCommandRunner())
            renderer.success(result, human: result.output)
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct StoreApply: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apply",
        abstract: "Apply metadata changes to App Store Connect (the only remote writer).")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Path to lutin.yml.") var config: String?
    @Option(name: .long, help: "Project name.") var name: String?
    @Option(name: .long, help: "Directory for metadata review artifacts (default: .asc/metadata/review).") var reviewDir: String?
    @Flag(name: .long, help: "Confirm the live mutation.") var confirm = false

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let url = try resolveConfigURL(config: config, name: name)
            let result = try StoreLogic.apply(
                configURL: url, reviewDir: reviewDir, confirmed: confirm,
                runner: ShellCommandRunner())
            renderer.success(result, human: result.output)
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct StorePull: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pull",
        abstract: "Pull App Store Connect metadata into the canonical tree.")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Path to lutin.yml.") var config: String?
    @Option(name: .long, help: "Project name.") var name: String?
    @Option(name: .long, help: "App version string (for example 1.2.3).") var version: String?
    @Flag(name: .long, help: "Overwrite existing local metadata files.") var force = false

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let url = try resolveConfigURL(config: config, name: name)
            let result = try StoreLogic.pull(
                configURL: url, version: version, force: force,
                runner: ShellCommandRunner())
            renderer.success(result, human: result.output)
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

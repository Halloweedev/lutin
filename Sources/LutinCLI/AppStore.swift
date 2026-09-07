import Foundation
import ArgumentParser
import LutinCore

// MARK: - App Store Connect via `asc`

/// Thin, JSON-enveloped wrapper around the `asc` App Store Connect CLI
/// (`brew install asc`). `asc` handles the App Store channel — build uploads
/// (IPA/PKG), TestFlight, and submission — which is outside Lutin's DMG
/// pipeline. Lutin never vendors `asc`: it resolves the binary (explicit
/// `--asc-path`, well-known Homebrew locations, then `which`), shells out
/// with `--output json`, and maps failures to stable `app_store_*` codes.
///
/// Artifact note: App Store Connect accepts macOS uploads as **PKG**, not
/// DMG. `lutin app-store upload` therefore takes `--pkg` (macOS) or `--ipa`
/// (iOS/tvOS/visionOS) — never a Lutin-built DMG.
enum AppStoreLogic {
    /// Well-known Homebrew install locations, checked before PATH lookup.
    /// `which` alone can miss brew when the caller's PATH is sparse.
    static let knownPaths = ["/opt/homebrew/bin/asc", "/usr/local/bin/asc"]

    enum ArtifactKind {
        case pkg, ipa

        var flag: String {
            switch self {
            case .pkg: return "--pkg"
            case .ipa: return "--ipa"
            }
        }
    }

    struct UploadResult: Encodable {
        let artifactPath: String
        let app: String
        let command: String
        let output: String
        let dryRun: Bool
    }

    struct StatusResult: Encodable {
        let app: String
        let command: String
        let output: String
        let dryRun: Bool
    }

    /// Resolves the `asc` binary. Explicit path wins, then the known Homebrew
    /// locations, then `which asc`. Throws `app_store_tool_missing` with an
    /// install hint when nothing resolves.
    static func resolveAscPath(explicit: String?,
                               runner: CommandRunning = ShellCommandRunner()) throws -> String {
        try resolveAscPath(explicit: explicit, runner: runner,
                           isExecutable: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    /// Injectable-filesystem variant for unit tests (`@testable import`).
    static func resolveAscPath(explicit: String?, runner: CommandRunning,
                               isExecutable: (String) -> Bool) throws -> String {
        if let explicit, !explicit.isEmpty {
            guard isExecutable(explicit) else {
                throw LutinError(
                    code: "app_store_tool_missing",
                    message: "No executable `asc` at \(explicit). "
                           + "Install with `brew install asc`.",
                    details: ["ascPath": explicit])
            }
            return explicit
        }
        if let found = knownPaths.first(where: isExecutable) {
            return found
        }
        let result = try? runner.runAllowingFailure("/usr/bin/which", ["asc"])
        if let path = result?.stdout
            .trimmingCharacters(in: .whitespacesAndNewlines),
            result?.exitCode == 0, !path.isEmpty,
            isExecutable(path) {
            return path
        }
        throw LutinError(
            code: "app_store_tool_missing",
            message: "The `asc` App Store Connect CLI was not found. "
                   + "Install with `brew install asc`, or pass --asc-path.",
            details: nil)
    }

    /// Builds the `asc builds upload` argument list (pure — also used for
    /// `--dry-run` previews and unit tests).
    static func uploadArguments(artifact: String, kind: ArtifactKind, app: String,
                                version: String?, buildNumber: String?,
                                wait: Bool) -> [String] {
        var args = ["builds", "upload", "--app", app, kind.flag, artifact,
                    "--output", "json"]
        if let version { args += ["--version", version] }
        if let buildNumber { args += ["--build-number", buildNumber] }
        if wait { args.append("--wait") }
        return args
    }

    /// Uploads a PKG/IPA via `asc builds upload`. The artifact must exist;
    /// `asc` itself extracts version/build defaults when the flags are omitted.
    static func upload(artifact: String, kind: ArtifactKind, app: String,
                       version: String?, buildNumber: String?, wait: Bool,
                       ascPath: String?, dryRun: Bool,
                       runner: CommandRunning = ShellCommandRunner()) throws -> UploadResult {
        guard FileManager.default.fileExists(atPath: artifact) else {
            throw LutinError(
                code: "app_store_artifact_missing",
                message: "Artifact not found at \(artifact). "
                       + "macOS uploads use --pkg; iOS/tvOS/visionOS use --ipa.",
                details: ["artifact": artifact])
        }
        let asc = try resolveAscPath(explicit: ascPath, runner: runner)
        let args = uploadArguments(artifact: artifact, kind: kind, app: app,
                                   version: version, buildNumber: buildNumber,
                                   wait: wait)
        let rendered = ([asc] + args).joined(separator: " ")
        if dryRun {
            return UploadResult(artifactPath: artifact, app: app,
                                command: rendered,
                                output: "Would run: \(rendered)", dryRun: true)
        }
        let result = try runner.runAllowingFailure(asc, args)
        guard result.exitCode == 0 else {
            throw appStoreFailure(code: "app_store_upload_failed",
                                  verb: "upload",
                                  result: result, app: app)
        }
        return UploadResult(artifactPath: artifact, app: app,
                            command: rendered, output: result.stdout,
                            dryRun: false)
    }

    /// Builds the `asc status` argument list (pure).
    static func statusArguments(app: String, platform: String?) -> [String] {
        var args = ["status", "--app", app, "--output", "json"]
        if let platform { args += ["--platform", platform] }
        return args
    }

    /// Shows the App Store release dashboard for an app via `asc status`.
    /// Read-only — safe to run any time.
    static func status(app: String, platform: String?,
                       ascPath: String?, dryRun: Bool,
                       runner: CommandRunning = ShellCommandRunner()) throws -> StatusResult {
        let asc = try resolveAscPath(explicit: ascPath, runner: runner)
        let args = statusArguments(app: app, platform: platform)
        let rendered = ([asc] + args).joined(separator: " ")
        if dryRun {
            return StatusResult(app: app, command: rendered,
                                output: "Would run: \(rendered)", dryRun: true)
        }
        let result = try runner.runAllowingFailure(asc, args)
        guard result.exitCode == 0 else {
            throw appStoreFailure(code: "app_store_status_failed",
                                  verb: "status check",
                                  result: result, app: app)
        }
        return StatusResult(app: app, command: rendered,
                            output: result.stdout, dryRun: false)
    }

    /// Describes `asc` availability for `lutin doctor`. Informational only —
    /// always `ok: true` so a missing optional tool can never fail release
    /// readiness. Auth problems surface at command time with fix hints.
    static func doctorDetail(runner: CommandRunning = ShellCommandRunner()) -> String {
        doctorDetail(runner: runner,
                     isExecutable: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    /// Injectable-filesystem variant for unit tests.
    static func doctorDetail(runner: CommandRunning,
                             isExecutable: (String) -> Bool) -> String {
        guard let asc = try? resolveAscPath(explicit: nil, runner: runner,
                                            isExecutable: isExecutable) else {
            return "asc not found — `brew install asc` to enable `lutin app-store` (optional)"
        }
        let version = try? runner.runAllowingFailure(asc, ["--version"])
        if let line = version?.stdout
            .trimmingCharacters(in: .whitespacesAndNewlines),
            version?.exitCode == 0, !line.isEmpty {
            return "asc \(line) available — `lutin app-store` ready"
        }
        return "asc available — `lutin app-store` ready"
    }

    // MARK: - Failure mapping

    /// Maps a non-zero `asc` result to a stable error. Output mentioning
    /// auth/credentials becomes `app_store_auth_failed` (fix: `asc auth login`
    /// or env credentials) regardless of the calling verb.
    static func appStoreFailure(code: String, verb: String,
                                result: ShellResult, app: String) -> LutinError {
        let combined = (result.stdout + "\n" + result.stderr).lowercased()
        let looksLikeAuth = ["auth", "credential", "unauthorized",
                             "401", "api key", "issuer"].contains { combined.contains($0) }
        if looksLikeAuth {
            return LutinError(
                code: "app_store_auth_failed",
                message: "App Store \(verb) for '\(app)' failed: `asc` is not "
                       + "authenticated. Run `asc auth login` (or set ASC_* "
                       + "env credentials) and retry.",
                details: ["app": app, "stderr": result.stderr])
        }
        return LutinError(
            code: code,
            message: "App Store \(verb) for '\(app)' failed: \(result.stderr)",
            details: ["app": app, "stderr": result.stderr])
    }
}

// MARK: - CLI surface

/// Resolves `--app`, falling back to `ASC_APP_ID` (which `asc` itself honors).
/// Throws `app_store_missing_app` when neither is set.
func resolveAppStoreApp(_ flag: String?) throws -> String {
    if let flag, !flag.isEmpty { return flag }
    if let env = ProcessInfo.processInfo.environment["ASC_APP_ID"],
       !env.isEmpty { return env }
    throw LutinError(
        code: "app_store_missing_app",
        message: "No app given. Pass --app <Connect ID | bundle ID | name> "
               + "or set ASC_APP_ID.",
        details: nil)
}

struct AppStore: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app-store",
        abstract: "App Store Connect via `asc` — upload builds and check release status.",
        subcommands: [AppStoreUpload.self, AppStoreStatus.self])
}

struct AppStoreUpload: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "upload",
        abstract: "Upload a PKG (macOS) or IPA (iOS/tvOS/visionOS) to App Store Connect. DMGs are not accepted — build a PKG for the Mac App Store.")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "Path to a .pkg (macOS). Exactly one of --pkg/--ipa.") var pkg: String?
    @Option(name: .long, help: "Path to an .ipa (iOS/tvOS/visionOS). Exactly one of --pkg/--ipa.") var ipa: String?
    @Option(name: .long, help: "App Store Connect app ID, bundle ID, or exact name (or ASC_APP_ID).") var app: String?
    @Option(name: .long, help: "CFBundleShortVersionString (default: extracted from the artifact).") var version: String?
    @Option(name: .long, help: "CFBundleVersion (default: extracted from the artifact).") var buildNumber: String?
    @Flag(name: .long, help: "Wait for build processing to complete.") var wait = false
    @Option(name: .long, help: "Path to the asc binary (default: auto-detect).") var ascPath: String?

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let (artifact, kind): (String, AppStoreLogic.ArtifactKind) = try {
                switch (pkg, ipa) {
                case let (p?, nil) where !p.isEmpty: return (p, .pkg)
                case let (nil, i?) where !i.isEmpty: return (i, .ipa)
                case (nil, nil):
                    throw LutinError(
                        code: "app_store_artifact_missing",
                        message: "Pass --pkg <path> (macOS) or --ipa <path> "
                               + "(iOS/tvOS/visionOS).",
                        details: nil)
                default:
                    throw LutinError(
                        code: "app_store_artifact_missing",
                        message: "Pass exactly one of --pkg or --ipa.",
                        details: nil)
                }
            }()
            let appID = try resolveAppStoreApp(app)
            let result = try AppStoreLogic.upload(
                artifact: artifact, kind: kind, app: appID,
                version: version, buildNumber: buildNumber, wait: wait,
                ascPath: ascPath, dryRun: common.dryRun)
            renderer.success(result, human: result.dryRun
                ? result.output
                : "Uploaded \(result.artifactPath) for \(result.app).")
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

struct AppStoreStatus: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show the App Store release dashboard for an app (read-only).")
    @OptionGroup var common: CommonOptions
    @Option(name: .long, help: "App Store Connect app ID, bundle ID, or exact name (or ASC_APP_ID).") var app: String?
    @Option(name: .long, help: "Filter by platform: IOS, MAC_OS, TV_OS, VISION_OS.") var platform: String?
    @Option(name: .long, help: "Path to the asc binary (default: auto-detect).") var ascPath: String?

    func run() throws {
        let renderer = OutputRenderer(json: common.json, verbose: common.verbose)
        do {
            let appID = try resolveAppStoreApp(app)
            let result = try AppStoreLogic.status(
                app: appID, platform: platform,
                ascPath: ascPath, dryRun: common.dryRun)
            renderer.success(result, human: result.dryRun
                ? result.output
                : result.output)
        } catch let error as LutinError {
            renderer.failure(error); throw ExitCode(1)
        }
    }
}

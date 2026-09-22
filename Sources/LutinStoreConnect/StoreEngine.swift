import Foundation
import LutinCore
import LutinConfig
import LutinStoreMetadata

// MARK: - App Store Connect listing via `asc metadata`

/// The engine behind `lutin store` — status, validate, plan, approve, apply,
/// and pull — plus the payloads those operations return.
///
/// It lives in `LutinStoreConnect` rather than `LutinCLI` because two
/// presenters run the same operations: the CLI's `ParsableCommand` structs and
/// (later) the GUI's Store tab. The GUI cannot depend on `LutinCLI`, so keeping
/// the engine low and shared is what lets both call one implementation instead
/// of two. The argv building, the capability gating, and the confirmation and
/// overwrite guards are exactly the parts that must never drift between the
/// two surfaces, so they are the parts that get a single home here.
///
/// Lutin renders asc's plan rather than computing its own: this type shells
/// out to `asc metadata …` and maps its output and failures into Lutin's
/// stable `store_*` codes. The only path that never touches asc is
/// `validateOffline`.
///
/// The `lutin store` surface: validate, plan, approve, apply, and pull App
/// Store Connect metadata through `asc metadata …`.
///
/// Two paths never touch `asc`: `validateOffline` — the whole reason
/// `LutinStoreMetadata` is a separate module, so CI can validate a listing on
/// a machine with no asc and no network — and `validate`'s fallback to it when
/// asc is not installed. Every other command resolves asc, gates on the
/// capabilities asc reports, and maps failures to stable unprefixed `store_*`
/// codes.
public enum StoreLogic {

    // MARK: - Payloads

    public struct StoreStatusPayload: Encodable {
        public let ascVersion: String
        public let authenticated: Bool
        public let hasWebSession: Bool
        public let appID: String?
        public let fileCount: Int
        public let storageBackend: String
        public let credential: String?
        public let environmentCredentials: Bool
        public let capabilitiesByStatus: [String: Int]
    }

    public struct StoreValidateReport: Encodable {
        public let fileCount: Int
        public let issues: [StoreMetadataIssue]
        public let offline: Bool
        public let errorCount: Int
        public let warningCount: Int
        public let valid: Bool

        public init(fileCount: Int, issues: [StoreMetadataIssue], offline: Bool,
                    errorCount: Int, warningCount: Int, valid: Bool) {
            self.fileCount = fileCount
            self.issues = issues
            self.offline = offline
            self.errorCount = errorCount
            self.warningCount = warningCount
            self.valid = valid
        }
    }

    public struct StoreCommandResult: Encodable {
        public let app: String?
        public let command: String
        public let output: String
    }

    private struct ASCValidateOutput: Decodable {
        let filesScanned: Int
        let issues: [StoreMetadataIssue]
        let errorCount: Int
        let warningCount: Int
        let valid: Bool
    }

    // MARK: - Offline validation (no asc, no network)

    /// Enumerates and decodes the canonical metadata tree without ever
    /// touching asc. Decoding is strict — an unknown key throws
    /// `store_metadata_schema` exactly as asc would on push. Structural
    /// stray-directory findings populate `issues`, and an empty tree is an
    /// error (spec §3.4), not a clean bill of health.
    public static func validateOffline(configURL: URL,
                                       runner: CommandRunning) throws -> StoreValidateReport {
        let config = try LutinConfig.load(from: configURL)
        let dir = try metadataDirectory(for: config, configURL: configURL)
        let storeDir = StoreMetadataDirectory(root: dir)

        // `default.json` fallback files are deliberately NOT decoded here:
        // the locale enumeration excludes them, so an unknown key in a
        // fallback file is only caught by the asc-backed path. The offline
        // subset validates what asc would push per locale; the fallback is
        // asc's own merge input.
        for locale in try storeDir.appInfoLocales() {
            _ = try storeDir.localization(scope: .appInfo, locale: locale, version: nil)
        }
        for version in try storeDir.versionDirectories() {
            for locale in try storeDir.versionLocales(version: version) {
                _ = try storeDir.localization(scope: .version, locale: locale, version: version)
            }
        }

        var issues: [StoreMetadataIssue] = []
        for stray in (try? storeDir.strayDirectories()) ?? [] {
            issues.append(.strayPath(stray))
        }

        let fileCount = try storeDir.enumeratedFileCount()
        if fileCount == 0 {
            issues.append(.emptyTree(dir.path))
        }

        return StoreValidateReport(
            fileCount: fileCount,
            issues: issues,
            offline: true,
            errorCount: issues.count,
            warningCount: 0,
            valid: issues.isEmpty)
    }

    // MARK: - Status

    public static func status(configURL: URL,
                              runner: CommandRunning,
                              isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) throws -> StoreStatusPayload {
        let config = try LutinConfig.load(from: configURL)
        let dir = try metadataDirectory(for: config, configURL: configURL)
        let fileCount = try StoreMetadataDirectory(root: dir).enumeratedFileCount()

        let asc = try resolveAsc(for: config, runner: runner, isExecutable: isExecutable)

        let versionResult = try runner.runAllowingFailure(asc, ["--version"])
        guard versionResult.exitCode == 0 else {
            throw ASCErrorMapping.map(result: versionResult, command: ["--version"],
                                      fallbackCode: "store_asc_failed")
        }
        try ASCToolVersion.assertSupported(versionResult.stdout)
        let version = ASCToolVersion(versionResult.stdout)?.description
            ?? versionResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        let auth = try ASCAuthState.load(ascPath: asc, runner: runner)
        let capabilities = try ASCCapabilities.load(ascPath: asc, runner: runner)
        // Best-effort: an asc build without `web auth status` must not break
        // an informational command. The throwing path (`assertAvailable`) runs
        // as capability gating on the mutating commands.
        let web = try? ASCWebSessionState.load(ascPath: asc, runner: runner)

        var byStatus: [String: Int] = [:]
        for capability in capabilities.capabilities {
            byStatus[capability.status.rawValue, default: 0] += 1
        }

        return StoreStatusPayload(
            ascVersion: version,
            authenticated: auth.hasUsableCredential,
            hasWebSession: web?.isAvailable ?? false,
            appID: config.store?.appID,
            fileCount: fileCount,
            storageBackend: auth.storageBackend,
            credential: auth.defaultCredential?.name,
            environmentCredentials: auth.environmentCredentialsProvided,
            capabilitiesByStatus: byStatus)
    }

    // MARK: - Validate

    /// Renders asc's findings when asc is present; runs the in-process subset
    /// when it is not (spec §5). The asc path cross-checks asc's `filesScanned`
    /// against Lutin's own enumeration via `StoreMetadataGuard`.
    public static func validate(configURL: URL,
                                runner: CommandRunning,
                                isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) throws -> StoreValidateReport {
        let config = try LutinConfig.load(from: configURL)
        let dir = try metadataDirectory(for: config, configURL: configURL)

        let asc: String
        do {
            asc = try resolveAsc(for: config, runner: runner, isExecutable: isExecutable)
        } catch let error as LutinError where error.code == "store_asc_missing" {
            return try validateOffline(configURL: configURL, runner: runner)
        }

        let client = ASCClient(ascPath: asc, runner: runner)
        try gate(ascPath: asc, runner: runner, command: "metadata validate")

        let (stdout, _) = try client.runAllowingValidationFailure(
            ["metadata", "validate", "--dir", dir.path])
        let findings: ASCValidateOutput
        do {
            findings = try JSONDecoder().decode(ASCValidateOutput.self, from: Data(stdout.utf8))
        } catch {
            throw LutinError(
                code: "store_asc_failed",
                message: "Could not decode `asc metadata validate` output: \(error)",
                details: ["ascCommand": "asc metadata validate --dir \(dir.path)"])
        }
        try StoreMetadataGuard.assertConsistent(
            ascScanned: findings.filesScanned, local: StoreMetadataDirectory(root: dir))

        return StoreValidateReport(
            fileCount: findings.filesScanned,
            issues: findings.issues,
            offline: false,
            errorCount: findings.errorCount,
            warningCount: findings.warningCount,
            valid: findings.valid)
    }

    // MARK: - plan / approve / apply / pull

    public static func plan(configURL: URL, reviewDir: String?,
                            runner: CommandRunning,
                            isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) throws -> StoreCommandResult {
        let config = try LutinConfig.load(from: configURL)
        let dir = try metadataDirectory(for: config, configURL: configURL)
        let asc = try resolveAsc(for: config, runner: runner, isExecutable: isExecutable)
        let client = ASCClient(ascPath: asc, runner: runner)
        try gate(ascPath: asc, runner: runner, command: "metadata plan")

        var arguments = ["metadata", "plan"] + appArguments(for: config.store)
        // `--version` only when the tree names exactly one version; otherwise
        // asc resolves the active editable version (spec §395).
        let versions = try StoreMetadataDirectory(root: dir).versionDirectories()
        if versions.count == 1 {
            arguments += ["--version", versions[0]]
        }
        arguments += ["--platform", platform(for: config.store),
                      "--dir", dir.path,
                      "--review-dir", reviewPath(for: reviewDir, configURL: configURL)]
        let output = try runMapped(client, arguments, resolvingApp: config.store?.appID)
        return StoreCommandResult(app: config.store?.appID,
                                  command: rendered(asc, arguments), output: output)
    }

    public static func approve(configURL: URL, reviewDir: String?, all: Bool,
                               keys: [String], scope: String?, note: String?,
                               runner: CommandRunning,
                               isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) throws -> StoreCommandResult {
        let config = try LutinConfig.load(from: configURL)
        let asc = try resolveAsc(for: config, runner: runner, isExecutable: isExecutable)
        let client = ASCClient(ascPath: asc, runner: runner)
        try gate(ascPath: asc, runner: runner, command: "metadata approve")

        var arguments = ["metadata", "approve",
                         "--review-dir", reviewPath(for: reviewDir, configURL: configURL)]
        if all { arguments.append("--all") }
        if !keys.isEmpty { arguments += ["--key", keys.joined(separator: ",")] }
        if let scope, !scope.isEmpty { arguments += ["--scope", scope] }
        if let note, !note.isEmpty { arguments += ["--note", note] }
        let output = try client.run(arguments)
        return StoreCommandResult(app: nil, command: rendered(asc, arguments),
                                  output: output)
    }

    public static func apply(configURL: URL, reviewDir: String?, confirmed: Bool,
                             runner: CommandRunning,
                             isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) throws -> StoreCommandResult {
        let config = try LutinConfig.load(from: configURL)
        // The guard runs before any resolution or runner call: an unconfirmed
        // apply must not invoke asc at all.
        guard confirmed else {
            throw LutinError(
                code: "store_confirmation_required",
                message: "`lutin store apply` mutates the live App Store listing. "
                       + "Review the plan and re-run with --confirm.",
                details: nil)
        }
        let dir = try metadataDirectory(for: config, configURL: configURL)
        let asc = try resolveAsc(for: config, runner: runner, isExecutable: isExecutable)
        let client = ASCClient(ascPath: asc, runner: runner)
        try gate(ascPath: asc, runner: runner, command: "metadata apply")

        var arguments = ["metadata", "apply"] + appArguments(for: config.store)
        arguments += ["--platform", platform(for: config.store),
                      "--dir", dir.path,
                      "--review-dir", reviewPath(for: reviewDir, configURL: configURL),
                      "--confirm"]
        let output = try runMapped(client, arguments, resolvingApp: config.store?.appID)
        return StoreCommandResult(app: config.store?.appID,
                                  command: rendered(asc, arguments), output: output)
    }

    public static func pull(configURL: URL, version: String?, force: Bool,
                            runner: CommandRunning,
                            isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) throws -> StoreCommandResult {
        let config = try LutinConfig.load(from: configURL)
        let dir = try metadataDirectory(for: config, configURL: configURL)
        // Local guard first — before any resolution or runner call.
        if !force,
           ((try? StoreMetadataDirectory(root: dir).enumeratedFileCount()) ?? 0) > 0 {
            throw LutinError(
                code: "store_pull_would_overwrite",
                message: "The metadata directory already holds files that pull would "
                       + "overwrite. Re-run with --force to overwrite them, or run "
                       + "`lutin store plan` first.",
                details: ["dir": dir.path])
        }
        let asc = try resolveAsc(for: config, runner: runner, isExecutable: isExecutable)
        let client = ASCClient(ascPath: asc, runner: runner)
        try gate(ascPath: asc, runner: runner, command: "metadata pull")

        var arguments = ["metadata", "pull"] + appArguments(for: config.store)
        if let version, !version.isEmpty { arguments += ["--version", version] }
        arguments += ["--dir", dir.path, "--platform", platform(for: config.store)]
        if force { arguments.append("--force") }
        let output = try runMapped(client, arguments, resolvingApp: config.store?.appID)
        return StoreCommandResult(app: config.store?.appID,
                                  command: rendered(asc, arguments), output: output)
    }

    // MARK: - Catalog

    /// The resolved app record, when `store.appID` names it. `nil` when the app
    /// is left for asc to resolve — Lutin cannot see which app asc picks, and
    /// says so rather than guessing (§4.2).
    ///
    /// When `store.bundleID` is present it is **verified** against this record;
    /// a mismatch is an error. It is never used to resolve.
    public static func app(configURL: URL, runner: CommandRunning,
                           isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) throws -> ASCApp? {
        let config = try LutinConfig.load(from: configURL)
        guard let appID = normalized(config.store?.appID) else { return nil }
        let asc = try resolveAsc(for: config, runner: runner, isExecutable: isExecutable)
        let client = ASCClient(ascPath: asc, runner: runner)
        let app = try client.runJSON(["apps", "view", "--id", appID],
                                     as: ASCApp.self).payload
        // Blank is absent on both sides: a whitespace-only `store.bundleID` is
        // not an expectation to enforce, and a blank record value is not a
        // bundle ID to compare against. Only a real, differing pair is a
        // mismatch (§4.2). The UI derives its "verified"/"could not verify"
        // note from the same pair, so the two cannot disagree.
        if let expected = normalized(config.store?.bundleID),
           let actual = normalized(app.bundleID), expected != actual {
            throw LutinError(
                code: "store_bundle_id_mismatch",
                message: "store.bundleID is \(expected), but the resolved app "
                       + "\(appID) is \(actual).",
                details: ["expected": expected, "actual": actual, "appID": appID])
        }
        return app
    }

    // MARK: - App resolution rules

    /// Trims, and treats the empty result as absent. Public so the Store tab's
    /// App model reads "stated" exactly as the engine does — the note must not
    /// advertise a verification the engine skipped.
    public static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    /// App Store versions, newest first. Read-only (§7.3).
    public static func versions(configURL: URL, runner: CommandRunning,
                                isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) throws -> [ASCAppStoreVersion] {
        let config = try LutinConfig.load(from: configURL)
        let asc = try resolveAsc(for: config, runner: runner, isExecutable: isExecutable)
        let client = ASCClient(ascPath: asc, runner: runner)
        var arguments = ["versions", "list"] + appArguments(for: config.store)
        arguments += ["--platform", platform(for: config.store), "--paginate"]
        let list = try runMappedJSON(client, arguments,
                                     as: ASCAppStoreVersionList.self,
                                     resolvingApp: config.store?.appID).payload
        return ASCAppStoreVersion.newestFirst(list.data)
    }

    // MARK: - Shared helpers

    private static func resolveAsc(for config: LutinConfig,
                                   runner: CommandRunning,
                                   isExecutable: (String) -> Bool) throws -> String {
        try ASCLocator.resolve(
            explicit: nil, ascPath: config.store?.ascPath, runner: runner,
            isExecutable: isExecutable,
            installHint: "Install with `brew install asc`, or set store.ascPath in lutin.yml.")
    }

    private static func metadataDirectory(for config: LutinConfig,
                                          configURL: URL) throws -> URL {
        let relative = config.store?.resolvedMetadataDir ?? StoreInfo.defaultMetadataDir
        let url = URL(fileURLWithPath: relative,
                      relativeTo: configURL.deletingLastPathComponent()).standardizedFileURL
        // `ConfigValidator` is pure, so the "directory, not a file" rule lives
        // here, at resolution time, where the filesystem can be asked (§4.2).
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
           !isDirectory.boolValue {
            throw LutinError(
                code: "store_layout_mismatch",
                message: "store.metadataDir points at a file, not a directory. "
                       + "asc reads a directory of app-info/ and version/<v>/ files.",
                details: ["path": url.path])
        }
        return url
    }

    private static func platform(for store: StoreInfo?) -> String {
        store?.resolvedPlatform ?? StoreInfo.defaultPlatform
    }

    private static func appArguments(for store: StoreInfo?) -> [String] {
        guard let id = store?.appID, !id.isEmpty else { return [] }
        return ["--app", id]
    }

    private static func reviewPath(for explicit: String?, configURL: URL) -> String {
        if let explicit, !explicit.isEmpty { return explicit }
        // asc's own default, resolved against the project directory so the
        // plan/approve/apply trio agree regardless of the process cwd.
        return URL(fileURLWithPath: ".asc/metadata/review",
                   relativeTo: configURL.deletingLastPathComponent()).path
    }

    private static func rendered(_ asc: String, _ arguments: [String]) -> String {
        ([asc] + arguments).joined(separator: " ")
    }

    /// Capability gating (spec §4.3): a `.webSession` capability needs an
    /// authenticated web session; `.notPublicAPI` is disabled outright with
    /// asc's own `nextAction`; `.cliSupported`/`.partial`/`.unknown` pass
    /// through, and so does a command the capabilities payload does not
    /// enumerate. A failed capabilities probe is absence of evidence, not a
    /// reason to disable a working feature — only the probe is best-effort,
    /// never the command the caller asked for.
    private static func gate(ascPath: String, runner: CommandRunning,
                             command: String) throws {
        guard let capabilities = try? ASCCapabilities.load(ascPath: ascPath,
                                                           runner: runner) else { return }
        guard let entry = capabilities.capability(forCommand: command) else { return }
        switch entry.status {
        case .webSession:
            let web = try ASCWebSessionState.load(ascPath: ascPath, runner: runner)
            try web.assertAvailable(forCapability: command)
        case .notPublicAPI:
            throw LutinError(
                code: "store_unsupported",
                message: entry.nextAction
                    ?? "asc reports `\(command)` is not available over a public API.",
                details: ["ascCommand": command])
        case .cliSupported, .partial, .unknown:
            break
        }
    }

    /// Runs an asc command, and — when no explicit app was configured —
    /// surfaces `store_app_not_found` for asc's own "cannot resolve an app"
    /// failures (probed on asc 5.3.0: `Error: --app is required (or set
    /// ASC_APP_ID)`, exit 2). The mapping reads the first stderr line asc's
    /// error mapping already captured.
    private static func runMapped(_ client: ASCClient, _ arguments: [String],
                                  resolvingApp appID: String?) throws -> String {
        do {
            return try client.run(arguments)
        } catch let error as LutinError {
            throw appResolutionFailure(error, appID: appID)
        }
    }

    /// `runMapped`'s JSON counterpart: `runJSON` still owns the decode and
    /// exit-code mapping, and the "asc cannot resolve an app" wording is
    /// reused so both catalog calls fail identically.
    private static func runMappedJSON<Payload: Decodable>(
        _ client: ASCClient, _ arguments: [String],
        as type: Payload.Type, resolvingApp appID: String?) throws -> ASCResult<Payload> {
        do {
            return try client.runJSON(arguments, as: type)
        } catch let error as LutinError {
            throw appResolutionFailure(error, appID: appID)
        }
    }

    /// Re-writes an asc failure as `store_app_not_found` when no explicit app
    /// was configured and asc said it could not resolve one; returns the error
    /// unchanged otherwise.
    private static func appResolutionFailure(_ error: LutinError,
                                             appID: String?) -> LutinError {
        guard appID == nil,
              let stderr = error.details?["stderr"] else { return error }
        let haystack = stderr.lowercased()
        let markers = ["--app is required", "asc_app_id", "app not found", "no app"]
        guard markers.contains(where: { haystack.contains($0) }) else { return error }
        return LutinError(
            code: "store_app_not_found",
            message: "asc could not resolve an App Store Connect app. Set "
                   + "store.appID in lutin.yml (or ASC_APP_ID / a .asc/config.json) and retry.",
            details: error.details)
    }
}

import Foundation
import LutinCore

/// Signs an app bundle inner-to-outer using `codesign`.
public enum CodeSigner {
    /// Nested code items inside an app bundle that must be signed before the
    /// top-level bundle, returned deepest-first.
    ///
    /// Filters out SwiftPM-style resource bundles (`<Package>_<Target>.bundle`
    /// with a `Resources/` at the root and no `Contents/`). They are not
    /// independently code-signable — codesign rejects them with "bundle format
    /// unrecognized, invalid, or unsuitable" — and the parent app's seal
    /// already covers their contents via its recursive resource hash.
    public static func nestedCodePaths(in appBundle: URL) -> [URL] {
        let fm = FileManager.default
        let signableExtensions: Set<String> = ["framework", "dylib", "app", "xpc", "bundle", "appex"]
        var found: [URL] = []
        if let walker = fm.enumerator(at: appBundle,
                                      includingPropertiesForKeys: nil,
                                      options: []) {
            for case let url as URL in walker {
                guard signableExtensions.contains(url.pathExtension) else { continue }
                if url.pathExtension == "bundle", !isCodeSignableBundle(url) { continue }
                found.append(url)
            }
        }
        // Deepest paths first, so children sign before their parents.
        return found.sorted { $0.pathComponents.count > $1.pathComponents.count }
    }

    /// True when `bundle` follows the macOS bundle layout codesign expects
    /// (a `Contents/` directory holding `Info.plist` and `MacOS/`). False for
    /// SwiftPM resource bundles, which keep their `Resources/` at the root.
    private static func isCodeSignableBundle(_ bundle: URL) -> Bool {
        let contents = bundle.appendingPathComponent("Contents", isDirectory: true)
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: contents.path,
                                              isDirectory: &isDir) && isDir.boolValue
    }

    private static let codesign = "/usr/bin/codesign"

    /// Signs `appBundle` inner-to-outer: nested code first, then the bundle
    /// itself with hardened runtime and optional entitlements.
    public static func signApp(_ appBundle: URL, identity: String,
                               entitlements: String?,
                               hardenedRuntime: Bool = true,
                               runner: CommandRunning) throws {
        // Nested items: deepest first, no entitlements, same runtime policy.
        for item in nestedCodePaths(in: appBundle) {
            try sign(item, identity: identity, entitlements: nil,
                     hardenedRuntime: hardenedRuntime, runner: runner)
        }
        // Top-level app last, with entitlements if given.
        try sign(appBundle, identity: identity, entitlements: entitlements,
                 hardenedRuntime: hardenedRuntime, runner: runner)
    }

    /// Signs one item with `codesign`.
    static func sign(_ target: URL, identity: String, entitlements: String?,
                     hardenedRuntime: Bool = true,
                     runner: CommandRunning) throws {
        var args = ["--force", "--sign", identity]
        if hardenedRuntime {
            args += ["--options", "runtime"]
        }
        args.append("--timestamp")
        if let entitlements {
            args += ["--entitlements", entitlements]
        }
        args.append(target.path)
        do {
            _ = try runner.run(codesign, args)
        } catch let error as LutinError {
            throw signingFailed(target: target,
                                action: "codesign",
                                error: error)
        }
    }

    /// Builds a `signing_failed` error that surfaces codesign's real
    /// diagnostic line. codesign writes its error to stdout for some
    /// failures (e.g. "bundle format unrecognized") and to stderr for
    /// others; prefer whichever has content, fall back to the generic
    /// "exited with code N" message if both are empty.
    private static func signingFailed(target: URL, action: String,
                                      error: LutinError) -> LutinError {
        let stderr = error.details?["stderr"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stdout = error.details?["stdout"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let detail = !stderr.isEmpty ? stderr
                   : !stdout.isEmpty ? stdout
                   : ""
        let suffix = detail.isEmpty ? error.message : "\(error.message)\n\(detail)"
        var details = ["target": target.path]
        if !detail.isEmpty { details["codesignOutput"] = detail }
        return LutinError(
            code: "signing_failed",
            message: "\(action) failed for \(target.lastPathComponent): \(suffix)",
            details: details)
    }

    private static let security = "/usr/bin/security"

    /// Signs a `.dmg` file with `codesign`.
    public static func signDMG(_ dmg: URL, identity: String,
                               runner: CommandRunning) throws {
        do {
            _ = try runner.run(codesign, ["--force", "--sign", identity,
                                          "--timestamp", dmg.path])
        } catch let error as LutinError {
            throw signingFailed(target: dmg, action: "codesign", error: error)
        }
    }

    /// Throws `identity_not_found` if `identity` is not in the Keychain.
    public static func verifyIdentityExists(_ identity: String,
                                            runner: CommandRunning) throws {
        let result = try runner.runAllowingFailure(
            security, ["find-identity", "-v", "-p", "codesigning"])
        if !result.stdout.contains(identity) {
            throw LutinError(
                code: "identity_not_found",
                message: "Signing identity '\(identity)' was not found in the Keychain. "
                       + "Import your Developer ID certificate, or check signing.identity.",
                details: ["identity": identity])
        }
    }

    /// Verifies a signed bundle with `codesign --verify --deep --strict`.
    public static func verifySignature(of bundle: URL,
                                       runner: CommandRunning) throws {
        do {
            _ = try runner.run(codesign, ["--verify", "--deep", "--strict", bundle.path])
        } catch let error as LutinError {
            throw signingFailed(target: bundle,
                                action: "Signature verification",
                                error: error)
        }
    }
}

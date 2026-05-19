import Foundation
import LutinCore

/// Signs an app bundle inner-to-outer using `codesign`.
public enum CodeSigner {
    /// Nested code items inside an app bundle that must be signed before the
    /// top-level bundle, returned deepest-first.
    public static func nestedCodePaths(in appBundle: URL) -> [URL] {
        let fm = FileManager.default
        let signableExtensions: Set<String> = ["framework", "dylib", "app", "xpc", "bundle", "appex"]
        var found: [URL] = []
        if let walker = fm.enumerator(at: appBundle,
                                      includingPropertiesForKeys: nil,
                                      options: []) {
            for case let url as URL in walker {
                if signableExtensions.contains(url.pathExtension) {
                    found.append(url)
                }
            }
        }
        // Deepest paths first, so children sign before their parents.
        return found.sorted { $0.pathComponents.count > $1.pathComponents.count }
    }

    private static let codesign = "/usr/bin/codesign"

    /// Signs `appBundle` inner-to-outer: nested code first, then the bundle
    /// itself with hardened runtime and optional entitlements.
    public static func signApp(_ appBundle: URL, identity: String,
                               entitlements: String?,
                               runner: CommandRunning) throws {
        // Nested items: deepest first, no entitlements, with hardened runtime.
        for item in nestedCodePaths(in: appBundle) {
            try sign(item, identity: identity, entitlements: nil, runner: runner)
        }
        // Top-level app last, with entitlements if given.
        try sign(appBundle, identity: identity, entitlements: entitlements, runner: runner)
    }

    /// Signs one item with `codesign`, always forcing hardened runtime.
    static func sign(_ target: URL, identity: String, entitlements: String?,
                     runner: CommandRunning) throws {
        var args = ["--force", "--sign", identity, "--options", "runtime", "--timestamp"]
        if let entitlements {
            args += ["--entitlements", entitlements]
        }
        args.append(target.path)
        do {
            _ = try runner.run(codesign, args)
        } catch let error as LutinError {
            throw LutinError(
                code: "signing_failed",
                message: "codesign failed for \(target.lastPathComponent): \(error.message)",
                details: ["target": target.path])
        }
    }

    private static let security = "/usr/bin/security"

    /// Signs a `.dmg` file with `codesign`.
    public static func signDMG(_ dmg: URL, identity: String,
                               runner: CommandRunning) throws {
        do {
            _ = try runner.run(codesign, ["--force", "--sign", identity,
                                          "--timestamp", dmg.path])
        } catch let error as LutinError {
            throw LutinError(code: "signing_failed",
                             message: "codesign failed for the DMG: \(error.message)",
                             details: ["target": dmg.path])
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
            throw LutinError(code: "signing_failed",
                             message: "Signature verification failed for "
                                    + "\(bundle.lastPathComponent): \(error.message)",
                             details: ["target": bundle.path])
        }
    }
}

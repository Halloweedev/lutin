import Foundation
import LutinCore

/// Resolves the `asc` binary.
///
/// This logic previously lived in `LutinCLI/AppStore.swift`. It moved down here
/// because `LutinStoreConnect` needs it and cannot depend on `LutinCLI` — the
/// dependency runs the other way. `AppStore.swift` now calls into this type, so
/// there is exactly one resolver rather than two that drift.
public enum ASCLocator {

    /// Well-known Homebrew install locations, checked before PATH lookup.
    /// `which` alone can miss brew when the caller's PATH is sparse.
    public static let knownPaths = ["/opt/homebrew/bin/asc", "/usr/local/bin/asc"]

    /// Explicit `store.ascPath` → known Homebrew locations → `which asc`.
    ///
    /// `installHint` is a seam: it suffixes the "not found" message so the two
    /// call sites can advertise the install hint that is actually true for each
    /// surface (`--asc-path` is a `lutin app-store` flag; `lutin store` uses
    /// `store.ascPath` instead). The default matches this module's contract.
    ///
    /// - Throws: `LutinError(code: "store_asc_missing")` when nothing resolves.
    public static func resolve(explicit: String?,
                               ascPath: String?,
                               runner: CommandRunning,
                               isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
                               installHint: String = "Install with `brew install asc`.") throws -> String {
        // `store.ascPath` is the user's explicit instruction; a bad value is an
        // error, not a cue to guess.
        if let ascPath, !ascPath.isEmpty {
            guard isExecutable(ascPath) else {
                throw LutinError(
                    code: "store_asc_missing",
                    message: "No executable `asc` at \(ascPath), which is set as store.ascPath. "
                           + "Fix the path or remove it to auto-detect.",
                    details: ["ascPath": ascPath])
            }
            return ascPath
        }
        if let explicit, !explicit.isEmpty {
            guard isExecutable(explicit) else {
                throw LutinError(
                    code: "store_asc_missing",
                    message: "No executable `asc` at \(explicit). Install with `brew install asc`.",
                    details: ["ascPath": explicit])
            }
            return explicit
        }
        if let found = knownPaths.first(where: isExecutable) { return found }

        let result = try? runner.runAllowingFailure("/usr/bin/which", ["asc"])
        if let path = result?.stdout.trimmingCharacters(in: .whitespacesAndNewlines),
           result?.exitCode == 0, !path.isEmpty, isExecutable(path) {
            return path
        }
        throw LutinError(
            code: "store_asc_missing",
            message: "The `asc` App Store Connect CLI was not found. " + installHint,
            details: nil)
    }
}

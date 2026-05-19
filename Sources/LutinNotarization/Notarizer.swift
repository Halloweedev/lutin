import Foundation
import LutinCore

/// Wraps `xcrun notarytool` for submitting a DMG to Apple's notary service.
public enum Notarizer {
    private static let xcrun = "/usr/bin/xcrun"

    /// Submits `dmg` and waits for Apple's verdict. Throws on rejection or
    /// tool failure.
    public static func submit(dmg: URL, profile: String,
                              runner: CommandRunning) throws {
        let result: ShellResult
        do {
            result = try runner.run(xcrun, [
                "notarytool", "submit", dmg.path,
                "--keychain-profile", profile, "--wait",
            ])
        } catch let error as LutinError {
            throw LutinError(
                code: "notarization_failed",
                message: "notarytool could not complete the submission: \(error.message). "
                       + "Check your network and that the '\(profile)' profile is valid.",
                details: ["profile": profile])
        }
        // notarytool exits 0 even when the verdict is Invalid; inspect output.
        let output = result.stdout + result.stderr
        if output.contains("status: Accepted") {
            return
        }
        // Try to fetch the log for an Invalid verdict.
        let submissionID = parseSubmissionID(from: output)
        var log = ""
        if let submissionID {
            log = (try? runner.runAllowingFailure(xcrun, [
                "notarytool", "log", submissionID, "--keychain-profile", profile,
            ]).stdout) ?? ""
        }
        throw LutinError(
            code: "notarization_rejected",
            message: "Apple rejected the notarization submission. Notary log:\n\(log)",
            details: ["log": log])
    }

    /// Extracts the submission `id:` value from notarytool output.
    static func parseSubmissionID(from output: String) -> String? {
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("id:") {
                return trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}

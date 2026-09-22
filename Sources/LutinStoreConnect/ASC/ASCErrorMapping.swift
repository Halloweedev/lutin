import Foundation
import LutinCore

/// Turns an `asc` failure into a `store_*` error.
///
/// Three things here are load-bearing and were established by probing asc
/// 5.3.0, not by reading its documentation:
///
/// - Exit **2** means a schema or parse error. stdout is empty and stderr holds
///   the error line *followed by the command's full help text*.
/// - Exit **1** means validation ran and found errors — a result, not a
///   transport failure.
/// - Auth failures are detected by wording, and must never be confused with a
///   missing binary.
public enum ASCErrorMapping {

    /// asc appends its entire help text after the error line, so anything that
    /// surfaces stderr verbatim leaks a wall of usage text into the UI.
    public static func firstLine(of stderr: String) -> String {
        stderr
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
    }

    public static func map(result: ShellResult,
                           command: [String],
                           fallbackCode: String) -> LutinError {
        let rendered = (["asc"] + command).joined(separator: " ")
        let first = firstLine(of: result.stderr)
        let haystack = (result.stdout + "\n" + result.stderr).lowercased()

        var details: [String: String] = [
            "ascCommand": rendered,
            "exitCode": String(result.exitCode),
        ]
        if !first.isEmpty { details["stderr"] = first }

        // Exit 2 — schema/parse. Highest precedence: it is unambiguous.
        if result.exitCode == 2 {
            return LutinError(
                code: "store_metadata_schema",
                message: first.isEmpty
                    ? "asc rejected the metadata schema (exit 2)."
                    : first,
                details: details)
        }

        // Auth wording. Checked before the fallback so an installed-but-
        // unauthenticated asc is never reported as missing.
        let authMarkers = ["unauthorized", "401", "api key", "issuer",
                           "credential", "not authenticated"]
        if authMarkers.contains(where: { haystack.contains($0) }) {
            return LutinError(
                code: "store_unauthenticated",
                message: "asc is not authenticated. Run `asc auth login` "
                       + "(or set ASC_* environment credentials) and retry.",
                details: details)
        }

        if haystack.contains("429") || haystack.contains("rate limit")
            || haystack.contains("too many requests") {
            return LutinError(
                code: "store_rate_limited",
                message: "App Store Connect rate limit reached. Limits are hourly; "
                       + "wait and retry.",
                details: details)
        }

        // Exit 1 with a JSON body is a validation result, not a failure of the
        // tool. Callers that want findings use
        // `runAllowingValidationFailure`; reaching here means they did not.
        if result.exitCode == 1, !result.stdout.isEmpty {
            return LutinError(
                code: "store_validation_failed",
                message: first.isEmpty
                    ? "Metadata validation failed. Review the findings and retry."
                    : first,
                details: details)
        }

        return LutinError(
            code: fallbackCode,
            message: first.isEmpty
                ? "`\(rendered)` failed with exit \(result.exitCode)."
                : first,
            details: details)
    }
}

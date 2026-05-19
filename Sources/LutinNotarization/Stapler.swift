import Foundation
import LutinCore

/// Wraps `xcrun stapler` for attaching and validating a notarization ticket.
public enum Stapler {
    private static let xcrun = "/usr/bin/xcrun"

    /// Staples the notarization ticket to `dmg`, then validates it.
    public static func staple(_ dmg: URL, runner: CommandRunning) throws {
        do {
            _ = try runner.run(xcrun, ["stapler", "staple", dmg.path])
        } catch let error as LutinError {
            throw LutinError(code: "staple_failed",
                             message: "stapler could not staple the ticket: \(error.message).",
                             details: ["dmg": dmg.path])
        }
        do {
            _ = try runner.run(xcrun, ["stapler", "validate", dmg.path])
        } catch let error as LutinError {
            throw LutinError(code: "staple_failed",
                             message: "Stapled ticket failed validation: \(error.message).",
                             details: ["dmg": dmg.path])
        }
    }
}

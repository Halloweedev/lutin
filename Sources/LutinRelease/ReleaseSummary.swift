import Foundation
import LutinCore

/// The structured result of a release, written as `release-summary.json`.
public struct ReleaseSummary: Codable, Equatable {
    public let projectName: String
    public let appName: String
    public let bundleId: String
    public let version: String
    public let buildNumber: String
    public let dmgPath: String
    public let dmgSizeBytes: Int
    public let sha256: String
    public let signingStatus: String
    public let notarizationStatus: String
    public let timestamp: String

    public init(projectName: String, appName: String, bundleId: String,
                version: String, buildNumber: String, dmgPath: String,
                dmgSizeBytes: Int, sha256: String, signingStatus: String,
                notarizationStatus: String, timestamp: String) {
        self.projectName = projectName
        self.appName = appName
        self.bundleId = bundleId
        self.version = version
        self.buildNumber = buildNumber
        self.dmgPath = dmgPath
        self.dmgSizeBytes = dmgSizeBytes
        self.sha256 = sha256
        self.signingStatus = signingStatus
        self.notarizationStatus = notarizationStatus
        self.timestamp = timestamp
    }

    /// Writes `release-summary.json` and `checksums.txt` into `directory`.
    public func write(toDirectory directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let summaryURL = directory.appendingPathComponent("release-summary.json")
        do {
            try encoder.encode(self).write(to: summaryURL)
        } catch {
            throw LutinError(code: "write_failed",
                             message: "Could not write release-summary.json: \(error).")
        }

        // checksums.txt — `shasum -a 256` format: "<hash>  <filename>".
        let dmgFileName = URL(fileURLWithPath: dmgPath).lastPathComponent
        let checksums = "\(sha256)  \(dmgFileName)\n"
        let checksumsURL = directory.appendingPathComponent("checksums.txt")
        do {
            try checksums.write(to: checksumsURL, atomically: true, encoding: .utf8)
        } catch {
            throw LutinError(code: "write_failed",
                             message: "Could not write checksums.txt: \(error).")
        }
    }
}

import XCTest
import TestSupport
@testable import LutinRelease

final class ReleaseSummaryTests: XCTestCase {
    private func sample() -> ReleaseSummary {
        ReleaseSummary(
            projectName: "Barry", appName: "Barry.app",
            bundleId: "com.anotheragence.barry", version: "1.0.0", buildNumber: "42",
            dmgPath: "/out/Barry-1.0.0.dmg", dmgSizeBytes: 1234,
            sha256: String(repeating: "a", count: 64),
            signingStatus: "signed", notarizationStatus: "notarized",
            timestamp: "2026-05-18T00:00:00Z")
    }

    func testWritesSummaryJsonAndChecksums() throws {
        let outDir = try Fixtures.makeTempDirectory()
        try sample().write(toDirectory: outDir)

        let summaryURL = outDir.appendingPathComponent("release-summary.json")
        let checksumsURL = outDir.appendingPathComponent("checksums.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: summaryURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: checksumsURL.path))

        let json = try String(contentsOf: summaryURL, encoding: .utf8)
        XCTAssertTrue(json.contains("\"version\""))
        XCTAssertTrue(json.contains("Barry"))

        let checksums = try String(contentsOf: checksumsURL, encoding: .utf8)
        XCTAssertTrue(checksums.contains(String(repeating: "a", count: 64)))
        XCTAssertTrue(checksums.contains("Barry-1.0.0.dmg"))
    }
}

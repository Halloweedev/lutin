import XCTest
import TestSupport
@testable import LutinCLI

final class DoctorSigningTests: XCTestCase {
    func testDoctorIncludesSigningAndNotaryChecksWhenEnabled() throws {
        let projectDir = try Fixtures.makeTempDirectory()
        let fm = FileManager.default
        try fm.copyItem(at: Fixtures.barryApp,
                        to: projectDir.appendingPathComponent("Barry.app"))
        let yaml = """
        project:
          name: Barry
          bundleId: com.anotheragence.barry
        app:
          path: ./Barry.app
        output:
          directory: ./release
          dmgName: Barry-${version}.dmg
          volumeName: Barry
        signing:
          enabled: true
          identity: "Developer ID Application: Nobody"
        notarization:
          enabled: true
          profile: lutin-notary
        """
        let configURL = projectDir.appendingPathComponent("lutin.yml")
        try yaml.write(to: configURL, atomically: true, encoding: .utf8)

        let checks = try CommandLogic.doctor(configURL: configURL)
        let names = Set(checks.map(\.name))
        XCTAssertTrue(names.contains("signingIdentity"))
        XCTAssertTrue(names.contains("notaryProfile"))
    }

    func testDoctorOmitsSigningChecksWhenDisabled() throws {
        let checks = try CommandLogic.doctor(configURL: Fixtures.barryConfig)
        let names = Set(checks.map(\.name))
        XCTAssertFalse(names.contains("signingIdentity"))
    }
}

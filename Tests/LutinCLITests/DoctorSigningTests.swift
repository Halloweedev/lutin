import XCTest
import TestSupport
import LutinCore
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

    // MARK: - Runner injection tests

    private func makeSigningConfig(in dir: URL, identity: String) throws -> URL {
        let fm = FileManager.default
        try fm.copyItem(at: Fixtures.barryApp,
                        to: dir.appendingPathComponent("Barry.app"))
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
          identity: "\(identity)"
        notarization:
          enabled: true
          profile: lutin-notary
        """
        let configURL = dir.appendingPathComponent("lutin.yml")
        try yaml.write(to: configURL, atomically: true, encoding: .utf8)
        return configURL
    }

    func testSigningIdentityOkWhenFoundInSecurityOutput() throws {
        let projectDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: projectDir) }
        let identity = "Developer ID Application: Test Corp (ABCD1234)"
        let configURL = try makeSigningConfig(in: projectDir, identity: identity)

        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/security",
                  result: ShellResult(exitCode: 0,
                    stdout: "1) ABC123 \"\(identity)\"", stderr: ""))
        fake.stub(executable: "/usr/bin/xcrun",
                  result: ShellResult(exitCode: 0, stdout: "", stderr: ""))

        let checks = try CommandLogic.doctor(configURL: configURL, runner: fake)
        let signingCheck = try XCTUnwrap(checks.first { $0.name == "signingIdentity" })
        XCTAssertTrue(signingCheck.ok, "Expected signingIdentity ok=true when identity is in security output")
    }

    func testSigningIdentityNotOkWhenMissingFromSecurityOutput() throws {
        let projectDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: projectDir) }
        let identity = "Developer ID Application: Test Corp (ABCD1234)"
        let configURL = try makeSigningConfig(in: projectDir, identity: identity)

        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/security",
                  result: ShellResult(exitCode: 0,
                    stdout: "No matching identities found", stderr: ""))
        fake.stub(executable: "/usr/bin/xcrun",
                  result: ShellResult(exitCode: 0, stdout: "", stderr: ""))

        let checks = try CommandLogic.doctor(configURL: configURL, runner: fake)
        let signingCheck = try XCTUnwrap(checks.first { $0.name == "signingIdentity" })
        XCTAssertFalse(signingCheck.ok, "Expected signingIdentity ok=false when identity is absent from security output")
    }

    func testNotaryProfileOkWhenXcrunSucceeds() throws {
        let projectDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: projectDir) }
        let configURL = try makeSigningConfig(in: projectDir, identity: "Some Identity")

        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/security",
                  result: ShellResult(exitCode: 0, stdout: "Some Identity", stderr: ""))
        fake.stub(executable: "/usr/bin/xcrun",
                  result: ShellResult(exitCode: 0, stdout: "History: []", stderr: ""))

        let checks = try CommandLogic.doctor(configURL: configURL, runner: fake)
        let notaryCheck = try XCTUnwrap(checks.first { $0.name == "notaryProfile" })
        XCTAssertTrue(notaryCheck.ok, "Expected notaryProfile ok=true when xcrun exits 0")
    }

    func testNotaryProfileNotOkWhenXcrunFails() throws {
        let projectDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: projectDir) }
        let configURL = try makeSigningConfig(in: projectDir, identity: "Some Identity")

        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/security",
                  result: ShellResult(exitCode: 0, stdout: "Some Identity", stderr: ""))
        fake.stub(executable: "/usr/bin/xcrun",
                  result: ShellResult(exitCode: 69, stdout: "", stderr: "profile not found"))

        let checks = try CommandLogic.doctor(configURL: configURL, runner: fake)
        let notaryCheck = try XCTUnwrap(checks.first { $0.name == "notaryProfile" })
        XCTAssertFalse(notaryCheck.ok, "Expected notaryProfile ok=false when xcrun exits non-zero")
    }
}

import XCTest
import TestSupport
import LutinRegistry
@testable import LutinCLI

final class BuildOutcomeWritebackTests: XCTestCase {
    func testBuildRecordsUnsignedOutcomeInInjectedRegistry() throws {
        let projectDir = try makeBarryProjectCopy()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        let registry = Registry(storeURL: projectDir.appendingPathComponent("projects.json"))
        let configURL = projectDir.appendingPathComponent("lutin.yml")
        _ = try CommandLogic.addProject(configPath: configURL.path,
                                        overrideName: nil,
                                        registry: registry,
                                        dryRun: false)

        _ = try CommandLogic.build(configURL: configURL,
                                   dryRun: false,
                                   registry: registry)

        XCTAssertEqual(try registry.find(name: "Barry")?.lastBuildOutcome, .unsigned)
    }

    func testBuildRecordsUnsignedOutcomeEvenWhenSigningEnabled() throws {
        let projectDir = try makeBarryProjectCopy()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        let registry = Registry(storeURL: projectDir.appendingPathComponent("projects.json"))
        let configURL = projectDir.appendingPathComponent("lutin.yml")
        try enableSigning(in: configURL)
        _ = try CommandLogic.addProject(configPath: configURL.path,
                                        overrideName: nil,
                                        registry: registry,
                                        dryRun: false)

        _ = try CommandLogic.build(configURL: configURL,
                                   dryRun: false,
                                   registry: registry)

        XCTAssertEqual(try registry.find(name: "Barry")?.lastBuildOutcome, .unsigned)
    }


    func testBuildDryRunDoesNotRecordOutcome() throws {
        let projectDir = try makeBarryProjectCopy()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        let registry = Registry(storeURL: projectDir.appendingPathComponent("projects.json"))
        let configURL = projectDir.appendingPathComponent("lutin.yml")
        _ = try CommandLogic.addProject(configPath: configURL.path,
                                        overrideName: nil,
                                        registry: registry,
                                        dryRun: false)

        _ = try CommandLogic.build(configURL: configURL,
                                   dryRun: true,
                                   registry: registry)

        XCTAssertNil(try registry.find(name: "Barry")?.lastBuildOutcome)
    }

    func testBuildFailureRecordsFailedOutcomeInInjectedRegistry() throws {
        let projectDir = try makeBarryProjectCopy()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        let registry = Registry(storeURL: projectDir.appendingPathComponent("projects.json"))
        let configURL = projectDir.appendingPathComponent("lutin.yml")
        _ = try CommandLogic.addProject(configPath: configURL.path,
                                        overrideName: nil,
                                        registry: registry,
                                        dryRun: false)
        try FileManager.default.removeItem(at: projectDir.appendingPathComponent("Barry.app"))

        XCTAssertThrowsError(try CommandLogic.build(configURL: configURL,
                                                    dryRun: false,
                                                    registry: registry))
        XCTAssertEqual(try registry.find(name: "Barry")?.lastBuildOutcome, .failed)
    }

    func testBuildFailureRecordsOutcomeForMatchingConfigPathWhenNameDiffers() throws {
        let projectDir = try makeBarryProjectCopy()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        let registry = Registry(storeURL: projectDir.appendingPathComponent("projects.json"))
        let configURL = projectDir.appendingPathComponent("lutin.yml")
        _ = try CommandLogic.addProject(configPath: configURL.path,
                                        overrideName: "Custom Barry",
                                        registry: registry,
                                        dryRun: false)
        try FileManager.default.removeItem(at: projectDir.appendingPathComponent("Barry.app"))

        XCTAssertThrowsError(try CommandLogic.build(configURL: configURL,
                                                    dryRun: false,
                                                    registry: registry))
        XCTAssertEqual(try registry.find(name: "Custom Barry")?.lastBuildOutcome, .failed)
        XCTAssertNil(try registry.find(name: "Barry")?.lastBuildOutcome)
    }

    func testBuildFailureRecordsOutcomeForNamedDuplicateConfigPathOnly() throws {
        let projectDir = try makeBarryProjectCopy()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        let registry = Registry(storeURL: projectDir.appendingPathComponent("projects.json"))
        let configURL = projectDir.appendingPathComponent("lutin.yml")
        _ = try CommandLogic.addProject(configPath: configURL.path,
                                        overrideName: "Barry One",
                                        registry: registry,
                                        dryRun: false)
        _ = try CommandLogic.addProject(configPath: configURL.path,
                                        overrideName: "Barry Two",
                                        registry: registry,
                                        dryRun: false)
        try FileManager.default.removeItem(at: projectDir.appendingPathComponent("Barry.app"))

        XCTAssertThrowsError(try CommandLogic.build(configURL: configURL,
                                                    dryRun: false,
                                                    registry: registry,
                                                    registryEntryName: "Barry Two"))
        XCTAssertNil(try registry.find(name: "Barry One")?.lastBuildOutcome)
        XCTAssertEqual(try registry.find(name: "Barry Two")?.lastBuildOutcome, .failed)
    }

    func testBuildFailureRecordsOutcomeForAllMatchingConfigPathsWithoutName() throws {
        let projectDir = try makeBarryProjectCopy()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        let registry = Registry(storeURL: projectDir.appendingPathComponent("projects.json"))
        let configURL = projectDir.appendingPathComponent("lutin.yml")
        _ = try CommandLogic.addProject(configPath: configURL.path,
                                        overrideName: "Barry One",
                                        registry: registry,
                                        dryRun: false)
        _ = try CommandLogic.addProject(configPath: configURL.path,
                                        overrideName: "Barry Two",
                                        registry: registry,
                                        dryRun: false)
        try FileManager.default.removeItem(at: projectDir.appendingPathComponent("Barry.app"))

        XCTAssertThrowsError(try CommandLogic.build(configURL: configURL,
                                                    dryRun: false,
                                                    registry: registry))
        XCTAssertEqual(try registry.find(name: "Barry One")?.lastBuildOutcome, .failed)
        XCTAssertEqual(try registry.find(name: "Barry Two")?.lastBuildOutcome, .failed)
    }

    func testBuildConfigLoadFailureRecordsFailedOutcomeForRegisteredPath() throws {
        let projectDir = try makeBarryProjectCopy()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        let registry = Registry(storeURL: projectDir.appendingPathComponent("projects.json"))
        let configURL = projectDir.appendingPathComponent("lutin.yml")
        _ = try CommandLogic.addProject(configPath: configURL.path,
                                        overrideName: nil,
                                        registry: registry,
                                        dryRun: false)
        try "not: [valid".write(to: configURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try CommandLogic.build(configURL: configURL,
                                                    dryRun: false,
                                                    registry: registry))
        XCTAssertEqual(try registry.find(name: "Barry")?.lastBuildOutcome, .failed)
    }

    func testBuildDryRunConfigLoadFailureDoesNotRecordOutcome() throws {
        let projectDir = try makeBarryProjectCopy()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        let registry = Registry(storeURL: projectDir.appendingPathComponent("projects.json"))
        let configURL = projectDir.appendingPathComponent("lutin.yml")
        _ = try CommandLogic.addProject(configPath: configURL.path,
                                        overrideName: nil,
                                        registry: registry,
                                        dryRun: false)
        try "not: [valid".write(to: configURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try CommandLogic.build(configURL: configURL,
                                                    dryRun: true,
                                                    registry: registry))
        XCTAssertNil(try registry.find(name: "Barry")?.lastBuildOutcome)
    }

    func testBuildFailureDoesNotRecordOutcomeForUnregisteredMatchingProjectName() throws {
        let registeredProjectDir = try makeBarryProjectCopy()
        let unregisteredProjectDir = try makeBarryProjectCopy()
        defer {
            try? FileManager.default.removeItem(at: registeredProjectDir)
            try? FileManager.default.removeItem(at: unregisteredProjectDir)
        }
        let registry = Registry(storeURL: registeredProjectDir.appendingPathComponent("projects.json"))
        let registeredConfigURL = registeredProjectDir.appendingPathComponent("lutin.yml")
        let unregisteredConfigURL = unregisteredProjectDir.appendingPathComponent("lutin.yml")
        _ = try CommandLogic.addProject(configPath: registeredConfigURL.path,
                                        overrideName: nil,
                                        registry: registry,
                                        dryRun: false)
        try FileManager.default.removeItem(
            at: unregisteredProjectDir.appendingPathComponent("Barry.app"))

        XCTAssertThrowsError(try CommandLogic.build(configURL: unregisteredConfigURL,
                                                    dryRun: false,
                                                    registry: registry))
        XCTAssertNil(try registry.find(name: "Barry")?.lastBuildOutcome)
    }

    func testBuildFailureDoesNotRecordOutcomeForUnregisteredMatchingParentName() throws {
        let root = try Fixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let registeredProjectDir = root.appendingPathComponent("registered/Barry")
        let unregisteredProjectDir = root.appendingPathComponent("unregistered/Barry")
        try FileManager.default.createDirectory(
            at: registeredProjectDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: unregisteredProjectDir, withIntermediateDirectories: true)
        try copyBarryProject(into: registeredProjectDir)
        try copyBarryProject(into: unregisteredProjectDir)

        let registry = Registry(storeURL: root.appendingPathComponent("projects.json"))
        let registeredConfigURL = registeredProjectDir.appendingPathComponent("lutin.yml")
        let unregisteredConfigURL = unregisteredProjectDir.appendingPathComponent("lutin.yml")
        _ = try CommandLogic.addProject(configPath: registeredConfigURL.path,
                                        overrideName: nil,
                                        registry: registry,
                                        dryRun: false)
        try FileManager.default.removeItem(
            at: unregisteredProjectDir.appendingPathComponent("Barry.app"))

        XCTAssertThrowsError(try CommandLogic.build(configURL: unregisteredConfigURL,
                                                    dryRun: false,
                                                    registry: registry))
        XCTAssertNil(try registry.find(name: "Barry")?.lastBuildOutcome)
    }

    func testReleaseWithoutSigningRecordsUnsignedOutcomeInInjectedRegistry() throws {
        let projectDir = try makeBarryProjectCopy()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        let registry = Registry(storeURL: projectDir.appendingPathComponent("projects.json"))
        let configURL = projectDir.appendingPathComponent("lutin.yml")
        _ = try CommandLogic.addProject(configPath: configURL.path,
                                        overrideName: nil,
                                        registry: registry,
                                        dryRun: false)

        _ = try CommandLogic.release(configURL: configURL, registry: registry)

        XCTAssertEqual(try registry.find(name: "Barry")?.lastBuildOutcome, .unsigned)
    }

    private func makeBarryProjectCopy() throws -> URL {
        let projectDir = try Fixtures.makeTempDirectory()
        try copyBarryProject(into: projectDir)
        return projectDir
    }

    private func copyBarryProject(into projectDir: URL) throws {
        let fm = FileManager.default
        try fm.copyItem(at: Fixtures.barryApp,
                        to: projectDir.appendingPathComponent("Barry.app"))
        try fm.copyItem(at: Fixtures.barryConfig,
                        to: projectDir.appendingPathComponent("lutin.yml"))
    }

    private func enableSigning(in configURL: URL) throws {
        let signing = """

        signing:
          enabled: true
          identity: 'Developer ID Application: Example'
        """
        var config = try String(contentsOf: configURL, encoding: .utf8)
        config.append(signing)
        try config.write(to: configURL, atomically: true, encoding: .utf8)
    }
}

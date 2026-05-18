import XCTest
import TestSupport
@testable import LutinCore

final class ProjectResolverTests: XCTestCase {
    /// A registry lookup that knows one project.
    private func lookup(_ name: String) -> URL? {
        name == "Barry" ? Fixtures.barryConfig : nil
    }

    func testConfigFlagWinsOverEverything() throws {
        let resolved = try ProjectResolver.resolve(
            explicitConfig: Fixtures.barryConfig.path,
            projectName: "Barry",
            currentDirectory: Fixtures.barryProject,
            registryLookup: { _ in URL(fileURLWithPath: "/wrong/lutin.yml") })
        XCTAssertEqual(resolved.standardizedFileURL, Fixtures.barryConfig.standardizedFileURL)
    }

    func testNamedArgUsedWhenNoConfigFlag() throws {
        let resolved = try ProjectResolver.resolve(
            explicitConfig: nil, projectName: "Barry",
            currentDirectory: FileManager.default.temporaryDirectory,
            registryLookup: lookup)
        XCTAssertEqual(resolved.standardizedFileURL, Fixtures.barryConfig.standardizedFileURL)
    }

    func testCurrentDirectoryUsedAsLastResort() throws {
        let resolved = try ProjectResolver.resolve(
            explicitConfig: nil, projectName: nil,
            currentDirectory: Fixtures.barryProject, registryLookup: lookup)
        XCTAssertEqual(resolved.standardizedFileURL, Fixtures.barryConfig.standardizedFileURL)
    }

    func testUnknownNameThrows() {
        XCTAssertThrowsError(try ProjectResolver.resolve(
            explicitConfig: nil, projectName: "Ghost",
            currentDirectory: FileManager.default.temporaryDirectory,
            registryLookup: lookup)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "project_not_in_registry")
        }
    }

    func testNoSourceThrowsNoProjectInCwd() {
        XCTAssertThrowsError(try ProjectResolver.resolve(
            explicitConfig: nil, projectName: nil,
            currentDirectory: FileManager.default.temporaryDirectory,
            registryLookup: lookup)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "no_project_in_cwd")
        }
    }

    func testMissingExplicitConfigThrows() {
        XCTAssertThrowsError(try ProjectResolver.resolve(
            explicitConfig: "/tmp/nope/lutin.yml", projectName: nil,
            currentDirectory: FileManager.default.temporaryDirectory,
            registryLookup: lookup)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "config_not_found")
        }
    }

    func testRegistryLookupErrorPropagates() {
        struct Boom: Error {}
        XCTAssertThrowsError(try ProjectResolver.resolve(
            explicitConfig: nil, projectName: "Barry",
            currentDirectory: FileManager.default.temporaryDirectory,
            registryLookup: { _ in throw Boom() }))
    }
}

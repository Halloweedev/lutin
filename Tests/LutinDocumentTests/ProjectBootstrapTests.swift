import XCTest
@testable import LutinDocument
@testable import LutinConfig

final class ProjectBootstrapTests: XCTestCase {
    func testSlugify() {
        XCTAssertEqual(ProjectBootstrap.slugify("My Project"), "my-project")
        XCTAssertEqual(ProjectBootstrap.slugify(""), "")
        XCTAssertEqual(ProjectBootstrap.slugify("Foo!Bar"), "foo-bar")
        XCTAssertEqual(ProjectBootstrap.slugify("  --hi--there  "), "hi-there")
    }

    func testSuggestedBundleId() {
        XCTAssertEqual(ProjectBootstrap.suggestedBundleId(for: "My App"),
                       "com.example.my-app")
        XCTAssertEqual(ProjectBootstrap.suggestedBundleId(for: ""),
                       "com.example.app")
    }

    func testStarterConfigShape() {
        let inputs = ProjectBootstrap.Inputs(
            projectName: "Test",
            bundleId: "com.test",
            appPath: "/Applications/Test.app")
        let cfg = ProjectBootstrap.starterConfig(for: inputs)
        XCTAssertEqual(cfg.project.name, "Test")
        XCTAssertEqual(cfg.project.bundleId, "com.test")
        XCTAssertEqual(cfg.app.path, "/Applications/Test.app")
        XCTAssertEqual(cfg.output.directory, "./release")
        XCTAssertEqual(cfg.output.dmgName, "test-${version}.dmg")
        XCTAssertEqual(cfg.output.volumeName, "Test")
        XCTAssertEqual(cfg.window?.width, 680)
        XCTAssertEqual(cfg.window?.height, 420)
        XCTAssertEqual(cfg.items?.count, 2)
        XCTAssertEqual(cfg.items?.first?.id, "app")
        XCTAssertEqual(cfg.items?.last?.id, "applications")
        XCTAssertNil(cfg.decorations,
                     "starter config seeds two items only — no default arrow")
    }

    func testProjectDirectoryRejectsEmptyName() throws {
        XCTAssertThrowsError(try ProjectBootstrap.projectDirectory(
            for: "   ",
            homeDirectory: URL(fileURLWithPath: "/tmp")
        )) { err in
            if case ProjectBootstrap.BootstrapError.emptyName = err {} else {
                XCTFail("wrong error: \(err)")
            }
        }
    }

    func testCreateWritesAndReturnsConfigURL() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("bootstrap-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: tmp,
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let inputs = ProjectBootstrap.Inputs(
            projectName: "MyApp",
            bundleId: "com.example.myapp",
            appPath: "/Applications/MyApp.app")
        let url = try ProjectBootstrap.create(inputs: inputs, homeDirectory: tmp)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.lastPathComponent, "lutin.yml")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "myapp")

        // Confirm round-trip: load it back, key fields survive.
        let reloaded = try LutinConfig.load(from: url)
        XCTAssertEqual(reloaded.project.name, "MyApp")
        XCTAssertEqual(reloaded.items?.count, 2)
    }

    func testCreateRejectsExisting() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("bootstrap-dup-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: tmp,
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let inputs = ProjectBootstrap.Inputs(
            projectName: "Dup",
            bundleId: "com.example.dup",
            appPath: "/Applications/Dup.app")
        _ = try ProjectBootstrap.create(inputs: inputs, homeDirectory: tmp)
        XCTAssertThrowsError(try ProjectBootstrap.create(inputs: inputs,
                                                         homeDirectory: tmp)) { err in
            if case ProjectBootstrap.BootstrapError.alreadyExists = err {} else {
                XCTFail("wrong error: \(err)")
            }
        }
    }
}

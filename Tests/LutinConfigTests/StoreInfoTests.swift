import XCTest
@testable import LutinConfig
import LutinCore

final class StoreInfoTests: XCTestCase {

    private func write(_ yaml: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lutin-store-\(UUID().uuidString).yml")
        try yaml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private let base = """
    project:
      name: MyApp
      bundleId: com.example.myapp
    app:
      path: ./build/MyApp.app
    output:
      directory: ./release
      dmgName: MyApp.dmg
      volumeName: MyApp
    """

    // MARK: - Backwards compatibility

    /// The overwhelmingly common case: an existing lutin.yml with no store block.
    func testConfigWithoutStoreStillDecodes() throws {
        let url = try write(base)
        defer { try? FileManager.default.removeItem(at: url) }
        let config = try LutinConfig.load(from: url)
        XCTAssertNil(config.store)
    }

    /// Every existing call site passes 10 arguments positionally. Adding the
    /// parameter must not break them.
    func testExistingInitializerCallSitesStillCompile() {
        let config = LutinConfig(
            project: .init(name: "A", bundleId: "com.a"),
            app: .init(path: "./a.app"),
            output: .init(directory: "./r", dmgName: "a.dmg", volumeName: "A"),
            window: nil, background: nil, items: nil, decorations: nil,
            signing: nil, notarization: nil, sparkle: nil)
        XCTAssertNil(config.store)
    }

    func testNilStoreIsOmittedFromEncodedYAML() throws {
        let url = try write(base)
        defer { try? FileManager.default.removeItem(at: url) }
        let config = try LutinConfig.load(from: url)
        let out = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("out-\(UUID().uuidString).yml")
        defer { try? FileManager.default.removeItem(at: out) }
        try config.save(to: out)
        let text = try String(contentsOf: out, encoding: .utf8)
        XCTAssertFalse(text.contains("store:"),
                       "A nil store must not append an empty block to every project file.")
    }

    // MARK: - Decoding

    func testStoreBlockDecodes() throws {
        let yaml = base + """

        store:
          appID: "1234567890"
          bundleID: com.example.myapp
          platform: MAC_OS
          metadataDir: store/metadata
        """
        let url = try write(yaml)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try XCTUnwrap(try LutinConfig.load(from: url).store)
        XCTAssertEqual(store.appID, "1234567890")
        XCTAssertEqual(store.bundleID, "com.example.myapp")
        XCTAssertEqual(store.resolvedPlatform, "MAC_OS")
        XCTAssertEqual(store.resolvedMetadataDir, "store/metadata")
    }

    func testDefaultsApplyWhenFieldsAreOmitted() throws {
        let url = try write(base + "\n\nstore: {}\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try XCTUnwrap(try LutinConfig.load(from: url).store)
        XCTAssertNil(store.appID)
        XCTAssertEqual(store.resolvedPlatform, StoreInfo.defaultPlatform)
        XCTAssertEqual(store.resolvedMetadataDir, StoreInfo.defaultMetadataDir)
    }

    func testRoundTripPreservesTheStoreBlock() throws {
        let yaml = base + "\n\nstore:\n  appID: \"42\"\n  platform: MAC_OS\n"
        let url = try write(yaml)
        defer { try? FileManager.default.removeItem(at: url) }
        let config = try LutinConfig.load(from: url)
        let out = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rt-\(UUID().uuidString).yml")
        defer { try? FileManager.default.removeItem(at: out) }
        try config.save(to: out)
        XCTAssertEqual(try LutinConfig.load(from: out).store, config.store)
    }

    // MARK: - Validation

    func testValidatorRejectsAnUnknownPlatform() throws {
        let url = try write(base + "\n\nstore:\n  platform: WINDOWS\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let config = try LutinConfig.load(from: url)
        let issues = ConfigValidator.validate(config)
        XCTAssertTrue(issues.contains { $0.path.contains("store.platform") })
    }

    func testValidatorAcceptsEveryDocumentedPlatform() throws {
        for platform in ["IOS", "MAC_OS", "TV_OS", "VISION_OS"] {
            let url = try write(base + "\n\nstore:\n  platform: \(platform)\n")
            defer { try? FileManager.default.removeItem(at: url) }
            let issues = ConfigValidator.validate(try LutinConfig.load(from: url))
            XCTAssertFalse(issues.contains { $0.path.contains("store.platform") },
                           "\(platform) is a documented platform and must validate.")
        }
    }

    func testValidatorRejectsAnEmptyMetadataDir() throws {
        let url = try write(base + "\n\nstore:\n  metadataDir: \"\"\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let issues = ConfigValidator.validate(try LutinConfig.load(from: url))
        XCTAssertTrue(issues.contains { $0.path.contains("store.metadataDir") })
    }
}

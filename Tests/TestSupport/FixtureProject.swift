import Foundation
import LutinConfig

/// Builds a throwaway project directory with a `lutin.yml` and a metadata tree.
public enum FixtureProject {
    public struct Handle {
        public let root: URL
        public var configURL: URL { root.appendingPathComponent("lutin.yml") }
    }

    public static func make(metadata: [String: String],
                            appID: String? = nil,
                            bundleID: String? = nil,
                            platform: String = "MAC_OS") throws -> Handle {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lutin-cli-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        var config = LutinConfig.empty(name: "MyApp", bundleId: "com.example.myapp",
                                       appPath: "./MyApp.app", outputDir: "./release",
                                       dmgName: "MyApp.dmg", volumeName: "MyApp")
        if appID != nil || bundleID != nil {
            config.store = StoreInfo(appID: appID, bundleID: bundleID, platform: platform)
        }
        try config.save(to: root.appendingPathComponent("lutin.yml"))

        for (relative, contents) in metadata {
            let url = root.appendingPathComponent("store/metadata/\(relative)")
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
        return Handle(root: root)
    }
}

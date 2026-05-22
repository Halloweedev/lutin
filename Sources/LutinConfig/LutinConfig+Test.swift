#if DEBUG
import Foundation

public extension LutinConfig {
    /// Test helper — produces a minimal config with mandatory fields filled.
    /// Optional fields default to nil so tests can populate exactly what they need.
    static func empty(name: String, bundleId: String, appPath: String,
                      outputDir: String, dmgName: String, volumeName: String) -> LutinConfig {
        LutinConfig(
            project: ProjectInfo(name: name, bundleId: bundleId),
            app: AppInfo(path: appPath),
            output: OutputInfo(directory: outputDir, dmgName: dmgName, volumeName: volumeName),
            window: nil, background: nil, items: nil, decorations: nil,
            signing: nil, notarization: nil, sparkle: nil)
    }
}
#endif

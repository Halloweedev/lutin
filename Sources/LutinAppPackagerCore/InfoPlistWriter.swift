import Foundation
import LutinCore

/// Writes a macOS `Info.plist` for a Lutin-produced `.app` bundle.
///
/// Error codes emitted:
/// - `app_packager_layout_invalid`: serialization or write failed.
public enum InfoPlistWriter {
    public static func write(_ spec: AppBundleSpec, to url: URL) throws {
        let dict: [String: Any] = [
            "CFBundleName": spec.bundleName,
            "CFBundleDisplayName": spec.bundleName,
            "CFBundleExecutable": spec.bundleName,
            "CFBundleIdentifier": spec.bundleIdentifier,
            "CFBundleVersion": spec.buildNumber,
            "CFBundleShortVersionString": spec.shortVersion,
            "CFBundlePackageType": "APPL",
            "CFBundleInfoDictionaryVersion": "6.0",
            "LSMinimumSystemVersion": spec.minimumSystemVersion,
            "NSHighResolutionCapable": true,
            "NSPrincipalClass": "NSApplication",
            "CFBundleIconFile": "AppIcon",
        ]
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
            try data.write(to: url, options: .atomic)
        } catch {
            throw LutinError(code: "app_packager_layout_invalid",
                             message: "Could not write Info.plist: \(error.localizedDescription)")
        }
    }
}

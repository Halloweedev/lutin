import Foundation
import LutinCore

/// Assembles a macOS `.app` bundle from a built binary plus a resources directory.
///
/// Layout produced:
/// ```
/// <output>/<Name>.app/
///   Contents/
///     MacOS/<Name>          (executable, 0755)
///     Resources/...         (copied from spec.resourcesURL)
///     Info.plist
/// ```
///
/// Error codes emitted:
/// - `app_packager_missing_binary`: spec.binaryURL does not exist.
/// - `app_packager_layout_invalid`: Info.plist serialization or write failed
///   (re-thrown from `InfoPlistWriter`).
public enum BundleAssembler {
    @discardableResult
    public static func assemble(_ spec: AppBundleSpec) throws -> URL {
        let fm = FileManager.default

        guard fm.fileExists(atPath: spec.binaryURL.path) else {
            throw LutinError(code: "app_packager_missing_binary",
                             message: "Binary not found at \(spec.binaryURL.path). Did `swift build -c release` run?")
        }

        let appURL = spec.outputDirectory.appendingPathComponent("\(spec.bundleName).app")
        let contents = appURL.appendingPathComponent("Contents")
        let macOS = contents.appendingPathComponent("MacOS")
        let resources = contents.appendingPathComponent("Resources")

        if fm.fileExists(atPath: appURL.path) {
            try fm.removeItem(at: appURL)
        }
        try fm.createDirectory(at: macOS, withIntermediateDirectories: true)
        try fm.createDirectory(at: resources, withIntermediateDirectories: true)

        let dest = macOS.appendingPathComponent(spec.bundleName)
        try fm.copyItem(at: spec.binaryURL, to: dest)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)

        if fm.fileExists(atPath: spec.resourcesURL.path) {
            for item in (try? fm.contentsOfDirectory(at: spec.resourcesURL,
                                                    includingPropertiesForKeys: nil)) ?? [] {
                let target = resources.appendingPathComponent(item.lastPathComponent)
                try fm.copyItem(at: item, to: target)
            }
        }

        try InfoPlistWriter.write(spec, to: contents.appendingPathComponent("Info.plist"))
        return appURL
    }
}

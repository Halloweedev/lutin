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

        // Copy resources, but route any `Assets.xcassets` through `actool`
        // (the same tool Xcode runs under the hood) so the bundle gets a
        // compiled `Assets.car` + an extracted `AppIcon.icns`, matching what
        // a real Xcode-built app produces. Anything else is copied verbatim.
        var partialPlistKeys: [String: Any] = [:]
        if fm.fileExists(atPath: spec.resourcesURL.path) {
            for item in (try? fm.contentsOfDirectory(at: spec.resourcesURL,
                                                    includingPropertiesForKeys: nil)) ?? [] {
                if item.lastPathComponent == "Assets.xcassets" {
                    partialPlistKeys = try compileAssetCatalog(
                        item, into: resources,
                        minimumDeployment: spec.minimumSystemVersion)
                } else {
                    let target = resources.appendingPathComponent(item.lastPathComponent)
                    try fm.copyItem(at: item, to: target)
                }
            }
        }

        // PkgInfo — classic macOS bundle marker. Apps without this look
        // suspect to LaunchServices / Finder; Xcode always writes it.
        try Data("APPL????".utf8).write(
            to: contents.appendingPathComponent("PkgInfo"))

        try InfoPlistWriter.write(spec, to: contents.appendingPathComponent("Info.plist"),
                                  extraKeys: partialPlistKeys)
        return appURL
    }

    /// Compiles `Assets.xcassets` into `Assets.car` + extracted icon set via
    /// `xcrun actool`. Returns the partial Info.plist fragment actool emits
    /// (icon-related keys like `CFBundleIconName`, `CFBundleIcons`, etc.).
    /// Silently falls back to a verbatim copy if actool is unavailable.
    private static func compileAssetCatalog(_ catalog: URL, into resources: URL,
                                            minimumDeployment: String) throws -> [String: Any] {
        let fm = FileManager.default
        try fm.createDirectory(at: resources, withIntermediateDirectories: true)

        let actool = "/usr/bin/xcrun"
        let partialPlist = resources.deletingLastPathComponent()
            .appendingPathComponent("actool-partial.plist")
        defer { try? fm.removeItem(at: partialPlist) }

        let proc = Process()
        proc.launchPath = actool
        proc.arguments = [
            "actool", catalog.path,
            "--compile", resources.path,
            "--platform", "macosx",
            "--minimum-deployment-target", minimumDeployment,
            "--app-icon", "AppIcon",
            "--include-all-app-icons",
            "--output-partial-info-plist", partialPlist.path,
            "--output-format", "human-readable-text",
        ]
        let stderr = Pipe()
        proc.standardError = stderr
        proc.standardOutput = Pipe()

        do {
            try proc.run()
        } catch {
            // actool not available — fall back to verbatim copy
            let target = resources.appendingPathComponent(catalog.lastPathComponent)
            try? fm.copyItem(at: catalog, to: target)
            return [:]
        }
        proc.waitUntilExit()

        if proc.terminationStatus != 0 {
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(),
                             encoding: .utf8) ?? ""
            throw LutinError(code: "app_packager_actool_failed",
                             message: "actool failed (\(proc.terminationStatus)) for "
                                + "\(catalog.path): \(err.prefix(400))")
        }

        // actool emits Resources/AppIcon-related files at the top level of
        // the catalog's output directory, plus a partial Info.plist next to
        // them. Merge that partial plist back into the main Info.plist so
        // CFBundleIconFile / CFBundleIconName resolve at runtime.
        guard fm.fileExists(atPath: partialPlist.path),
              let data = try? Data(contentsOf: partialPlist),
              let dict = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil) as? [String: Any]
        else { return [:] }
        return dict
    }
}

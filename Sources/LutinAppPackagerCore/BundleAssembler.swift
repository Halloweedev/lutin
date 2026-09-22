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
/// - `app_packager_missing_asset_catalog`: spec.assetCatalogURL does not exist.
/// - `app_packager_actool_failed`: `actool` rejected the source catalog.
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

        // The app icon and the top-level `Assets.car` can only come from the
        // *source* catalog: `actool` is what extracts `AppIcon.icns` and the
        // icon keys. The scripts hand us SwiftPM's built bundle (a compiled car
        // and nothing else), so without an explicit catalog the app would ship
        // with `CFBundleIconFile` pointing at a file that was never staged.
        if let catalog = spec.assetCatalogURL {
            guard fm.fileExists(atPath: catalog.path) else {
                throw LutinError(
                    code: "app_packager_missing_asset_catalog",
                    message: "Asset catalog not found at \(catalog.path).")
            }
            partialPlistKeys = try compileAssetCatalog(
                catalog, into: resources,
                minimumDeployment: spec.minimumSystemVersion)
        }

        if fm.fileExists(atPath: spec.resourcesURL.path) {
            if spec.resourcesURL.pathExtension == "bundle" {
                try stageResourceBundle(spec.resourcesURL, into: resources)
            } else {
                for item in (try? fm.contentsOfDirectory(at: spec.resourcesURL,
                                                         includingPropertiesForKeys: nil)) ?? [] {
                    if item.lastPathComponent == "Assets.xcassets" {
                        // Compile a catalog found by convention only when the
                        // caller did not already supply one explicitly.
                        guard spec.assetCatalogURL == nil else { continue }
                        partialPlistKeys = try compileAssetCatalog(
                            item, into: resources,
                            minimumDeployment: spec.minimumSystemVersion)
                    } else {
                        let target = resources.appendingPathComponent(item.lastPathComponent)
                        try fm.copyItem(at: item, to: target)
                    }
                }
            }
        }

        // PkgInfo — classic macOS bundle marker. Apps without this look
        // suspect to LaunchServices / Finder; Xcode always writes it.
        try Data("APPL????".utf8).write(
            to: contents.appendingPathComponent("PkgInfo"))

        try InfoPlistWriter.write(spec, to: contents.appendingPathComponent("Info.plist"),
                                  extraKeys: partialPlistKeys)

        // Make the bundle self-contained: embed any @rpath framework the
        // binary links against (e.g. KeylightSDK) and add the Frameworks
        // rpath. Frameworks are sought next to the source binary in the build
        // dir. No-op for binaries with no @rpath framework deps.
        try FrameworkEmbedder.embed(
            appBundle: appURL,
            binaryName: spec.bundleName,
            searchDirectory: spec.binaryURL.deletingLastPathComponent())

        return appURL
    }

    /// Stages the built `<Package>_<Target>.bundle` the dev and release scripts
    /// hand us, so `Bundle.module` resolves at runtime.
    ///
    /// The generated accessor looks for that bundle under the app's
    /// `Contents/Resources/`, and its lookup ends in a `fatalError` — so a
    /// bundle that is not staged there crashes the app on the first asset
    /// lookup, before any window appears (issue #2: `_assertionFailure` in
    /// `NSBundle.module`, reached from `Tokens.nsColor`).
    ///
    /// SwiftPM's own layout is kept (compiled `Assets.car` under the bundle's
    /// `Contents/Resources/`), minus its build-time signature; the compiled car
    /// is mirrored at the top level where the app-icon and legacy lookups
    /// expect it.
    private static func stageResourceBundle(_ bundle: URL, into resources: URL) throws {
        let fm = FileManager.default
        let staged = resources.appendingPathComponent(bundle.lastPathComponent, isDirectory: true)
        if fm.fileExists(atPath: staged.path) { try fm.removeItem(at: staged) }

        try fm.copyItem(at: bundle, to: staged)
        try? fm.removeItem(at: staged.appendingPathComponent("Contents/_CodeSignature"))

        let topLevelCar = resources.appendingPathComponent("Assets.car")
        if let car = resourceCar(in: staged), !fm.fileExists(atPath: topLevelCar.path) {
            try fm.copyItem(at: car, to: topLevelCar)
        }
    }

    /// The compiled asset catalog inside a resource bundle, in either layout
    /// SwiftPM has produced (nested `Contents/Resources/` or flat).
    private static func resourceCar(in bundle: URL) -> URL? {
        let candidates = [bundle.appendingPathComponent("Contents/Resources/Assets.car"),
                          bundle.appendingPathComponent("Assets.car")]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
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

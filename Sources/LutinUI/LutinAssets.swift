import Foundation

/// Smart bundle accessor for LutinUI image assets.
///
/// SwiftPM's auto-generated `Bundle.module` looks for the resource
/// bundle at `Bundle.main.bundleURL/Lutin_LutinUI.bundle` — i.e. at
/// the top level of the `.app`. That path violates macOS bundle
/// structure (codesign rejects "unsealed contents present in the
/// bundle root"), so the packager places the bundle inside
/// `Contents/Resources/` instead. The auto-generated accessor then
/// falls back to the hardcoded build-dir path, which contains
/// **uncompiled** `Assets.xcassets` — SwiftUI's `Image(_:bundle:)`
/// can't load assets from an uncompiled catalog, so every
/// `Image("Foo", bundle: .module)` silently renders nothing.
///
/// `LutinAssets.bundle` checks the codesign-safe location first and
/// falls back to `Bundle.module` for `swift test` / `swift run`
/// contexts where the SPM convention does work.
public enum LutinAssets {
    public static let bundle: Bundle = {
        let candidates: [URL] = [
            // macOS .app layout (what the packager produces)
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/Lutin_LutinUI.bundle"),
            // SPM "next to executable" convention (where Bundle.module
            // already looks first; included for completeness)
            Bundle.main.bundleURL.appendingPathComponent("Lutin_LutinUI.bundle"),
        ]
        for url in candidates {
            if FileManager.default.fileExists(atPath: url.path),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }
        // swift test / swift run: SPM's accessor finds the build dir.
        return .module
    }()
}

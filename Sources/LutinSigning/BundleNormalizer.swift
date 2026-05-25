import Foundation
import LutinCore

/// Pre-signing fix-up for app bundles whose layout doesn't match
/// codesign's expectations.
///
/// The case we handle: SwiftPM produces resource bundles named
/// `<Package>_<Target>.bundle` and, in some build pipelines, those
/// end up at the **root** of the `.app` directory instead of under
/// `Contents/Resources/`. macOS codesign refuses to seal an app
/// whose root contains anything other than `Contents/`, failing
/// with "unsealed contents present in the bundle root" — even
/// though the underlying app is otherwise valid.
///
/// We detect SwiftPM resource bundles by their structural shape
/// (a `Resources/` child and no `Contents/` child) rather than by
/// the `_` naming convention, so a custom-named resource bundle in
/// the same broken position still gets relocated.
public enum BundleNormalizer {
    /// Moves any SwiftPM-style resource bundle found at the root of
    /// `appBundle` into `Contents/Resources/`. Reports each move via
    /// `onOutput`. Throws `bundle_relocation_conflict` if a file with
    /// the same name already exists at the destination.
    public static func normalize(_ appBundle: URL,
                                 onOutput: ((String) -> Void)? = nil) throws {
        let fm = FileManager.default
        let resourcesDir = appBundle
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)

        guard let items = try? fm.contentsOfDirectory(
            at: appBundle, includingPropertiesForKeys: nil) else { return }

        for item in items {
            if item.lastPathComponent == "Contents" { continue }
            guard item.pathExtension == "bundle" else { continue }

            let hasResources = fm.fileExists(
                atPath: item.appendingPathComponent("Resources").path)
            let hasContents = fm.fileExists(
                atPath: item.appendingPathComponent("Contents").path)
            // Only relocate SwiftPM-style resource bundles. A real macOS
            // bundle with Contents/ at the root of the .app would be a
            // separate problem we shouldn't silently paper over.
            guard hasResources, !hasContents else { continue }

            if !fm.fileExists(atPath: resourcesDir.path) {
                try fm.createDirectory(at: resourcesDir,
                                       withIntermediateDirectories: true)
            }

            let destination = resourcesDir
                .appendingPathComponent(item.lastPathComponent)
            if fm.fileExists(atPath: destination.path) {
                throw LutinError(
                    code: "bundle_relocation_conflict",
                    message: "Cannot move \(item.lastPathComponent) into "
                           + "Contents/Resources/ — a file with that name "
                           + "already exists at \(destination.path).",
                    details: ["source": item.path,
                              "destination": destination.path])
            }
            try fm.moveItem(at: item, to: destination)
            onOutput?(
                "Relocated \(item.lastPathComponent) from app root → "
                + "Contents/Resources/ (codesign requires a clean bundle root)."
            )
        }
    }
}

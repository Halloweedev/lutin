import Foundation
import LutinConfig

/// Every LutinConfig field that the editor exposes. The schema-coverage
/// test compares this against the actual struct using Mirror; new fields
/// not in this set fail the test, forcing either an editor surface or an
/// explicit entry here.
public enum SchemaCoverage {
    public static let coveredFields: Set<String> = [
        "project.name", "project.bundleId",
        "app.path",
        "output.directory", "output.dmgName", "output.volumeName",
        "window.width", "window.height", "window.iconSize",
        "window.textSize", "window.showToolbar", "window.showSidebar",
        "background.type", "background.template", "background.path",
        "background.scale", "background.colorA", "background.colorB",
        "background.angle", "background.grid", "background.noise",
        "background.cornerRadius",
        "items.type", "items.id", "items.x", "items.y", "items.label", "items.hidden",
        "decorations.type",
        "decorations.path", "decorations.x", "decorations.y", "decorations.width",
        "decorations.height", "decorations.label", "decorations.hidden",
        "signing.enabled", "signing.identity", "signing.hardenedRuntime",
        "signing.entitlements", "signing.signDmg",
        "notarization.enabled", "notarization.profile", "notarization.staple",
        "sparkle.enabled", "sparkle.appcastPath",
        "sparkle.releaseNotesDirectory", "sparkle.downloadBaseURL",
    ]

    public static func fieldsFromConfig(_ config: LutinConfig) -> Set<String> {
        var result: Set<String> = []
        walk(prefix: "", mirror: Mirror(reflecting: config), into: &result)
        return result
    }

    private static func walk(prefix: String, mirror: Mirror, into result: inout Set<String>) {
        for child in mirror.children {
            guard let label = child.label else { continue }
            let path = prefix.isEmpty ? label : "\(prefix).\(label)"
            let m = Mirror(reflecting: child.value)
            if m.displayStyle == .optional, let some = m.children.first?.value {
                walkValue(path: path, value: some, into: &result); continue
            }
            // If the optional is `nil`, we still need to record the field — by
            // synthesizing a minimal instance of the wrapped type. The simplest
            // path: walk the schema based on the static type system isn't
            // possible at runtime without an instance. The chosen pragma is:
            // if a field is nil at runtime, skip it; the manifest test will
            // hand-trip on missing fields when the seed config has them
            // populated. To get full coverage, the test below uses an instance
            // with EVERY optional populated (see SchemaCoverageTests).
            walkValue(path: path, value: child.value, into: &result)
        }
    }

    private static func walkValue(path: String, value: Any, into result: inout Set<String>) {
        let m = Mirror(reflecting: value)
        switch m.displayStyle {
        case .struct, .class:
            walk(prefix: path, mirror: m, into: &result)
        case .collection:
            if let elem = m.children.first?.value {
                let em = Mirror(reflecting: elem)
                for sub in em.children {
                    guard let label = sub.label else { continue }
                    result.insert("\(path).\(label)")
                }
            } else {
                result.insert(path)
            }
        default:
            result.insert(path)
        }
    }
}

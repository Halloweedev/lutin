import Foundation
import LutinCore

/// Signs an app bundle inner-to-outer using `codesign`.
public enum CodeSigner {
    /// Nested code items inside an app bundle that must be signed before the
    /// top-level bundle, returned deepest-first.
    public static func nestedCodePaths(in appBundle: URL) -> [URL] {
        let fm = FileManager.default
        let signableExtensions: Set<String> = ["framework", "dylib", "app", "xpc", "bundle", "appex"]
        var found: [URL] = []
        if let walker = fm.enumerator(at: appBundle,
                                      includingPropertiesForKeys: nil,
                                      options: []) {
            for case let url as URL in walker {
                if signableExtensions.contains(url.pathExtension) {
                    found.append(url)
                }
            }
        }
        // Deepest paths first, so children sign before their parents.
        return found.sorted { $0.pathComponents.count > $1.pathComponents.count }
    }
}

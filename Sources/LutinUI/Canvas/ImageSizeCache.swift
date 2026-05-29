import AppKit
import Foundation

/// Process-wide cache of decoded source-image sizes, keyed by resolved file
/// path. Off-canvas detection and drag math need a decoration's source aspect
/// ratio on every canvas re-render; without caching, each call re-decodes the
/// PNG from disk via `NSImage(contentsOf:)`, which janks during a drag (the
/// owning views recompute every frame). Accessed only from SwiftUI bodies /
/// gestures on the main thread.
enum ImageSizeCache {
    private static var sizes: [String: CGSize] = [:]

    /// Decoded source pixel size for `path` resolved against `base`, memoized
    /// by resolved path. Returns nil when the file can't be decoded.
    static func size(ofPath path: String, relativeTo base: URL) -> CGSize? {
        let url = URL(fileURLWithPath: path, relativeTo: base).standardizedFileURL
        if let cached = sizes[url.path] { return cached }
        guard let ns = NSImage(contentsOf: url), ns.size.width > 0 else { return nil }
        sizes[url.path] = ns.size
        return ns.size
    }

    /// Source aspect ratio (height / width); returns nil when undecodable.
    static func aspect(ofPath path: String, relativeTo base: URL) -> CGFloat? {
        guard let s = size(ofPath: path, relativeTo: base) else { return nil }
        return s.height / s.width
    }
}

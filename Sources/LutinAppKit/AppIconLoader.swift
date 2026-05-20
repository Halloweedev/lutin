import AppKit
import CoreGraphics
import Foundation

/// Loads the macOS Finder icon for a given file URL. Used by the canvas to
/// show the real .app icon (and the real /Applications folder icon) instead
/// of a stylized placeholder — so the GUI canvas matches what Finder shows
/// when the assembled DMG is mounted.
///
/// Returns `nil` when the path doesn't exist or the icon can't be rasterized
/// at the requested size. Callers should fall back to a placeholder glyph.
public enum AppIconLoader {
    /// Icon for the macOS `/Applications` folder alias that ships in DMGs.
    public static func applicationsFolderIcon(sizePoints: Int) -> CGImage? {
        icon(at: URL(fileURLWithPath: "/Applications"), sizePoints: sizePoints)
    }

    /// Icon for a `.app` bundle at the given URL. Missing paths return `nil`.
    public static func appBundleIcon(at url: URL, sizePoints: Int) -> CGImage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return icon(at: url, sizePoints: sizePoints)
    }

    private static func icon(at url: URL, sizePoints: Int) -> CGImage? {
        let nsImage = NSWorkspace.shared.icon(forFile: url.path)
        let size = max(16, sizePoints)
        let target = NSSize(width: size, height: size)
        nsImage.size = target
        var rect = NSRect(origin: .zero, size: target)
        return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}

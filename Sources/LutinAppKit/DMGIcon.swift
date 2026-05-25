import AppKit
import Foundation

/// Applies a custom Finder icon to a file (typically a `.dmg`) using
/// AppKit's `NSWorkspace.setIcon` API. The icon is stored as a
/// `com.apple.ResourceFork` extended attribute and the file's Finder
/// flags are updated so Finder renders the custom icon instead of the
/// default disk-image card.
///
/// This is what makes `daub-2.0.0.dmg` appear in Finder with the app's
/// own icon. The mounted volume's icon is handled separately by
/// `DMGBuilder` (`.VolumeIcon.icns` + `SetFile -a C`).
///
/// `NSWorkspace.setIcon` documented as main-thread; callers running on
/// background queues must hop to the main actor first.
public enum DMGIcon {
    /// Sets the icon at `iconURL` (typically an `.icns`) as the file
    /// icon of `fileURL`. Returns `false` silently if the icon can't be
    /// loaded or the metadata write is rejected.
    @MainActor
    @discardableResult
    public static func apply(iconURL: URL, to fileURL: URL) -> Bool {
        guard let image = NSImage(contentsOf: iconURL) else { return false }
        return NSWorkspace.shared.setIcon(image,
                                          forFile: fileURL.path,
                                          options: [])
    }
}

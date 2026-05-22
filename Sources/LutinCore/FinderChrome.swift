import Foundation

/// Heights, in window points, of the chrome Finder adds *around* a DMG's icon
/// view content area.
///
/// `lutin.yml`'s `window.width × window.height` describes the **content area**
/// — the canvas a user designs their background for. The `.DS_Store`'s
/// `WindowBounds`, by contrast, is the *outer window frame* including the
/// title bar and (on macOS 26 Tahoe) the always-on volume-name strip at the
/// bottom. To deliver the contract "the size the user specifies is the size
/// the background fills in the DMG window", every site that:
///
///   * renders the background PNG, or
///   * writes `WindowBounds` to the `.DS_Store`,
///
/// reads these constants from this single source of truth so the two sides
/// stay in lock-step.
///
/// The numbers below were measured by pixel-walking a freshly mounted DMG on
/// macOS 26 Tahoe (title bar with traffic lights ~28 pt; the always-on bottom
/// volume-name strip including its divider ~26 pt — the bottom strip is *not*
/// disable-able via `ShowStatusBar`/`ShowPathbar`). The budget is deliberately
/// set at or slightly above the measured chrome so the user's background
/// always fits the content area; on a system where chrome is a couple of
/// points less, the cost is a thin white band below the background rather
/// than the background spilling under the footer. **Always err on the side
/// of over-budgeting** — overflow looks broken, a tiny gap doesn't.
public enum FinderChrome {
    public static let titleBarHeightPoints = 28
    public static let bottomChromeHeightPoints = 26
    public static var totalHeightPoints: Int {
        titleBarHeightPoints + bottomChromeHeightPoints
    }
}

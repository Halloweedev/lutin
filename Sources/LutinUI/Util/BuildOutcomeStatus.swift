import SwiftUI
import LutinRegistry

/// Maps a `RegistryEntry`'s build outcome (and optional missing-on-disk
/// override) to a `StatusKind` for the UI. Single source of truth shared
/// by the Welcome recents card and the Switcher modal row — keep the
/// switch here so the two surfaces never drift.
///
/// `.failed` → `.warn` (not `.blocked`) intentionally: a failed build is
/// recoverable; the user just needs to look at the log. `.blocked` is
/// reserved for state that prevents the next build from running at all
/// (e.g. missing-on-disk, no signing identity).
enum RegistryEntryStatusKind {
    static func resolve(entry: RegistryEntry, isMissingOnDisk: Bool) -> StatusKind {
        if isMissingOnDisk { return .blocked }
        switch entry.lastBuildOutcome {
        case .succeeded: return .ok
        case .failed:    return .warn
        case .unsigned:  return .inactive
        case .none:      return .inactive
        }
    }
}

extension StatusKind {
    /// Convenience: when a status needs to render as a colored Circle
    /// dot, prefer `.dotColor` over reaching for `.color` so the call
    /// site reads "what color is the dot" rather than "what color is the
    /// thing the kind happens to map to".
    var dotColor: Color { color }
}

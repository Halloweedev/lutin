import Foundation

/// Pure policy. No side effects, no I/O, no SDK dependency — the UI layer
/// passes in `isEntitled` (from `Keylight.manager.isEntitled`), the project
/// count (from `Registry.allEntries().count`), and the last-nag date (from
/// `PreferencesStore`).
///
/// Keeping the gate dependency-free means every branch is trivially
/// unit-testable and the file does not have to evolve when the Keylight
/// SDK version changes.
public enum LicenseGate {
    /// Free tier ceiling. Creating an 11th project requires Pro.
    public static let freeProjectCap = 10

    /// How often the non-blocking "support development" sheet may
    /// re-appear for free-tier users.
    public static let supportNagInterval: TimeInterval = 30 * 24 * 60 * 60

    /// Whether the user may create another project. Pro is always
    /// allowed; free tier caps at `freeProjectCap`.
    public static func canCreateProject(projectCount: Int, isEntitled: Bool) -> Bool {
        if isEntitled { return true }
        return projectCount < freeProjectCap
    }

    /// Whether to show the 30-day support nag right now. Pro users
    /// never see it; free users see it on first launch (when
    /// `lastShown` is nil) and again every `supportNagInterval`.
    public static func shouldShowSupportNag(lastShown: Date?, isEntitled: Bool,
                                            now: Date = Date()) -> Bool {
        if isEntitled { return false }
        guard let lastShown else { return true }
        return now.timeIntervalSince(lastShown) >= supportNagInterval
    }
}

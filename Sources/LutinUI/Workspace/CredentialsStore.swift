import Foundation
import AppKit
import Observation

/// App-level cache of credentials discovered from the user's system:
/// Developer ID signing identities (from the Keychain) and notarytool
/// keychain profiles. Runs both probes once at launch, then refreshes
/// on demand (manual ↻ button) and automatically when the app regains
/// focus (so alt-tabbing back from Keychain Access or Terminal picks up
/// what you just added).
///
/// Why a store and not per-view `.task` calls:
///
/// 1. The Welcome screen + Doctor + Release tab all need the same data;
///    re-probing in each is wasteful and the views can disagree (e.g.
///    Release tab says identity X is gone but Doctor still shows it).
/// 2. Probing at launch means we can show a "no identities found" hint
///    on the Welcome screen before any project is open — surfacing the
///    setup gap as early as possible.
///
/// The store does *not* manage credentials — it only reads them. Adding
/// a Developer ID certificate is a Keychain Access / `security import`
/// flow; creating a notarytool profile is `xcrun notarytool
/// store-credentials` (the in-app sheet shells out to that command).
@MainActor
@Observable
public final class CredentialsStore {
    public private(set) var identities: [IdentityProbe.Identity] = []
    public private(set) var lastProbedAt: Date?
    public private(set) var isProbing: Bool = false
    public private(set) var hasCodesign: Bool = false
    //
    // Notary profile discovery deliberately omitted. We can't probe it
    // reliably — notarytool stores credentials with an ACL restricted
    // to its own signing team, and third-party apps (including Lutin)
    // get errSecItemNotFound for every `SecItemCopyMatching` shape,
    // regardless of partition or query. The UI surfaces profiles
    // through `PreferencesStore.knownNotaryProfiles` (positive
    // tracking of what Lutin observed at creation time) and
    // `NotaryProbe.test(...)` (definitive shell-out to notarytool on
    // demand, behind a "Test" button).

    public init() {
        // Eager initial probe — the @Observable framework lets late
        // subscribers see the latest value even if they bind after the
        // probe finishes, so we don't need to defer until first read.
        hasCodesign = Self.probeCodesignAvailability()
        Task { await refresh() }
        observeAppActivation()
    }

    /// Re-runs both probes. Idempotent and cheap (~50ms per call on a
    /// warm system); safe to call from the refresh button or in
    /// response to app-activation notifications. Sequenced as two
    /// independent off-main calls so the UI doesn't hitch.
    public func refresh() async {
        guard !isProbing else { return }
        isProbing = true
        defer { isProbing = false }
        identities = await Task.detached(priority: .userInitiated) {
            IdentityProbe.run()
        }.value
        lastProbedAt = Date()
    }

    /// True when the user has no Developer ID Application identity in
    /// their Keychain — surfaced on the Welcome screen so the gap is
    /// visible before a project is even open.
    public var hasNoDeveloperIDIdentity: Bool {
        !identities.contains { $0.name.contains("Developer ID Application:") }
    }

    // `hasNoNotaryProfile` was removed — see the comment above the
    // `identities` field. The Welcome banner now only flags missing
    // signing identities, which we *can* detect via `security
    // find-identity`. Notary profile presence is surfaced through
    // `PreferencesStore.knownNotaryProfiles` (Lutin-created) and an
    // explicit Test button (definitive).

    // MARK: - App activation hook

    private func observeAppActivation() {
        // Re-probe whenever the user brings Lutin back to the front —
        // covers the workflow "alt-tab to Keychain Access, import a
        // cert, alt-tab back". `didBecomeActiveNotification` fires for
        // both initial launch (filtered out by our `lastProbedAt`
        // throttle) and subsequent activations.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // NotificationCenter's queue:.main delivers on the main
            // thread, but the closure type is non-isolated Sendable —
            // hop onto the MainActor explicitly so property reads /
            // refresh calls are typechecked under our isolation.
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Throttle: skip if we probed less than 2 seconds ago.
                // Prevents a launch-time activation from triggering a
                // second redundant probe before the eager one finishes.
                if let last = self.lastProbedAt,
                   Date().timeIntervalSince(last) < 2 {
                    return
                }
                await self.refresh()
            }
        }
    }

    private static func probeCodesignAvailability() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--version"]
        let nullHandle = FileHandle(forWritingAtPath: "/dev/null")
        process.standardOutput = nullHandle
        process.standardError = nullHandle
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

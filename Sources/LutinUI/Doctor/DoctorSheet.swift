import SwiftUI
import LutinCore
import LutinSigning
import LutinNotarization
import LutinDocument

public struct DoctorSheet: View {
    let document: LutinProjectDocument?
    @Environment(\.dismiss) private var dismiss
    @Environment(CredentialsStore.self) private var credentialsStore
    @Environment(PreferencesStore.self) private var preferencesStore
    @State private var results: [Check] = []
    @State private var running: Bool = false

    public init(document: LutinProjectDocument?) {
        self.document = document
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.lg)) {
            HStack {
                Text("Doctor").font(.title2.weight(.semibold))
                Spacer()
                LutinButton("Re-run") { Task { await runChecks() } }.disabled(running)
                LutinButton("Done", role: .primary) { dismiss() }
            }
            if results.isEmpty && !running {
                EmptyState(title: "Run checks to begin",
                           message: "Doctor inspects code-signing identity, notary profile, and bundle structure.",
                           icon: "DoctorAllClear")
            }
            if running {
                ProgressView("Running checks…")
            }
            ForEach(results) { check in CheckRow(check: check) }
        }
        .padding(Tokens.spacing(.xl))
        .frame(minWidth: 520, minHeight: 360)
        .task { await runChecks() }
    }

    struct Check: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let status: StatusKind  // shared with the rest of the app —
                                 // see `TabComponents.StatusKind`.
    }

    private func runChecks() async {
        running = true
        var collected: [Check] = []

        collected.append(signingCheck())
        collected.append(notaryCheck())

        if let document {
            let appURL = URL(fileURLWithPath: document.config.app.path,
                             relativeTo: document.projectDirectory)
            if FileManager.default.fileExists(atPath: appURL.path) {
                collected.append(.init(title: "App bundle exists",
                                       detail: appURL.path, status: .ok))
            } else {
                collected.append(.init(title: "App bundle missing",
                                       detail: "Expected at \(appURL.path)", status: .blocked))
            }
        }

        results = collected
        running = false
    }

    /// Signing-identity check. Four states, ordered most-helpful to
    /// least: configured-and-present, configured-but-stale (in YAML but
    /// no longer in Keychain), unconfigured-with-options (Keychain has
    /// identities; pick one), unconfigured-and-empty (Keychain is bare;
    /// import a `.cer`).
    private func signingCheck() -> Check {
        let availableNames = credentialsStore.identities.map(\.name)
        let developerIDNames = availableNames.filter {
            $0.contains("Developer ID Application:")
        }

        guard let document else {
            if developerIDNames.isEmpty {
                return .init(
                    title: "No Developer ID identity available",
                    detail: "No Developer ID Application identities found in the Keychain.",
                    status: .warn)
            }
            return .init(
                title: "Developer ID identity available",
                detail: "\(developerIDNames.count) Developer ID identity \(developerIDNames.count == 1 ? "is" : "are") available in your Keychain.",
                status: .ok)
        }

        let signing = document.config.signing

        if let signing, signing.enabled, let identity = signing.identity {
            if availableNames.contains(identity) {
                return .init(title: "Signing identity present",
                             detail: identity, status: .ok)
            }
            return .init(
                title: "Signing identity not in Keychain",
                detail: "'\(identity)' is in your project config but isn't installed on this machine. Pick another in the Release tab or import the certificate via Open Keychain.",
                status: .blocked)
        }
        if availableNames.isEmpty {
            return .init(
                title: "No signing identity available",
                detail: "No codesigning identities found in the Keychain. Click 'Open Keychain' in the Release tab to import a Developer ID Application certificate.",
                status: .warn)
        }
        return .init(
            title: "Signing identity not selected",
            detail: "\(availableNames.count) identity \(availableNames.count == 1 ? "is" : "are") available in your Keychain. Pick one in the Release tab → Signing → Identity.",
            status: .warn)
    }

    /// Notary-profile check. notarytool's keychain entries are
    /// ACL-restricted to its signing team — Lutin can't query them
    /// directly to verify a profile name is real. We only have two
    /// sources of truth:
    ///
    /// 1. `PreferencesStore.knownNotaryProfiles` — names Lutin saw at
    ///    creation time. Positive-only signal.
    /// 2. `xcrun notarytool history --keychain-profile …` — definitive
    ///    but slow (network). Triggered from the Test button in the
    ///    Release tab, not from Doctor.
    ///
    /// So this check is intentionally less assertive than the signing
    /// one: a recorded name gets a green check; an unrecorded name
    /// gets a yellow warn with a clear "this might be fine, press
    /// Test to confirm" hint.
    private func notaryCheck() -> Check {
        let known = preferencesStore.preferences.knownNotaryProfiles

        guard let document else {
            if known.isEmpty {
                return .init(
                    title: "No notary profile remembered",
                    detail: "Lutin has not observed any notary profile creations on this machine.",
                    status: .warn)
            }
            return .init(
                title: "Notary profile remembered",
                detail: "Lutin remembers these profiles: \(known.joined(separator: ", ")).",
                status: .ok)
        }

        let notary = document.config.notarization

        if let notary, notary.enabled,
           let profile = notary.profile, !profile.isEmpty {
            if known.contains(profile) {
                return .init(title: "Notary profile configured",
                             detail: "Lutin remembers creating '\(profile)' on this machine.",
                             status: .ok)
            }
            return .init(
                title: "Notary profile unverified",
                detail: "'\(profile)' may or may not exist — Lutin didn't create it (or doesn't remember doing so), and notarytool's keychain entries are ACL-locked to Apple's signing team so we can't query them directly. Press Test in Release tab → Notarization → Profile to ask notarytool itself.",
                status: .warn)
        }
        if known.isEmpty {
            return .init(
                title: "No notary profile remembered",
                detail: "Lutin hasn't observed any profile creations on this machine. If you already have one (e.g. created via Terminal), type its name in the Release tab and press Test — notarytool will confirm. Otherwise click 'New profile…' to create one.",
                status: .warn)
        }
        return .init(
            title: "Notary profile not selected",
            detail: "Lutin remembers these profiles: \(known.joined(separator: ", ")). Type one in Release tab → Notarization → Profile, or press Test there to verify a different name.",
            status: .warn)
    }
}

private struct CheckRow: View {
    let check: DoctorSheet.Check
    var body: some View {
        HStack(alignment: .top, spacing: Tokens.spacing(.md)) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(check.title).font(.headline)
                Text(check.detail)
                    .font(Typography.chromeSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Tokens.spacing(.sm))
    }

    /// Status glyph + color sourced from the shared `StatusKind` token
    /// — same color/icon the inline `StatusRow` would draw for an
    /// equivalent state in the Release tab. One enum, one mapping.
    @ViewBuilder private var icon: some View {
        Image(systemName: check.status.systemImage)
            .foregroundStyle(check.status.color)
    }
}

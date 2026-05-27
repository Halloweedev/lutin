import SwiftUI
import AppKit
import UniformTypeIdentifiers
import LutinConfig
import LutinDocument

public struct ReleaseTab: View {
    @Bindable var document: LutinProjectDocument
    /// App-level credentials cache. Populated at launch and refreshed
    /// automatically on app activation (see `CredentialsStore`); there's
    /// no manual refresh affordance in this tab anymore — the New-profile
    /// sheet writes its result back via its callback, and bringing Lutin
    /// to the front re-probes identities.
    @Environment(CredentialsStore.self) private var credentialsStore
    @State private var showingCreateProfile = false

    public init(document: LutinProjectDocument) { self.document = document }

    public var body: some View {
        TabBody {
            signingSection
            notarizationSection
        }
        .sheet(isPresented: $showingCreateProfile) {
            NotaryProfileSheet { newName in
                // Auto-select the just-created profile in the
                // Notarization field. The sheet already persisted the
                // name to `knownNotaryProfiles`, so writing it here
                // makes the dropdown light up and the field's "saved"
                // flash fire — no retyping.
                var n = currentNotarization(); n.profile = newName
                try? document.apply(.setNotarization(n))
            }
        }
    }

    private var identities: [IdentityProbe.Identity] { credentialsStore.identities }

    /// Hands off to Keychain Access — the canonical place to import a
    /// Developer ID Application certificate. Lutin can't safely become
    /// a CA / cert-importer (private-key handling is delicate); the
    /// honest path is to deep-link the user to the system tool that
    /// owns this flow.
    ///
    /// Resolves the app via LaunchServices' bundle-identifier lookup
    /// rather than a hardcoded path. Earlier hardcoded
    /// `/System/Applications/Utilities/Keychain Access.app`, which is
    /// where it lived through macOS 14 Sonoma — macOS 15 Sequoia
    /// relocated it to `/System/Library/CoreServices/Applications/` and
    /// the hardcoded path silently no-ops. Bundle-id lookup is
    /// version-agnostic.
    private func openKeychainAccess() {
        let id = "com.apple.keychainaccess"
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            NSWorkspace.shared.open(url)
            return
        }
        // Fallback chain in case bundle-id lookup fails (a stripped
        // installation that hasn't registered the app with
        // LaunchServices, etc.). Listed newest path first.
        for candidate in [
            "/System/Library/CoreServices/Applications/Keychain Access.app",
            "/System/Applications/Utilities/Keychain Access.app",
            "/Applications/Utilities/Keychain Access.app",
        ] {
            if FileManager.default.fileExists(atPath: candidate) {
                NSWorkspace.shared.open(URL(fileURLWithPath: candidate))
                return
            }
        }
    }

    // MARK: - Signing

    private var signingEnabled: Bool { document.config.signing?.enabled ?? false }

    private var signingSection: some View {
        let verdict = ReleaseStatusKind.signing(document.config.signing)
        return SettingsSection("Signing", headerMeta: {
            statusPill(verdict)
        }) {
            SettingsRow("Enabled",
                        helper: "Codesign the .app and the DMG before notarization.") {
                LutinToggle("", isOn: Binding(
                    get: { signingEnabled },
                    set: { v in
                        var s = currentSigning()
                        s.enabled = v
                        if v, (s.identity ?? "").isEmpty {
                            let devIDs = identities.filter {
                                $0.name.contains("Developer ID Application:")
                            }
                            if devIDs.count == 1 { s.identity = devIDs[0].name }
                        }
                        try? document.apply(.setSigning(s))
                    }))
            }
            Group {
                SettingsRow("Identity",
                            helper: identities.isEmpty
                                ? "No Developer ID identities found in the Keychain."
                                : nil) {
                    HStack(spacing: Tokens.spacing(.sm)) {
                        LutinPicker(
                            selection: Binding(
                                get: { document.config.signing?.identity ?? "" },
                                set: { v in
                                    var s = currentSigning()
                                    s.identity = v.isEmpty ? nil : v
                                    try? document.apply(.setSigning(s))
                                }),
                            options: [.init(id: "", label: "Not set")]
                                + identities.map { .init(id: $0.name, label: $0.name) }
                        )
                        if identities.isEmpty {
                            LutinButton("Open Keychain") { openKeychainAccess() }
                        }
                    }
                    .frame(maxWidth: 260)
                }
                SettingsRow("Hardened runtime",
                            helper: "Required for notarization.") {
                    LutinToggle("", isOn: Binding(
                        get: { document.config.signing?.hardenedRuntime ?? false },
                        set: { v in
                            var s = currentSigning(); s.hardenedRuntime = v
                            try? document.apply(.setSigning(s))
                        }))
                }
                SettingsRow("Sign DMG",
                            helper: "Also codesign the .dmg artifact.") {
                    LutinToggle("", isOn: Binding(
                        get: { document.config.signing?.signDmg ?? false },
                        set: { v in
                            var s = currentSigning(); s.signDmg = v
                            try? document.apply(.setSigning(s))
                        }))
                }
                SettingsRow("Entitlements") {
                    HStack(spacing: Tokens.spacing(.sm)) {
                        PathPickerRow(value: entitlementsDisplayPath,
                                      placeholder: "No .entitlements file",
                                      onPick: pickEntitlements)
                        if !(document.config.signing?.entitlements ?? "").isEmpty {
                            LutinIconButton(systemName: "xmark.circle",
                                            accessibilityLabel:
                                                "Clear entitlements") {
                                var s = currentSigning(); s.entitlements = nil
                                try? document.apply(.setSigning(s))
                            }
                        }
                    }
                    .frame(maxWidth: 260)
                }
            }
            .disabled(!signingEnabled)
            .opacity(signingEnabled ? 1.0 : 0.45)

            signingStatusRow
        }
    }

    // MARK: - Notarization

    private var notarizationEnabled: Bool { document.config.notarization?.enabled ?? false }

    private var notarizationSection: some View {
        let verdict = ReleaseStatusKind.notarization(
            document.config.notarization,
            signingHardenedRuntime:
                document.config.signing?.hardenedRuntime ?? false)
        return SettingsSection("Notarization", headerMeta: {
            statusPill(verdict)
        }) {
            SettingsRow("Enabled",
                        helper: "Submit to Apple after signing and wait for the ticket.") {
                LutinToggle("", isOn: Binding(
                    get: { notarizationEnabled },
                    set: { v in
                        var n = currentNotarization()
                        n.enabled = v
                        // First-enable default: Staple on so the user
                        // doesn't need a second deliberate toggle to reach
                        // a green state.
                        if v, n.staple == nil { n.staple = true }
                        try? document.apply(.setNotarization(n))
                    }))
            }
            Group {
                SettingsRow("Profile") {
                    NotaryProfileField(
                        name: Binding(
                            get: { document.config.notarization?.profile ?? "" },
                            set: { v in
                                var n = currentNotarization()
                                n.profile = v.isEmpty ? nil : v
                                try? document.apply(.setNotarization(n))
                            }),
                        onCreateNew: { showingCreateProfile = true }
                    )
                    .frame(maxWidth: 260)
                }
                SettingsRow("Staple",
                            helper: "Attach the notarization ticket so Gatekeeper can verify offline.") {
                    LutinToggle("", isOn: Binding(
                        get: { document.config.notarization?.staple ?? false },
                        set: { v in
                            var n = currentNotarization(); n.staple = v
                            try? document.apply(.setNotarization(n))
                        }))
                }
            }
            .disabled(!notarizationEnabled)
            .opacity(notarizationEnabled ? 1.0 : 0.45)

            notarizationStatusRow
        }
    }

    // MARK: - Helpers
    //
    // The Sparkle section was removed 2026-05-24. It captured four
    // fields (enabled / appcastPath / releaseNotesDirectory /
    // downloadBaseURL) but the release pipeline never read them —
    // `ReleasePipeline.swift` has no consumer for `config.sparkle`. No
    // appcast XML was generated, no EdDSA signing performed, no upload.
    // Proper Sparkle integration is a separate workstream (key
    // generation + EdDSA signing + appcast XML serialization + upload
    // to the download URL). The config struct and intent stayed for
    // YAML round-trip compatibility but are no longer surfaced.

    /// Computed section status — see the shared `StatusRow` /
    /// `StatusKind` in `TabComponents.swift`. Each property below
    /// returns a fully-built `StatusRow` so the section just renders
    /// `signingStatusRow` / `notarizationStatusRow` without knowing
    /// about the kind enum or the fix wiring.
    ///
    /// Notarization rolls in two cross-section requirements:
    ///
    ///   • Hardened runtime — Apple will reject any submission without
    ///     it (`codesign --options runtime`), so it's a hard block. We
    ///     attach a one-click "Enable" fix so the user doesn't need to
    ///     scroll up into Signing to flip it.
    ///   • Staple — not Apple-enforced, but a notarized-without-staple
    ///     artifact makes the user's Mac phone Apple on first launch
    ///     instead of verifying offline. First-time notarization
    ///     enable defaults Staple to on, so this branch mostly fires
    ///     when the user has deliberately flipped it off.
    private var signingStatusRow: some View {
        let v = ReleaseStatusKind.signing(document.config.signing)
        return StatusRow(v.kind, v.longMessage)
            .padding(.top, 4)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Tokens.color(.divider))
                    .frame(height: Tokens.Size.hairline)
            }
    }

    private func statusPill(_ v: ReleaseStatusKind.Verdict) -> some View {
        HStack(spacing: 5) {
            Circle().fill(v.kind.color).frame(width: 7, height: 7)
            Text(v.shortLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Tokens.color(.textSecondary))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Tokens.color(.canvasBackground))
        .overlay(SquareShape().stroke(Tokens.color(.divider),
                                      lineWidth: Tokens.Size.hairline))
    }

    private var notarizationStatusRow: some View {
        let v = ReleaseStatusKind.notarization(
            document.config.notarization,
            signingHardenedRuntime:
                document.config.signing?.hardenedRuntime ?? false)
        let fix: StatusRow.Fix? = {
            // Re-attach the cross-section one-click fixes that used to live
            // inline in this property. The verdict tells us which fix is
            // relevant via `shortLabel`.
            switch v.shortLabel {
            case "needs hardened runtime":
                return .init(label: "Enable") {
                    var s = currentSigning()
                    s.hardenedRuntime = true
                    if !s.enabled { s.enabled = true }
                    try? document.apply(.setSigning(s))
                }
            case "staple off":
                return .init(label: "Enable") {
                    var n = currentNotarization()
                    n.staple = true
                    try? document.apply(.setNotarization(n))
                }
            default:
                return nil
            }
        }()
        return StatusRow(v.kind, v.longMessage, fix: fix)
            .padding(.top, 4)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Tokens.color(.divider))
                    .frame(height: Tokens.Size.hairline)
            }
    }

    /// Entitlements path shown in the picker: relative to the project
    /// directory when possible so a path like
    /// `/Users/me/Projects/MyApp/build/MyApp.entitlements` reads as
    /// `build/MyApp.entitlements` instead of the verbose absolute
    /// form. Falls back to the absolute path for entitlements stored
    /// outside the project tree (rare but valid).
    private var entitlementsDisplayPath: String {
        let raw = document.config.signing?.entitlements ?? ""
        guard !raw.isEmpty else { return "" }
        let projectPath = document.projectDirectory.path
        if raw.hasPrefix(projectPath + "/") {
            return String(raw.dropFirst(projectPath.count + 1))
        }
        return raw
    }

    private func currentSigning() -> LutinConfig.SigningInfo {
        document.config.signing ?? LutinConfig.SigningInfo(
            enabled: false, identity: nil, hardenedRuntime: nil,
            entitlements: nil, signDmg: nil)
    }
    private func currentNotarization() -> LutinConfig.NotarizationInfo {
        document.config.notarization ?? LutinConfig.NotarizationInfo(
            enabled: false, profile: nil, staple: nil)
    }

    private func pickEntitlements() {
        let panel = NSOpenPanel()
        if let entitlements = UTType(filenameExtension: "entitlements") {
            panel.allowedContentTypes = [entitlements, .propertyList]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var s = currentSigning(); s.entitlements = url.path
        try? document.apply(.setSigning(s))
    }
}

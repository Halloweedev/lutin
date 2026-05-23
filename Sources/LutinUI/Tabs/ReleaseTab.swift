import SwiftUI
import AppKit
import UniformTypeIdentifiers
import LutinConfig
import LutinDocument

public struct ReleaseTab: View {
    @Bindable var document: LutinProjectDocument
    @State private var identities: [IdentityProbe.Identity] = []
    @State private var notaryProfiles: [String] = []

    public init(document: LutinProjectDocument) { self.document = document }

    public var body: some View {
        TabBody {
            signingSection
            notarizationSection
            sparkleSection
        }
        .task {
            identities = IdentityProbe.run()
            notaryProfiles = NotaryProbe.run()
        }
    }

    // MARK: - Signing

    private var signingSection: some View {
        SettingsSection("Signing") {
            SettingsField("Enabled") {
                Toggle("", isOn: Binding(
                    get: { document.config.signing?.enabled ?? false },
                    set: { v in
                        var s = currentSigning(); s.enabled = v
                        try? document.apply(.setSigning(s))
                    })).labelsHidden()
            }
            SettingsField("Identity",
                          helper: identities.isEmpty
                          ? "No Developer ID identities found in the Keychain."
                          : nil) {
                Picker("", selection: Binding(
                    get: { document.config.signing?.identity ?? "" },
                    set: { v in
                        var s = currentSigning(); s.identity = v.isEmpty ? nil : v
                        try? document.apply(.setSigning(s))
                    })) {
                    Text("Not set").tag("")
                    ForEach(identities) { i in
                        Text(i.name).tag(i.name as String)
                    }
                }
                .labelsHidden()
            }
            SettingsField("Hardened runtime") {
                Toggle("", isOn: Binding(
                    get: { document.config.signing?.hardenedRuntime ?? false },
                    set: { v in
                        var s = currentSigning(); s.hardenedRuntime = v
                        try? document.apply(.setSigning(s))
                    })).labelsHidden()
            }
            SettingsField("Entitlements") {
                PathPickerRow(value: document.config.signing?.entitlements ?? "",
                              placeholder: "No .entitlements file",
                              onPick: pickEntitlements)
            }
            SettingsField("Sign DMG") {
                Toggle("", isOn: Binding(
                    get: { document.config.signing?.signDmg ?? false },
                    set: { v in
                        var s = currentSigning(); s.signDmg = v
                        try? document.apply(.setSigning(s))
                    })).labelsHidden()
            }
            doctorRow(label: "Signing status",
                      ok: (document.config.signing?.enabled ?? false) &&
                          !(document.config.signing?.identity?.isEmpty ?? true))
        }
    }

    // MARK: - Notarization

    private var notarizationSection: some View {
        SettingsSection("Notarization") {
            SettingsField("Enabled") {
                Toggle("", isOn: Binding(
                    get: { document.config.notarization?.enabled ?? false },
                    set: { v in
                        var n = currentNotarization(); n.enabled = v
                        try? document.apply(.setNotarization(n))
                    })).labelsHidden()
            }
            SettingsField("Profile",
                          helper: notaryProfiles.isEmpty
                          ? "Couldn't list profiles via `xcrun notarytool`. Type one manually."
                          : nil) {
                if notaryProfiles.isEmpty {
                    SettingsTextField("ci-notary", text: Binding(
                        get: { document.config.notarization?.profile ?? "" },
                        set: { v in
                            var n = currentNotarization(); n.profile = v.isEmpty ? nil : v
                            try? document.apply(.setNotarization(n))
                        }))
                } else {
                    Picker("", selection: Binding(
                        get: { document.config.notarization?.profile ?? "" },
                        set: { v in
                            var n = currentNotarization(); n.profile = v.isEmpty ? nil : v
                            try? document.apply(.setNotarization(n))
                        })) {
                        Text("Not set").tag("")
                        ForEach(notaryProfiles, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
            }
            SettingsField("Staple") {
                Toggle("", isOn: Binding(
                    get: { document.config.notarization?.staple ?? false },
                    set: { v in
                        var n = currentNotarization(); n.staple = v
                        try? document.apply(.setNotarization(n))
                    })).labelsHidden()
            }
            doctorRow(label: "Notarization status",
                      ok: (document.config.notarization?.enabled ?? false) &&
                          !(document.config.notarization?.profile?.isEmpty ?? true))
        }
    }

    // MARK: - Sparkle

    private var sparkleSection: some View {
        SettingsSection("Sparkle") {
            SettingsField("Enabled") {
                Toggle("", isOn: Binding(
                    get: { document.config.sparkle?.enabled ?? false },
                    set: { v in
                        var sp = currentSparkle(); sp.enabled = v
                        try? document.apply(.setSparkle(sp))
                    })).labelsHidden()
            }
            SettingsField("Appcast path") {
                PathPickerRow(value: document.config.sparkle?.appcastPath ?? "",
                              placeholder: "No appcast.xml chosen",
                              onPick: pickAppcast)
            }
            SettingsField("Release notes directory") {
                PathPickerRow(value: document.config.sparkle?.releaseNotesDirectory ?? "",
                              placeholder: "No folder chosen",
                              onPick: pickReleaseNotesDir)
            }
            SettingsField("Download base URL",
                          helper: "Where new builds will live, e.g. https://example.com/releases") {
                SettingsTextField("https://example.com/releases", text: Binding(
                    get: { document.config.sparkle?.downloadBaseURL ?? "" },
                    set: { v in
                        var sp = currentSparkle(); sp.downloadBaseURL = v.isEmpty ? nil : v
                        try? document.apply(.setSparkle(sp))
                    }))
            }
            doctorRow(label: "Sparkle status",
                      ok: (document.config.sparkle?.enabled ?? false) &&
                          URL(string: document.config.sparkle?.downloadBaseURL ?? "")?.scheme != nil)
        }
    }

    // MARK: - Helpers

    private func doctorRow(label: String, ok: Bool) -> some View {
        HStack(spacing: 8) {
            Circle().fill(ok ? Tokens.color(.logSuccess) : Tokens.color(.logProgress))
                .frame(width: 8, height: 8)
            Text(label).font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
            Spacer()
        }
        .padding(.top, 4)
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
    private func currentSparkle() -> LutinConfig.SparkleInfo {
        document.config.sparkle ?? LutinConfig.SparkleInfo(
            enabled: false, appcastPath: nil,
            releaseNotesDirectory: nil, downloadBaseURL: nil)
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
    private func pickAppcast() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.xml]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var sp = currentSparkle(); sp.appcastPath = url.path
        try? document.apply(.setSparkle(sp))
    }
    private func pickReleaseNotesDir() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var sp = currentSparkle(); sp.releaseNotesDirectory = url.path
        try? document.apply(.setSparkle(sp))
    }
}

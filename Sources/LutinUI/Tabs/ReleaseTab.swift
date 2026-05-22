import SwiftUI
import AppKit
import UniformTypeIdentifiers
import LutinConfig
import LutinDocument

public struct ReleaseTab: View {
    @Bindable var document: LutinProjectDocument
    @State private var identities: [IdentityProbe.Identity] = []
    @State private var notaryProfiles: [String] = []
    @State private var signingExpanded = true
    @State private var notaryExpanded = true
    @State private var sparkleExpanded = true

    public init(document: LutinProjectDocument) { self.document = document }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                signingSection
                Divider().frame(height: Tokens.Size.hairline).background(Tokens.color(.divider))
                notarizationSection
                Divider().frame(height: Tokens.Size.hairline).background(Tokens.color(.divider))
                sparkleSection
            }
        }
        .background(Tokens.color(.panelBackground))
        .task {
            identities = IdentityProbe.run()
            notaryProfiles = NotaryProbe.run()
        }
    }

    private var signingSection: some View {
        DisclosureGroup(isExpanded: $signingExpanded) {
            VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
                Toggle("Enabled", isOn: Binding(
                    get: { document.config.signing?.enabled ?? false },
                    set: { v in
                        var s = currentSigning(); s.enabled = v
                        try? document.apply(.setSigning(s))
                    }))
                Picker("Identity", selection: Binding(
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
                Toggle("Hardened runtime", isOn: Binding(
                    get: { document.config.signing?.hardenedRuntime ?? false },
                    set: { v in
                        var s = currentSigning(); s.hardenedRuntime = v
                        try? document.apply(.setSigning(s))
                    }))
                HStack {
                    Text("Entitlements")
                    Spacer()
                    Text(document.config.signing?.entitlements ?? "—").lineLimit(1).truncationMode(.middle)
                    Button("Choose…", action: pickEntitlements)
                }
                Toggle("Sign DMG", isOn: Binding(
                    get: { document.config.signing?.signDmg ?? false },
                    set: { v in
                        var s = currentSigning(); s.signDmg = v
                        try? document.apply(.setSigning(s))
                    }))
                doctorRow(label: "Signing status",
                          ok: (document.config.signing?.enabled ?? false) &&
                              !(document.config.signing?.identity?.isEmpty ?? true))
            }
            .padding(Tokens.spacing(.md))
        } label: { sectionHeader("Signing") }
    }

    private var notarizationSection: some View {
        DisclosureGroup(isExpanded: $notaryExpanded) {
            VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
                Toggle("Enabled", isOn: Binding(
                    get: { document.config.notarization?.enabled ?? false },
                    set: { v in
                        var n = currentNotarization(); n.enabled = v
                        try? document.apply(.setNotarization(n))
                    }))
                if notaryProfiles.isEmpty {
                    TextField("Profile", text: Binding(
                        get: { document.config.notarization?.profile ?? "" },
                        set: { v in
                            var n = currentNotarization(); n.profile = v.isEmpty ? nil : v
                            try? document.apply(.setNotarization(n))
                        }))
                    Text("Could not list notary profiles via `xcrun notarytool`. See the release-lutin-app runbook.")
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.logProgress))
                } else {
                    Picker("Profile", selection: Binding(
                        get: { document.config.notarization?.profile ?? "" },
                        set: { v in
                            var n = currentNotarization(); n.profile = v.isEmpty ? nil : v
                            try? document.apply(.setNotarization(n))
                        })) {
                        Text("Not set").tag("")
                        ForEach(notaryProfiles, id: \.self) { Text($0).tag($0) }
                    }
                }
                Toggle("Staple", isOn: Binding(
                    get: { document.config.notarization?.staple ?? false },
                    set: { v in
                        var n = currentNotarization(); n.staple = v
                        try? document.apply(.setNotarization(n))
                    }))
                doctorRow(label: "Notarization status",
                          ok: (document.config.notarization?.enabled ?? false) &&
                              !(document.config.notarization?.profile?.isEmpty ?? true))
            }
            .padding(Tokens.spacing(.md))
        } label: { sectionHeader("Notarization") }
    }

    private var sparkleSection: some View {
        DisclosureGroup(isExpanded: $sparkleExpanded) {
            VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
                Toggle("Enabled", isOn: Binding(
                    get: { document.config.sparkle?.enabled ?? false },
                    set: { v in
                        var sp = currentSparkle(); sp.enabled = v
                        try? document.apply(.setSparkle(sp))
                    }))
                HStack {
                    Text("Appcast path")
                    Spacer()
                    Text(document.config.sparkle?.appcastPath ?? "—").lineLimit(1).truncationMode(.middle)
                    Button("Choose…", action: pickAppcast)
                }
                HStack {
                    Text("Release notes dir")
                    Spacer()
                    Text(document.config.sparkle?.releaseNotesDirectory ?? "—").lineLimit(1).truncationMode(.middle)
                    Button("Choose…", action: pickReleaseNotesDir)
                }
                TextField("Download base URL", text: Binding(
                    get: { document.config.sparkle?.downloadBaseURL ?? "" },
                    set: { v in
                        var sp = currentSparkle(); sp.downloadBaseURL = v.isEmpty ? nil : v
                        try? document.apply(.setSparkle(sp))
                    }))
                doctorRow(label: "Sparkle status",
                          ok: (document.config.sparkle?.enabled ?? false) &&
                              URL(string: document.config.sparkle?.downloadBaseURL ?? "")?.scheme != nil)
            }
            .padding(Tokens.spacing(.md))
        } label: { sectionHeader("Sparkle") }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(Typography.chromeSmall)
            .textCase(.uppercase)
            .foregroundStyle(Tokens.color(.textSecondary))
            .padding(.horizontal, Tokens.spacing(.md))
            .padding(.top, Tokens.spacing(.sm))
    }

    private func doctorRow(label: String, ok: Bool) -> some View {
        HStack {
            Circle().fill(ok ? Tokens.color(.logSuccess) : Tokens.color(.logProgress))
                .frame(width: 8, height: 8)
            Text(label).font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
        }
    }

    private func currentSigning() -> LutinConfig.SigningInfo {
        document.config.signing ?? LutinConfig.SigningInfo(enabled: false,
                                                            identity: nil,
                                                            hardenedRuntime: nil,
                                                            entitlements: nil,
                                                            signDmg: nil)
    }
    private func currentNotarization() -> LutinConfig.NotarizationInfo {
        document.config.notarization ?? LutinConfig.NotarizationInfo(enabled: false, profile: nil, staple: nil)
    }
    private func currentSparkle() -> LutinConfig.SparkleInfo {
        document.config.sparkle ?? LutinConfig.SparkleInfo(enabled: false,
                                                            appcastPath: nil,
                                                            releaseNotesDirectory: nil,
                                                            downloadBaseURL: nil)
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

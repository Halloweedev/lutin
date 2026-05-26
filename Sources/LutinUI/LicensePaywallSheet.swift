import SwiftUI
import KeylightSDK
import LutinLicense

/// Modal sheet shown when a free-tier user tries to create their
/// 11th project. Two paths out: activate a Lutin Pro license, or buy
/// one. A `Not now` button dismisses without creating the project —
/// the user keeps access to the 10 they already have.
///
/// After successful activation the sheet calls `onActivated` so the
/// workspace can pick up where the user left off (typically by
/// immediately opening `CreateProjectSheet` with the same preselected
/// `.app` URL).
struct LicensePaywallSheet: View {
    @ObservedObject var manager: LicenseManager
    let onActivated: () -> Void
    let onCancel: () -> Void

    @State private var licenseKey: String = ""
    @State private var enteringKey: Bool = false
    @FocusState private var keyFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().frame(height: Tokens.Size.hairline).background(Tokens.color(.divider))
            body_
            Divider().frame(height: Tokens.Size.hairline).background(Tokens.color(.divider))
            footer
        }
        .frame(width: 480)
        .background(Tokens.color(.sheetBackground))
        .onChange(of: manager.isEntitled) { _, entitled in
            if entitled { onActivated() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image("LutinLogo", bundle: LutinAssets.bundle)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(Tokens.color(.brandAccent))
            Text("Upgrade to Lutin Pro").font(Typography.chrome)
                .foregroundStyle(Tokens.color(.textPrimary))
            Spacer()
        }
        .padding(Tokens.spacing(.md))
    }

    // MARK: - Body

    private var body_: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
            pitch
            if enteringKey {
                keyEntryRow
            }
            if let activationError = manager.activationError {
                Text(activationError)
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.logError))
            }
        }
        .padding(Tokens.spacing(.md))
    }

    private var pitch: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.sm)) {
            Text("You've reached the \(LicenseGate.freeProjectCap)-project limit on free Lutin.")
                .font(Typography.chrome)
                .foregroundStyle(Tokens.color(.textPrimary))
            Text("Lutin Pro unlocks unlimited DMG projects and supports continued development. Your existing \(LicenseGate.freeProjectCap) projects keep working either way.")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var keyEntryRow: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.sm)) {
            Text("License key")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
            HStack(spacing: Tokens.spacing(.sm)) {
                LutinTextField("LUTN-XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                    .focused($keyFieldFocused)
                LutinButton("Activate", role: .primary, action: activate)
                    .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || manager.isChecking)
            }
            if manager.isChecking {
                HStack(spacing: Tokens.spacing(.sm)) {
                    ProgressView().controlSize(.small)
                    Text("Validating…")
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textTertiary))
                }
            }
        }
        .onAppear { keyFieldFocused = true }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Tokens.spacing(.sm)) {
            LutinButton("Not now") { onCancel() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            if !enteringKey {
                LutinButton("I have a key") {
                    enteringKey = true
                }
            }
            LutinButton("Buy Lutin Pro", role: .primary) {
                NSWorkspace.shared.open(manager.branding.purchaseURL)
            }
        }
        .padding(Tokens.spacing(.md))
    }

    // MARK: - Actions

    private func activate() {
        let trimmed = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { await manager.activate(key: trimmed) }
    }
}

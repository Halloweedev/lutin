import SwiftUI
import KeylightSDK

/// Friendly periodic "support development" sheet. Non-blocking — every
/// path closes the sheet in one click, including a plain `Maybe later`
/// button. Shown at most once every 30 days while the user is on the
/// free tier (see `LicenseGate.shouldShowSupportNag`).
///
/// Shares activation mechanics with `LicensePaywallSheet`: typing a
/// valid `LUTN-…` key and clicking Activate calls
/// `manager.activate(key:)`; the sheet observes `manager.isEntitled`
/// and self-dismisses on success.
struct LicenseSupportNagSheet: View {
    @ObservedObject var manager: LicenseManager
    let onDismiss: () -> Void

    @State private var licenseKey: String = ""
    @State private var enteringKey: Bool = false
    @FocusState private var keyFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().frame(height: Tokens.Size.hairline).background(Tokens.color(.divider))
            content
            Divider().frame(height: Tokens.Size.hairline).background(Tokens.color(.divider))
            footer
        }
        .frame(width: 460)
        .background(Tokens.color(.sheetBackground))
        .onChange(of: manager.isEntitled) { _, entitled in
            if entitled { onDismiss() }
        }
    }

    private var header: some View {
        HStack {
            Image("LutinLogo", bundle: LutinAssets.bundle)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(Tokens.color(.brandAccent))
            Text("Support Lutin").font(Typography.chrome)
                .foregroundStyle(Tokens.color(.textPrimary))
            Spacer()
        }
        .padding(Tokens.spacing(.md))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
            VStack(alignment: .leading, spacing: Tokens.spacing(.sm)) {
                Text("Lutin is free for everyone.")
                    .font(Typography.chrome)
                    .foregroundStyle(Tokens.color(.textPrimary))
                Text("If Lutin has been useful, consider buying a Pro license to support continued development. You'll get unlimited DMG projects and won't see this sheet again.")
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    private var footer: some View {
        HStack(spacing: Tokens.spacing(.sm)) {
            LutinButton("Maybe later") { onDismiss() }
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

    private func activate() {
        let trimmed = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { await manager.activate(key: trimmed) }
    }
}

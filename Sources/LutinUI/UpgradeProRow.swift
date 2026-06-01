import SwiftUI
import KeylightSDK
import LutinLicense

/// Persistent, always-available "upgrade to Pro" affordance for free-tier
/// users — the standing entry point the paywall and 30-day nag don't
/// provide. Hosted in the project library (`ProjectSwitcherModal`) and on
/// the welcome screen (`WelcomeView`).
///
/// Renders **nothing** once the user is entitled — Pro users never see a
/// "Buy" prompt (`LicenseGate.shouldShowUpgradePrompt`). Tapping it opens
/// the same support/upgrade sheet used elsewhere, so a user who just
/// purchased can paste their key, and one who hasn't can jump to checkout.
struct UpgradeProRow: View {
    @ObservedObject var manager: LicenseManager
    /// When set, shows "<count> / <cap> free projects" as quiet context
    /// (used in the project library; omitted on the welcome screen).
    var projectCount: Int? = nil

    @State private var showUpgrade = false

    var body: some View {
        if LicenseGate.shouldShowUpgradePrompt(isEntitled: manager.isEntitled) {
            HStack(spacing: Tokens.spacing(.sm)) {
                // With a count we lay out space-between (library footer);
                // without one the button centers (welcome screen).
                if let projectCount {
                    Text("\(projectCount) / \(LicenseGate.freeProjectCap) free projects")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.color(.textTertiary))
                    Spacer(minLength: 0)
                }
                LutinButton("Buy Lutin Pro", role: .secondary) { showUpgrade = true }
            }
            .frame(maxWidth: .infinity, alignment: projectCount == nil ? .center : .leading)
            .sheet(isPresented: $showUpgrade) {
                LicenseSupportNagSheet(manager: manager,
                                       onDismiss: { showUpgrade = false })
            }
        }
    }
}

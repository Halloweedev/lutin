import SwiftUI
import KeylightSDK

/// Single source of truth for the Keylight `LicenseManager`.
///
/// The reference is intentionally `internal` to the `LutinUI` module —
/// see https://docs.keylight.dev/swift-sdk/manager/#access-modifier-hygiene.
/// Public exposure would let linked code call `activate(key:)` with a
/// forged key. The `LicensingHooks` enum below provides the small
/// `public` surface the @main App entry point needs for lifecycle.
///
/// Free tier is the 10-project cap (`LutinLicense.LicenseGate`), not a
/// time-based trial — hence `trialDurationDays: 0`.
@MainActor
enum Licensing {
    static let manager: LicenseManager = {
        do {
            return try Keylight.manager(
                sdkKey: LutinSecrets.keylightSDKKey,
                tenantId: "anotheragence",
                productId: "lutn",
                keyPrefix: "LUTN",
                trustedPublicKeyBase64: "wPOiRNiP2hbc0O4UCAuO6FRRLKp4YvGtf8V27xnPzNY=",
                trialDurationDays: 0,
                branding: BrandingConfig(
                    appName: "Lutin",
                    // TODO(keylight-checkout): replace with the Stripe Connect
                    // checkout URL from app.keylight.dev once it's set up.
                    // Placeholder points at the parent-brand site so the
                    // `URL(string:)!` force-unwrap can't fail.
                    purchaseURL: URL(string: "https://anotheragence.com/lutin/buy")!,
                    supportEmail: "say@anotheragence.com",
                    tintColor: Tokens.color(.brandAccent)
                )
            )
        } catch {
            fatalError("Keylight.manager init failed — check credentials in Sources/LutinUI/Licensing.swift: \(error)")
        }
    }()
}

/// Public lifecycle bridge for the @main App entry point in
/// `Apps/LutinApp/main.swift`. Keeps `Licensing.manager` itself
/// internal (per Keylight security guidance) while still letting the
/// app driver call the required lifecycle methods.
public enum LicensingHooks {
    @MainActor
    public static func checkOnLaunch() async {
        await Licensing.manager.checkOnLaunch()
    }

    @MainActor
    public static func refreshIfNeeded() async {
        await Licensing.manager.refreshIfNeeded()
    }
}

import Foundation
import LutinConfig

/// Single source of truth for the "what's the section's verdict" math
/// shared by the section header pill (new in 2026-05-26) and the body
/// `StatusRow` (existing). If the two ever disagree, this enum is the
/// arbiter — `ReleaseTab` reads it twice and renders both presentations.
///
/// Kept off `LutinConfig` because the `StatusKind` enum is a UI concept
/// (color mapping, SF Symbol). The math itself is pure config.
public enum ReleaseStatusKind {
    public struct Verdict: Equatable {
        public let kind: StatusKind
        /// Short verdict label for the section's header pill.
        /// Also used as the switch key in `ReleaseTab` to decide which
        /// one-click `Fix` action to attach (e.g. `"needs hardened runtime"`
        /// → "Enable hardened runtime"). Treat these strings as a stable
        /// contract — change them only by also updating the consumer switch.
        public let shortLabel: String
        public let longMessage: String
        public init(kind: StatusKind, shortLabel: String, longMessage: String) {
            self.kind = kind
            self.shortLabel = shortLabel
            self.longMessage = longMessage
        }
    }

    public static func signing(_ s: LutinConfig.SigningInfo?) -> Verdict {
        let enabled = s?.enabled ?? false
        let identity = (s?.identity ?? "")
            .trimmingCharacters(in: .whitespaces)
        if !enabled {
            return Verdict(kind: .inactive,
                           shortLabel: "disabled",
                           longMessage: "Signing disabled")
        }
        if identity.isEmpty {
            return Verdict(kind: .blocked,
                           shortLabel: "needs identity",
                           longMessage: "Signing needs an identity")
        }
        return Verdict(kind: .ok,
                       shortLabel: "ready",
                       longMessage: "Signing ready")
    }

    public static func notarization(
        _ n: LutinConfig.NotarizationInfo?,
        signingHardenedRuntime: Bool
    ) -> Verdict {
        let enabled = n?.enabled ?? false
        let profile = (n?.profile ?? "")
            .trimmingCharacters(in: .whitespaces)
        let staple = n?.staple ?? false
        if !enabled {
            return Verdict(kind: .inactive,
                           shortLabel: "disabled",
                           longMessage: "Notarization disabled")
        }
        if profile.isEmpty {
            return Verdict(kind: .blocked,
                           shortLabel: "needs profile",
                           longMessage: "Notary profile required")
        }
        if !signingHardenedRuntime {
            return Verdict(kind: .blocked,
                           shortLabel: "needs hardened runtime",
                           longMessage:
                               "Hardened runtime required for notarization")
        }
        // Severity downgraded from `.blocked` to `.warn` in 2026-05-26:
        // Apple does not enforce stapling. A notarized-but-unstapled artifact
        // still ships; it just makes the user's Mac phone Apple on first
        // launch. The longMessage ("disable only if intentional") is warning
        // language, not blocking language — color now matches the copy.
        if !staple {
            return Verdict(kind: .warn,
                           shortLabel: "staple off",
                           longMessage:
                               "Stapling recommended — disable only if intentional")
        }
        return Verdict(kind: .ok,
                       shortLabel: "ready",
                       longMessage: "Notarization ready")
    }
}

import SwiftUI

/// Compact three-dot environment summary shown on the welcome page.
/// Tapping the row opens the full `DoctorSheet`.
struct WelcomeDoctorStrip: View {
    let hasCodesign: Bool
    let hasDeveloperIDIdentity: Bool
    let onOpenDoctor: () -> Void

    private enum DotState {
        case ok, warn, missing, unknown

        var color: Color {
            switch self {
            case .ok:      return StatusKind.ok.color
            case .warn:    return StatusKind.warn.color
            case .missing: return StatusKind.blocked.color
            case .unknown: return Tokens.color(.textTertiary)
            }
        }
    }

    var body: some View {
        LutinButton(role: .secondary, action: onOpenDoctor) {
            HStack(spacing: Tokens.spacing(.md)) {
                dot(label: "codesign",
                    state: hasCodesign ? .ok : .missing)
                dot(label: "Developer ID",
                    state: hasDeveloperIDIdentity ? .ok : .warn)
                dot(label: "notarytool profile",
                    state: .unknown)
                Spacer()
                Text("Doctor")
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.brandAccent))
            }
            .padding(.horizontal, Tokens.spacing(.md))
            .padding(.vertical, Tokens.spacing(.sm))
            .contentShape(Rectangle())
        }
        .overlay(SquareShape().stroke(Tokens.color(.divider),
                                      lineWidth: Tokens.Size.hairline))
    }

    private func dot(label: String, state: DotState) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(state.color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
        }
    }
}

import SwiftUI
import LutinRegistry

/// One card in the recents grid. Renders a rounded square icon
/// (initial + deterministic gradient from the project name),
/// the project name, and a status dot with last-built / last-opened
/// info. The whole card is the project-open button; a small
/// overflow `Menu` in the corner exposes Reveal / Remove.
struct WelcomeRecentCard: View {
    let entry: RegistryEntry
    let isMissingOnDisk: Bool
    let onSelect: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SwiftUI.Button(action: onSelect) {
                VStack(spacing: Tokens.spacing(.xs)) {
                    iconTile
                    Text(entry.name)
                        .font(Typography.chromeSmall.weight(.medium))
                        .foregroundStyle(Tokens.color(.textPrimary))
                        .lineLimit(1)
                    statusLine
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Tokens.spacing(.md))
                .padding(.bottom, Tokens.spacing(.sm))
                .padding(.horizontal, Tokens.spacing(.sm))
                .background(Tokens.color(.panelBackground))
                .overlay(SquareShape()
                    .stroke(Tokens.color(.divider),
                            lineWidth: Tokens.Size.hairline))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            overflowMenu
                .padding(.top, 4)
                .padding(.trailing, 4)
        }
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Self.gradient(for: entry.name))
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            Text(String(entry.name.prefix(1)).uppercased())
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textTertiary))
                .lineLimit(1)
        }
    }

    private var statusColor: Color {
        if isMissingOnDisk { return StatusKind.blocked.color }
        switch entry.lastBuildOutcome {
        case .succeeded: return StatusKind.ok.color
        case .failed:    return StatusKind.warn.color
        case .unsigned:  return Tokens.color(.textTertiary)
        case .none:      return Tokens.color(.textTertiary)
        }
    }

    private var statusText: String {
        if isMissingOnDisk { return "missing" }
        let when = entry.lastOpenedDate.formatted(.relative(presentation: .numeric))
        switch entry.lastBuildOutcome {
        case .succeeded: return "built · \(when)"
        case .failed:    return "failed · \(when)"
        case .unsigned:  return "unsigned · \(when)"
        case .none:      return "never built · \(when)"
        }
    }

    private var overflowMenu: some View {
        Menu {
            SwiftUI.Button("Reveal in Finder", action: onReveal) // allow-menu-button: Menu pop-up item
            SwiftUI.Button("Remove from Recents", role: .destructive, action: onRemove) // allow-menu-button: Menu pop-up item
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.color(.textTertiary))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// Deterministic gradient palette keyed by the project name's
    /// first character. Keeps the grid visually varied without
    /// requiring the real .app icon (which isn't always available).
    private static func gradient(for name: String) -> LinearGradient {
        let palette: [(Color, Color)] = [
            (Color(red: 0.77, green: 0.37, blue: 0.16), Color(red: 0.43, green: 0.23, blue: 0.10)), // orange
            (Color(red: 0.29, green: 0.48, blue: 0.72), Color(red: 0.16, green: 0.29, blue: 0.47)), // blue
            (Color(red: 0.44, green: 0.58, blue: 0.33), Color(red: 0.25, green: 0.33, blue: 0.19)), // green
            (Color(red: 0.72, green: 0.53, blue: 0.29), Color(red: 0.48, green: 0.35, blue: 0.16)), // amber
        ]
        let key = Int(name.unicodeScalars.first?.value ?? 0)
        let pick = palette[abs(key) % palette.count]
        return LinearGradient(colors: [pick.0, pick.1],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }
}

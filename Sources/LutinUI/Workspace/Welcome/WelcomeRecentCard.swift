import SwiftUI
import LutinRegistry
import LutinAppKit

/// One card in the recents grid. Renders the real `.app` Finder icon
/// when the bundle is reachable, otherwise falls back to an initial +
/// deterministic gradient keyed by the project name. Followed by the
/// project name and a status dot with last-built / last-opened info.
/// The whole card is the project-open button; a small overflow `Menu`
/// in the corner exposes Reveal / Remove.
struct WelcomeRecentCard: View {
    let entry: RegistryEntry
    let isMissingOnDisk: Bool
    let onSelect: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LutinButton(action: onSelect) {
                VStack(spacing: Tokens.spacing(.xs)) {
                    ProjectIconTile(name: entry.name,
                                    appPath: entry.appPath,
                                    sizePoints: 44)
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

            overflowMenu
                .padding(.top, 4)
                .padding(.trailing, 4)
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

}

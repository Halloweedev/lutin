import SwiftUI
import LutinRegistry

/// Horizontal grid of recent-project cards. The "Open existing" affordance
/// moved to the drop-hero inline link in 2026-05-26 — this grid is now
/// purely about recents. 4-column layout (down from 5) so cards breathe.
/// When more than 4 projects exist, a "See all →" link on the header
/// opens the switcher modal.
struct WelcomeRecentsGrid: View {
    let entries: [RegistryEntryStatus]
    let onSeeAll: () -> Void
    let onSelect: (String) -> Void
    let onReveal: (RegistryEntry) -> Void
    let onRemove: (String) -> Void

    private static let maxVisibleCards = 4

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: Tokens.spacing(.sm)),
        count: WelcomeRecentsGrid.maxVisibleCards)

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.xs)) {
            HStack {
                Text("RECENT · \(entries.count)")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(Tokens.color(.textTertiary))
                Spacer()
                if entries.count > Self.maxVisibleCards {
                    Text("See all →")
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.brandAccent))
                        .textLink(action: onSeeAll)
                }
            }
            .padding(.horizontal, 2)

            LazyVGrid(columns: columns, spacing: Tokens.spacing(.sm)) {
                ForEach(entries, id: \.entry.name) { status in
                    WelcomeRecentCard(
                        entry: status.entry,
                        isMissingOnDisk: status.status == .missing,
                        onSelect: { onSelect(status.entry.name) },
                        onReveal: { onReveal(status.entry) },
                        onRemove: { onRemove(status.entry.name) })
                }
            }
        }
    }
}

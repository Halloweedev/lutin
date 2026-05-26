import SwiftUI
import LutinRegistry

/// Horizontal row of recent-project cards on the welcome page. An
/// `Open existing…` tile leads the row, followed by up to 10 recents
/// sorted by `lastOpenedDate`. Project creation lives in the drop
/// zone above — the recent row is for re-opening, not creating.
struct WelcomeRecentsGrid: View {
    let entries: [RegistryEntryStatus]
    let onOpenExisting: () -> Void
    let onSelect: (String) -> Void
    let onReveal: (RegistryEntry) -> Void
    let onRemove: (String) -> Void

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: Tokens.spacing(.sm)),
        count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.xs)) {
            HStack {
                Text("Recent projects")
                    .font(Typography.chromeSmall.weight(.medium))
                    .foregroundStyle(Tokens.color(.textSecondary))
                Spacer()
                Text("\(entries.count) projects")
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
            }
            .padding(.horizontal, 2)

            LazyVGrid(columns: columns, spacing: Tokens.spacing(.sm)) {
                openExistingCard
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

    private var openExistingCard: some View {
        LutinButton(action: onOpenExisting) {
            VStack(spacing: Tokens.spacing(.xs)) {
                Image(systemName: "folder")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Tokens.color(.brandAccent))
                Text("Open existing")
                    .font(Typography.chromeSmall.weight(.medium))
                    .foregroundStyle(Tokens.color(.brandAccent))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 108)
            .background(Tokens.color(.brandAccentMuted).opacity(0.35))
            .overlay(SquareShape()
                .stroke(Tokens.color(.brandAccent),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            .contentShape(Rectangle())
        }
    }
}

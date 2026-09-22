import SwiftUI

/// §7.2 — the resolved app and platform. Read-only.
public struct StoreAppSection: View {
    let state: StoreSectionState<StoreAppModel>

    public init(state: StoreSectionState<StoreAppModel>) { self.state = state }

    public var body: some View {
        // The failure's fix rides in the shared failure view, never here.
        SettingsSection("App", footer: note) {
            switch state {
            case .loading:
                Text("Resolving the app…")
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Tokens.color(.textTertiary))
            case .failed(let failure):
                StoreSectionFailure(failure)
            case .loaded(let model):
                ForEach(model.rows) { row in
                    rowView(row)
                }
            }
        }
    }

    /// Only a loaded model has a footer; the failed case's explanation is the
    /// shared `StoreSectionFailure`, which draws the fix itself.
    private var note: String? {
        if case .loaded(let model) = state { return model.note }
        return nil
    }

    private func rowView(_ row: StoreAppModel.Row) -> some View {
        HStack(spacing: Tokens.spacing(.sm)) {
            Text(row.label)
                .font(Typography.inspectorLabel)
                .foregroundStyle(Tokens.color(.textSecondary))
                .frame(width: 156, alignment: .leading)   // StoreTab.variantRow's geometry
            Text(row.value)
                .font(row.isMonospaced ? Typography.logLine : Typography.inspectorValue)
                .foregroundStyle(Tokens.color(.textPrimary))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }
}

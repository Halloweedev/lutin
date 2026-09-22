import SwiftUI

/// §7.2 — the resolved app and platform. Read-only.
public struct StoreAppSection: View {
    let state: StoreSectionState<StoreAppModel>

    public init(state: StoreSectionState<StoreAppModel>) { self.state = state }

    /// What the section paints, split into the parts `SettingsSection` lays out
    /// separately. Pure so the "the fix appears exactly once" rule is asserted
    /// without reading pixels: the footer owns the fix, the body never repeats
    /// it.
    struct Content: Equatable {
        let footer: String?
        let bodyMessage: String?
        let rows: [StoreAppModel.Row]

        var showsFailureBody: Bool { bodyMessage != nil }
    }

    static func content(for state: StoreSectionState<StoreAppModel>) -> Content {
        switch state {
        case .loading:
            return Content(footer: nil, bodyMessage: nil, rows: [])
        case .failed(let failure):
            // The message is the body; the fix is the footer. Never both.
            return Content(footer: failure.fix, bodyMessage: failure.message, rows: [])
        case .loaded(let model):
            return Content(footer: model.note, bodyMessage: nil, rows: model.rows)
        }
    }

    public var body: some View {
        // The footer owns the fix hint, for the failure and the loaded case
        // alike; `failedBody` deliberately draws only the status row, so the
        // hint appears exactly once.
        SettingsSection("App", footer: content.footer) {
            switch state {
            case .loading:
                Text("Resolving the app…")
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Tokens.color(.textTertiary))
            case .failed(let failure):
                failedBody(failure)
            case .loaded(let model):
                ForEach(model.rows) { row in
                    rowView(row)
                }
            }
        }
    }

    private var content: Content { Self.content(for: state) }

    /// The message only: `SettingsSection`'s footer carries the fix, so drawing
    /// it here too would print it twice.
    @ViewBuilder
    private func failedBody(_ failure: StoreFailure) -> some View {
        StatusRow(.blocked, failure.message)
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

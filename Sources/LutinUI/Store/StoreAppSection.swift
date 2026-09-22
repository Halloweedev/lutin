import SwiftUI

/// §7.2 — the resolved app and platform. Read-only.
public struct StoreAppSection: View {
    let state: StoreSectionState<StoreAppModel>

    public init(state: StoreSectionState<StoreAppModel>) { self.state = state }

    public var body: some View {
        // The footer is the loaded model's note, or the failure's fix — the
        // section degrades to an explanation either way, and says nothing when
        // it has nothing to say.
        SettingsSection("App", footer: footer) {
            switch state {
            case .loading:
                Text("Resolving the app…")
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Tokens.color(.textTertiary))
            case .failed(let failure):
                failedBody(failure)
            case .loaded(let model):
                ForEach(model.rows) { row in
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
        }
    }

    private var footer: String? {
        if case .loaded(let model) = state { return model.note }
        return state.failureFix
    }

    @ViewBuilder
    private func failedBody(_ failure: StoreFailure) -> some View {
        StatusRow(.blocked, failure.message)
        if let fix = failure.fix {
            Text(fix)
                .font(Typography.inspectorLabel)
                .foregroundStyle(Tokens.color(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

import SwiftUI

/// §7.3 — App Store versions and states, newest first. Read-only: no editing
/// surface exists in Spec 1a.
public struct StoreVersionsSection: View {
    let state: StoreSectionState<StoreVersionsModel>

    public init(state: StoreSectionState<StoreVersionsModel>) { self.state = state }

    public var body: some View {
        SettingsSection("Versions", headerMeta: { pill }) {
            switch state {
            case .loading:
                Text("Asking asc for the versions…")
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Tokens.color(.textTertiary))
            case .failed(let failure):
                StoreSectionFailure(failure)
            case .loaded(let model):
                if model.isEmpty {
                    Text("asc reports no versions for this app yet.")
                        .font(Typography.inspectorLabel)
                        .foregroundStyle(Tokens.color(.textTertiary))
                }
                ForEach(model.versions) { version in
                    versionRow(version)
                }
            }
        }
    }

    @ViewBuilder
    private var pill: some View {
        if case .loaded(let model) = state, !model.isEmpty {
            Text("\(model.versions.count) · \(model.platform)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Tokens.color(.textSecondary))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Tokens.color(.canvasBackground))
                .overlay(SquareShape().stroke(Tokens.color(.divider),
                                              lineWidth: Tokens.Size.hairline))
        }
    }

    private func versionRow(_ version: StoreVersionsModel.Version) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.spacing(.sm)) {
            Text(version.versionString)
                .font(Typography.logLine)
                .foregroundStyle(Tokens.color(.textPrimary))
                .lineLimit(1)
            if version.isLive {
                HStack(spacing: 5) {
                    Circle().fill(StatusKind.ok.color).frame(width: 7, height: 7)
                    Text("live").font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Tokens.color(.textSecondary))
                }
            }
            Spacer(minLength: Tokens.spacing(.sm))
            Text(version.detail)
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textTertiary))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, Tokens.spacing(.md))
        .padding(.vertical, Tokens.spacing(.xs))
    }

}

import LutinStoreConnect
import SwiftUI

/// §7's Validation section: asc's findings, grouped by scope and locale, with
/// errors and warnings distinguished — and the offline subset when asc is
/// absent, never an empty state.
public struct StoreValidationSection: View {
    let state: StoreSectionState<StoreValidationModel>
    let onRecheck: () -> Void

    public init(state: StoreSectionState<StoreValidationModel>,
                onRecheck: @escaping () -> Void) {
        self.state = state
        self.onRecheck = onRecheck
    }

    public var body: some View {
        SettingsSection("Validation", headerMeta: { pill }) {
            switch state {
            case .loading:
                Text("Checking the metadata tree…")
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Tokens.color(.textTertiary))
            case .failed(let failure):
                failedBody(failure)
            case .loaded(let model):
                loadedBody(model)
            }
        }
    }

    // MARK: - Header pill (ReleaseTab.statusPill's geometry)

    @ViewBuilder
    private var pill: some View {
        if let label = pillLabel {
            HStack(spacing: 5) {
                Circle().fill(label.kind.color).frame(width: 7, height: 7)
                Text(label.text)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Tokens.color(.textSecondary))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Tokens.color(.canvasBackground))
            .overlay(SquareShape().stroke(Tokens.color(.divider),
                                          lineWidth: Tokens.Size.hairline))
        }
    }

    private var pillLabel: (text: String, kind: StatusKind)? {
        switch state {
        case .loading:
            return nil
        case .failed:
            return ("error", .blocked)
        case .loaded(let model):
            if model.errorCount > 0 {
                return ("\(model.errorCount) error\(model.errorCount == 1 ? "" : "s")", .blocked)
            }
            if model.warningCount > 0 {
                return ("\(model.warningCount) warning\(model.warningCount == 1 ? "" : "s")", .warn)
            }
            return model.offline ? ("offline subset", .warn) : ("clean", .ok)
        }
    }

    // MARK: - Bodies

    @ViewBuilder
    private func loadedBody(_ model: StoreValidationModel) -> some View {
        ForEach(model.groups) { group in
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Tokens.spacing(.sm)) {
                    Text(group.title)
                        .font(Typography.chromeSmall.weight(.medium))
                        .foregroundStyle(Tokens.color(.textSecondary))
                    Text(groupCounts(group))
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textTertiary))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Tokens.spacing(.md))
                .padding(.top, Tokens.spacing(.sm))
                .padding(.bottom, 2)

                ForEach(group.localeGroups) { localeGroup in
                    if let locale = localeGroup.locale {
                        Text(locale)
                            .font(Typography.chromeSmall)
                            .foregroundStyle(Tokens.color(.textTertiary))
                            .padding(.horizontal, Tokens.spacing(.md))
                            .padding(.top, 2)
                    }
                    ForEach(localeGroup.findings) { finding in
                        findingRow(finding)
                    }
                }
            }
        }
        if let fix = model.fix {
            Text(fix)
                .font(Typography.inspectorLabel)
                .foregroundStyle(Tokens.color(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
        StatusRow(statusKind(model), model.headline,
                  fix: .init(label: "Re-check", action: onRecheck))
    }

    @ViewBuilder
    private func failedBody(_ failure: StoreFailure) -> some View {
        StatusRow(.blocked, failure.message,
                  fix: .init(label: "Re-check", action: onRecheck))
        if let fix = failure.fix {
            Text(fix)
                .font(Typography.inspectorLabel)
                .foregroundStyle(Tokens.color(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func findingRow(_ finding: StoreValidationModel.Finding) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.spacing(.sm)) {
            Image(systemName: finding.severity == .error
                  ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Tokens.color(finding.severity == .error ? .logError : .logProgress))
                .frame(width: 16, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.title)
                    .font(.system(size: 13))
                    .foregroundStyle(Tokens.color(.textPrimary))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(finding.message)
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Tokens.spacing(.sm))
            if let budget = finding.budget {
                Text(budget)
                    .font(Typography.logLine)
                    .foregroundStyle(Tokens.color(finding.isOverLimit ? .logError : .textTertiary))
            }
        }
        .padding(.horizontal, Tokens.spacing(.md))
        .padding(.vertical, Tokens.spacing(.xs))
    }

    private func groupCounts(_ group: StoreValidationModel.Group) -> String {
        var parts: [String] = []
        if group.errorCount > 0 { parts.append("\(group.errorCount) error\(group.errorCount == 1 ? "" : "s")") }
        if group.warningCount > 0 { parts.append("\(group.warningCount) warning\(group.warningCount == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    private func statusKind(_ model: StoreValidationModel) -> StatusKind {
        if model.errorCount > 0 { return .blocked }
        if model.warningCount > 0 || model.offline { return .warn }
        return .ok
    }
}

import LutinStoreConnect
import SwiftUI

/// §7.6–7.7 — Pending changes and Apply. Every approval fact is asc's: the
/// changes come from asc's plan artifact, the approved/pending split from
/// asc's own status, the note and mode from asc's approved.json. The section
/// decides nothing itself (§4.5).
public struct StoreReviewSection: View {
    let state: StoreSectionState<StoreReviewModel>
    let hasPlan: Bool
    @Binding var reviewerNote: String
    let isConfirmingApply: Bool
    let isBusy: Bool
    let applyResult: String?
    let applyFailure: StoreFailure?
    /// An approve failure, shown under the approve controls that caused it.
    let approveFailure: StoreFailure?
    /// Why asc's status is missing, when it is. `nil` with no status means asc
    /// itself is absent — the one case the "install asc" wording belongs to.
    let statusFailure: StoreFailure?
    let actions: Actions

    public struct Actions {
        public let plan: () -> Void
        public let approveKey: (String) -> Void
        public let approveScope: (String) -> Void
        public let approveAll: () -> Void
        public let beginApply: () -> Void
        public let cancelApply: () -> Void
        public let confirmApply: () -> Void

        public init(plan: @escaping () -> Void,
                    approveKey: @escaping (String) -> Void,
                    approveScope: @escaping (String) -> Void,
                    approveAll: @escaping () -> Void,
                    beginApply: @escaping () -> Void,
                    cancelApply: @escaping () -> Void,
                    confirmApply: @escaping () -> Void) {
            self.plan = plan
            self.approveKey = approveKey
            self.approveScope = approveScope
            self.approveAll = approveAll
            self.beginApply = beginApply
            self.cancelApply = cancelApply
            self.confirmApply = confirmApply
        }
    }

    public init(state: StoreSectionState<StoreReviewModel>,
                hasPlan: Bool,
                reviewerNote: Binding<String>,
                isConfirmingApply: Bool,
                isBusy: Bool,
                applyResult: String?,
                applyFailure: StoreFailure?,
                approveFailure: StoreFailure? = nil,
                statusFailure: StoreFailure? = nil,
                actions: Actions) {
        self.state = state
        self.hasPlan = hasPlan
        self._reviewerNote = reviewerNote
        self.isConfirmingApply = isConfirmingApply
        self.isBusy = isBusy
        self.applyResult = applyResult
        self.applyFailure = applyFailure
        self.approveFailure = approveFailure
        self.statusFailure = statusFailure
        self.actions = actions
    }

    public var body: some View {
        pendingSection
        applySection
    }

    // MARK: - Pending changes (§7.6)

    private var pendingSection: some View {
        SettingsSection("Pending changes", headerMeta: { pill }) {
            switch state {
            case .loading:
                Text("Reading asc's review artifact…")
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Tokens.color(.textTertiary))
            case .failed(let failure):
                StoreSectionFailure(failure)
            case .loaded(let model):
                pendingBody(model)
            }
        }
    }

    @ViewBuilder
    private func pendingBody(_ model: StoreReviewModel) -> some View {
        if !hasPlan {
            Text("No plan yet. `Run plan` writes asc's review artifact — "
               + "it does not touch App Store Connect.")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
            LutinButton("Run plan", role: .primary, action: actions.plan)
        } else if model.isEmpty {
            Text("asc's plan has no changes — local files match the remote listing.")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
            LutinButton("Re-run plan", action: actions.plan)
        } else {
            if model.isStale {
                StatusRow(.warn, "The approval was made against an older plan; approve again.")
            }
            ForEach(model.groups) { group in
                groupHeader(group)
                ForEach(group.changes) { change in
                    changeRow(change)
                }
            }
            SettingsField("Reviewer note",
                          helper: "Written to approved.json with each approval.") {
                LutinTextField("Reviewer note", text: $reviewerNote)
            }
            HStack(spacing: Tokens.spacing(.sm)) {
                LutinButton("Approve everything", action: actions.approveAll)
                LutinButton("Run plan", action: actions.plan)
            }
            .disabled(isBusy)
            if let approveFailure {
                StoreSectionFailure(approveFailure)
            }
        }
    }

    private func groupHeader(_ group: StoreReviewModel.ScopeGroup) -> some View {
        HStack(spacing: Tokens.spacing(.sm)) {
            Text(group.title)
                .font(Typography.chromeSmall.weight(.medium))
                .foregroundStyle(Tokens.color(.textSecondary))
            Text("\(group.approvedCount)/\(group.changes.count) approved")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textTertiary))
            Spacer(minLength: 0)
            LutinButton("Approve all") { actions.approveScope(group.id) }
        }
        .padding(.horizontal, Tokens.spacing(.md))
        .padding(.top, Tokens.spacing(.sm))
        .padding(.bottom, 2)
        .disabled(isBusy)
    }

    private func changeRow(_ change: StoreReviewModel.Change) -> some View {
        HStack(alignment: .top, spacing: Tokens.spacing(.sm)) {
            Circle()
                .fill(Tokens.color(kindColor(change.kind)))
                .frame(width: 7, height: 7)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Tokens.spacing(.sm)) {
                    Text(change.title)
                        .font(.system(size: 13))
                        .foregroundStyle(Tokens.color(.textPrimary))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(change.kind.rawValue)          // "add" | "update" | "delete"
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Tokens.color(kindColor(change.kind)))
                    if change.isApproved {
                        Text("approved")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Tokens.color(.logSuccess))
                    }
                }
                Text(change.transition)
                    .font(Typography.logLine)
                    .foregroundStyle(Tokens.color(.textSecondary))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(change.reason)
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Tokens.spacing(.sm))
            if !change.isApproved {
                LutinButton("Approve", action: { actions.approveKey(change.id) })
            }
        }
        .padding(.horizontal, Tokens.spacing(.md))
        .padding(.vertical, Tokens.spacing(.xs))
        .disabled(isBusy)
    }

    private func kindColor(_ kind: StoreReviewModel.Kind) -> Tokens.Key {
        switch kind {
        case .add:    return .logSuccess
        case .update: return .logProgress
        case .delete: return .logError
        }
    }

    // MARK: - Header pill (ReleaseTab.statusPill's geometry)

    @ViewBuilder
    private var pill: some View {
        if case .loaded(let model) = state, hasPlan, !model.isEmpty {
            HStack(spacing: 5) {
                Circle().fill(pillKind(model).color).frame(width: 7, height: 7)
                Text("\(model.approvedCount)/\(model.totalCount) approved")
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

    /// asc's counts drive the pill's colour: ready, partly approved, or an
    /// approval that no longer matches the plan.
    private func pillKind(_ model: StoreReviewModel) -> StatusKind {
        if model.isStale { return .blocked }
        if model.isReady { return .ok }
        return .warn
    }

    // MARK: - Apply (§7.7)

    private var applySection: some View {
        SettingsSection("Apply") {
            if !hasPlan {
                Text("Nothing to apply yet.")
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
            } else if let applyFailure {
                StoreSectionFailure(applyFailure)
            } else {
                switch state {
                case .loading:
                    Text("Reading asc's review artifact…")
                        .font(Typography.inspectorLabel)
                        .foregroundStyle(Tokens.color(.textTertiary))
                case .failed:
                    // The failure is explained once, in Pending changes. There
                    // is nothing to apply from a plan that could not be read.
                    Text("Nothing to apply yet.")
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textTertiary))
                case .loaded(let model):
                    applyBody(model)
                }
            }
            if let applyResult {
                Text(applyResult)
                    .font(Typography.logLine)
                    .foregroundStyle(Tokens.color(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func applyBody(_ model: StoreReviewModel) -> some View {
        if !model.canApply {
            // One place decides whether Apply is offered — `canApply`. These
            // arms only say why it is not, so no branch can accidentally hand
            // back an enabled button.
            if model.isEmpty {
                StatusRow(.ok, "Nothing to apply — asc's plan has no changes.")
            } else if let statusFailure {
                // asc answered, and said no. Its own code and fix, not a guess.
                StoreSectionFailure(statusFailure)
            } else if !model.hasStatus {
                // asc is the only thing that knows what is approved. Without
                // it, Lutin says so rather than guessing.
                StatusRow(.warn, "asc's approval state is unavailable, so Lutin "
                               + "will not guess what is approved. Install asc to "
                               + "review and apply.")
            } else {
                StatusRow(.warn, "\(model.pendingCount) of \(model.totalCount) changes "
                               + "are not approved — apply needs every change approved.")
            }
        } else if isConfirmingApply {
            StatusRow(.blocked, "This writes to your live App Store listing.")
            HStack(spacing: Tokens.spacing(.sm)) {
                LutinButton("Apply now", role: .primary, action: actions.confirmApply)
                LutinButton("Cancel", action: actions.cancelApply)
            }
            .disabled(isBusy)
        } else {
            if let approval = model.approval {
                summaryRow("Mode", approval.mode)
                if let note = approval.note, !note.isEmpty {
                    summaryRow("Note", note)
                }
                if let approvedAt = approval.approvedAt {
                    summaryRow("Approved at", approvedAt)
                }
            }
            LutinButton("Apply to App Store Connect", role: .primary,
                        action: actions.beginApply)
                .disabled(isBusy)
        }
    }

    /// Label/value in `StoreAppSection`'s 156pt geometry, so a long note wraps
    /// instead of clipping the panel's edges.
    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.spacing(.sm)) {
            Text(label)
                .font(Typography.inspectorLabel)
                .foregroundStyle(Tokens.color(.textSecondary))
                .frame(width: 156, alignment: .leading)
            Text(value)
                .font(Typography.inspectorValue)
                .foregroundStyle(Tokens.color(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

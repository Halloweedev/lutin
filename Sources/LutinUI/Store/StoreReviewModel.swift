import Foundation
import LutinStoreConnect

/// §7.6–7.7's Pending changes and Apply sections, as data. Every approval fact
/// comes from asc's `status` payload; the model never decides what is approved.
public struct StoreReviewModel: Equatable {
    public enum Kind: String, Equatable {
        case add = "add"
        case update = "update"
        case delete = "delete"
    }

    public struct Change: Equatable, Identifiable {
        public let id: String          // asc's plan key
        public let scope: String
        public let locale: String
        public let version: String?
        public let field: String
        public let reason: String
        public let from: String?
        public let to: String?
        public let kind: Kind
        public let isApproved: Bool

        /// `field · locale`, the row's first line.
        public var title: String { "\(field) · \(locale)" }

        /// `<from> → <to>`, with the missing side of an add or delete implied.
        public var transition: String {
            switch (from, to) {
            case let (l?, r?): return "\(l) → \(r)"
            case let (nil, r?): return "→ \(r)"
            case let (l?, nil): return "\(l) →"
            default: return "—"
            }
        }
    }

    public struct ScopeGroup: Equatable, Identifiable {
        public let id: String          // "app-info" | "version"
        public let title: String       // "App info" | "Version"
        public let changes: [Change]
        public let approvedCount: Int
        public let pendingCount: Int
    }

    public struct Approval: Equatable {
        public let mode: String        // "all" | "key" | "scope"
        public let note: String?
        public let approvedAt: String?
    }

    public let groups: [ScopeGroup]
    public let planHash: String
    public let generatedAt: String?
    public let approval: Approval?     // nil when asc's status is unavailable
    public let isReady: Bool
    public let totalCount: Int
    public let approvedCount: Int
    public let pendingCount: Int
    public let isStale: Bool
    public let isEmpty: Bool           // a plan with no changes at all
    /// `true` when asc's `status` payload was readable. When it is `false`,
    /// `isReady` is false because Lutin will not guess an approval, and the
    /// Apply section says the approval state is unavailable rather than
    /// reporting a count it did not read.
    public let hasStatus: Bool

    /// The state before asc has written a plan at all. Honest by construction:
    /// nothing is ready, and no status was read.
    public static let empty = StoreReviewModel(
        groups: [], planHash: "", generatedAt: nil, approval: nil,
        isReady: false, totalCount: 0, approvedCount: 0, pendingCount: 0,
        isStale: false, isEmpty: true, hasStatus: false)

    /// `kind` comes from which of asc's three arrays the item was in — never
    /// from parsing `reason`, which is prose asc may reword.
    public static func make(plan: ASCReviewPlan, status: ASCReviewStatus?,
                            approval: ASCReviewApproval? = nil) -> StoreReviewModel {
        let approvedKeys = Set(status?.approvedKeys ?? [])
        func changes(_ items: [ASCReviewPlan.Item], _ kind: Kind) -> [Change] {
            items.map { item in
                Change(id: item.key, scope: item.scope, locale: item.locale,
                       version: item.version, field: item.field, reason: item.reason,
                       from: item.from, to: item.to, kind: kind,
                       isApproved: approvedKeys.contains(item.key))
            }
        }
        let all = changes(plan.plan.adds, .add) + changes(plan.plan.updates, .update)
                + changes(plan.plan.deletes, .delete)
        let groups = [("app-info", "App info"), ("version", "Version")].compactMap { id, title -> ScopeGroup? in
            let scoped = all.filter { $0.scope == id }
            guard !scoped.isEmpty else { return nil }
            return ScopeGroup(id: id, title: title, changes: scoped,
                              approvedCount: scoped.filter(\.isApproved).count,
                              pendingCount: scoped.filter { !$0.isApproved }.count)
        }
        return StoreReviewModel(
            groups: groups, planHash: plan.planHash, generatedAt: plan.generatedAt,
            approval: status == nil ? nil : approval.map {
                Approval(mode: $0.mode, note: $0.note, approvedAt: $0.approvedAt)
            },
            isReady: status?.ready ?? false,
            totalCount: status?.totalCount ?? all.count,
            approvedCount: status?.approvedCount ?? 0,
            pendingCount: status?.pendingCount ?? all.count,
            isStale: status?.isStale ?? false,
            isEmpty: all.isEmpty,
            hasStatus: status != nil)
    }
}

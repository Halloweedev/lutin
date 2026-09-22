import Foundation
import LutinCore

/// asc's persisted review artifacts, decoded — never recomputed (§4.5).
///
/// `plan.json` is asc's diff; `approved.json` is asc's approval record; the
/// `status` payload is asc's own intersection of the two. Lutin renders all
/// three. A hand-rolled diff *or* a hand-rolled approval could silently
/// disagree with the tool performing the push, and the disagreement would
/// surface as a wrong change on a live listing.
///
/// The shapes are transcribed from asc 5.3.0's
/// `internal/cli/metadata/review.go`; `schemaVersion` is the pinned contract,
/// and unknown keys are tolerated because asc may add fields.
public struct ASCReviewPlan: Decodable, Equatable, Sendable {
    public struct Item: Decodable, Equatable, Sendable, Identifiable {
        public let key: String
        public let scope: String
        public let locale: String
        public let version: String?
        public let field: String
        public let reason: String
        public let from: String?
        public let to: String?
        public var id: String { key }
    }

    public struct Plan: Decodable, Equatable, Sendable {
        public let appID: String?
        public let version: String?
        public let versionID: String?
        public let dir: String?
        public let adds: [Item]
        public let updates: [Item]
        public let deletes: [Item]

        private enum CodingKeys: String, CodingKey {
            case appID = "appId"
            case version
            case versionID = "versionId"
            case dir, adds, updates, deletes
        }
    }

    public let schemaVersion: Int
    public let generatedAt: String?
    public let planHash: String
    public let plan: Plan

    /// Every planned change, in asc's own order: adds, updates, deletes.
    public var changes: [Item] { plan.adds + plan.updates + plan.deletes }

    public static let supportedSchemaVersion = 1

    /// A decoding failure or an unsupported `schemaVersion` names the file, so
    /// a corrupted artifact is actionable rather than a mystery.
    public static func decode(_ data: Data, path: String) throws -> ASCReviewPlan {
        let plan: ASCReviewPlan
        do {
            plan = try JSONDecoder().decode(ASCReviewPlan.self, from: data)
        } catch {
            throw schemaError(path: path, reason: "\(error)")
        }
        guard plan.schemaVersion == supportedSchemaVersion else {
            throw schemaError(
                path: path,
                reason: "unsupported schemaVersion \(plan.schemaVersion); "
                      + "Lutin understands \(supportedSchemaVersion)")
        }
        return plan
    }

    static func schemaError(path: String, reason: String) -> LutinError {
        LutinError(
            code: "store_metadata_schema",
            message: "Could not read asc's review artifact at \(path): \(reason)",
            details: ["path": path])
    }
}

/// asc's approval record (`approved.json`). The reviewer note and the approval
/// mode live only here, so the Apply section reads "what was approved" from
/// this — never from a Lutin-computed set.
public struct ASCReviewApproval: Decodable, Equatable, Sendable {
    public let schemaVersion: Int
    public let approvedAt: String?
    public let planHash: String
    public let mode: String
    public let note: String?
    public let approvedKeys: [String]

    public static let supportedSchemaVersion = 1

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, approvedAt, planHash, mode, note, approvedKeys
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        approvedAt = try container.decodeIfPresent(String.self, forKey: .approvedAt)
        planHash = try container.decode(String.self, forKey: .planHash)
        mode = try container.decode(String.self, forKey: .mode)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        approvedKeys = try container.decodeIfPresent([String].self, forKey: .approvedKeys) ?? []
    }

    public static func decode(_ data: Data, path: String) throws -> ASCReviewApproval {
        let approval: ASCReviewApproval
        do {
            approval = try JSONDecoder().decode(ASCReviewApproval.self, from: data)
        } catch {
            throw ASCReviewPlan.schemaError(path: path, reason: "\(error)")
        }
        guard approval.schemaVersion == supportedSchemaVersion else {
            throw ASCReviewPlan.schemaError(
                path: path,
                reason: "unsupported schemaVersion \(approval.schemaVersion); "
                      + "Lutin understands \(supportedSchemaVersion)")
        }
        return approval
    }
}

/// `asc metadata status --output json` — asc's own approval state, so Lutin
/// never computes its own approval (§4.5).
public struct ASCReviewStatus: Decodable, Equatable, Sendable {
    public let planHash: String
    public let approvalPlanHash: String?
    public let approvalMatchesPlan: Bool
    public let ready: Bool
    public let totalCount: Int
    public let approvedCount: Int
    public let pendingCount: Int
    public let approvedKeys: [String]
    public let pendingKeys: [String]

    /// `true` when an approval exists but was made against a different plan —
    /// the UI says so and keeps Apply disabled.
    public var isStale: Bool { approvalPlanHash != nil && !approvalMatchesPlan }

    private enum CodingKeys: String, CodingKey {
        case planHash, approvalPlanHash, approvalMatchesPlan, ready
        case totalCount, approvedCount, pendingCount, approvedKeys, pendingKeys
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planHash = try container.decode(String.self, forKey: .planHash)
        approvalPlanHash = try container.decodeIfPresent(String.self, forKey: .approvalPlanHash)
        approvalMatchesPlan = try container.decode(Bool.self, forKey: .approvalMatchesPlan)
        ready = try container.decode(Bool.self, forKey: .ready)
        totalCount = try container.decode(Int.self, forKey: .totalCount)
        approvedCount = try container.decode(Int.self, forKey: .approvedCount)
        pendingCount = try container.decode(Int.self, forKey: .pendingCount)
        approvedKeys = try container.decodeIfPresent([String].self, forKey: .approvedKeys) ?? []
        pendingKeys = try container.decodeIfPresent([String].self, forKey: .pendingKeys) ?? []
    }

    /// A malformed payload names the review directory rather than reporting a
    /// mystery. `status` carries no schemaVersion of its own — `plan.json` is
    /// the pinned artifact.
    public static func decode(_ data: Data, path: String) throws -> ASCReviewStatus {
        do {
            return try JSONDecoder().decode(ASCReviewStatus.self, from: data)
        } catch {
            throw ASCReviewPlan.schemaError(path: path, reason: "\(error)")
        }
    }
}

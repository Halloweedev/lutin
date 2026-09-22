import Foundation
import LutinCore
import LutinStoreConnect

/// Spec 1a §7's Connection section, as data.
///
/// The section exists to state *which* of the five failure modes applies, each
/// with its fix — and to keep "offline" distinct from the credential failures,
/// because a connectivity blip must never be reported as an auth problem.
/// Deriving the state from (status, error, connectivity) keeps all of that
/// testable without a running `asc`.
public struct StoreConnectionSnapshot: Equatable {
    public enum State: Equatable {
        case ready
        case noWebSession
        case ascMissing
        case ascTooOld(found: String)
        case unauthenticated
        case offline
        /// A failure that is none of the five — reported honestly with whatever
        /// fix the shared suggestion table knows about, rather than squashed
        /// into a mode it isn't.
        case unexpected(code: String)
    }

    public struct Row: Equatable {
        public let label: String
        public let value: String
        /// `true`/`false` where the row itself is a pass/fail fact; `nil` where
        /// it is context.
        public let isHealthy: Bool?

        public init(label: String, value: String, isHealthy: Bool? = nil) {
            self.label = label
            self.value = value
            self.isHealthy = isHealthy
        }
    }

    public let state: State
    public let headline: String
    public let fix: String?
    public let rows: [Row]

    public var isReady: Bool { state == .ready }

    public static let offlineNote =
        "Validation and the listing preview still work offline — both are local."

    public static func make(status: StoreLogic.StoreStatusPayload?,
                            error: LutinError?,
                            isOnline: Bool) -> StoreConnectionSnapshot {
        if let error {
            return from(error: error, status: status, isOnline: isOnline)
        }
        guard let status else {
            return isOnline
                ? StoreConnectionSnapshot(state: .unexpected(code: "store_asc_failed"),
                                          headline: "asc hasn't been asked yet.",
                                          fix: nil, rows: [])
                : StoreConnectionSnapshot(state: .offline,
                                          headline: "You're offline.",
                                          fix: offlineNote, rows: [])
        }

        let state: State
        let headline: String
        if !status.authenticated {
            state = .unauthenticated
            headline = "asc is installed but not authenticated."
        } else if !status.hasWebSession {
            state = .noWebSession
            headline = "Authenticated, but no Apple ID web session."
        } else {
            state = .ready
            headline = "Connected — asc, credentials and web session are all in place."
        }
        return StoreConnectionSnapshot(state: state,
                                       headline: headline,
                                       fix: fixHint(for: state),
                                       rows: rows(from: status))
    }

    // MARK: - Deriving a state

    private static func from(error: LutinError,
                             status: StoreLogic.StoreStatusPayload?,
                             isOnline: Bool) -> StoreConnectionSnapshot {
        // `asc` missing or too old are *local* facts: connectivity cannot make
        // them true or false, so they survive being offline.
        // Credential failures can be produced by a network failure, so when the
        // machine is offline they are reported as offline instead — the spec's
        // point that a blip must not read as an auth problem.
        let state: State
        switch error.code {
        case "store_asc_missing":
            state = .ascMissing
        case "store_asc_too_old":
            state = .ascTooOld(found: error.details?["found"] ?? "unknown")
        case "store_unauthenticated":
            state = isOnline ? .unauthenticated : .offline
        case "store_web_session_missing":
            state = isOnline ? .noWebSession : .offline
        default:
            state = isOnline ? .unexpected(code: error.code) : .offline
        }

        let headline = state == .offline ? "You're offline." : error.message
        let rows = status.map(rows(from:)) ?? []
        return StoreConnectionSnapshot(state: state,
                                       headline: headline,
                                       fix: state == .offline ? offlineNote : fixHint(for: state),
                                       rows: rows)
    }

    /// Prefers the app's shared suggestion table so the GUI has one place for
    /// fix hints; falls back to the store codes' own wording, which is what the
    /// CLI messages carry today.
    static func fixHint(for state: State) -> String? {
        let code: String?
        switch state {
        case .ascMissing: code = "store_asc_missing"
        case .ascTooOld: code = "store_asc_too_old"
        case .unauthenticated: code = "store_unauthenticated"
        case .noWebSession: code = "store_web_session_missing"
        case .unexpected(let failed): code = failed
        case .ready, .offline: code = nil
        }
        if let code, let known = FixSuggestions.suggestion(for: code) { return known }

        switch state {
        case .ascMissing:
            return "Install it with `brew install asc`."
        case .ascTooOld:
            return "Run `brew upgrade asc` — Lutin needs 5.3.0 or newer."
        case .unauthenticated:
            return "Run `asc auth login`."
        case .noWebSession:
            return "Run `asc web auth login --apple-id`. 28 of asc's capabilities need a web session."
        case .ready, .offline, .unexpected:
            return nil
        }
    }

    // MARK: - Rows

    static func rows(from status: StoreLogic.StoreStatusPayload) -> [Row] {
        var rows: [Row] = [
            Row(label: "asc", value: status.ascVersion, isHealthy: true),
            Row(label: "Credential",
                value: status.credential ?? "none stored",
                isHealthy: status.authenticated),
            Row(label: "Storage", value: status.storageBackend),
            Row(label: "Environment credentials",
                value: status.environmentCredentials ? "provided" : "not set"),
            Row(label: "Web session",
                value: status.hasWebSession ? "authenticated" : "not authenticated",
                isHealthy: status.hasWebSession),
            Row(label: "App", value: status.appID ?? "resolved by asc"),
            Row(label: "Metadata files", value: "\(status.fileCount)"),
        ]
        if !status.capabilitiesByStatus.isEmpty {
            let summary = status.capabilitiesByStatus
                .sorted { $0.key < $1.key }
                .map { "\($0.value) \($0.key)" }
                .joined(separator: " · ")
            rows.append(Row(label: "Capabilities", value: summary))
        }
        return rows
    }
}

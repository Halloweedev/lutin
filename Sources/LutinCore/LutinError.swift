import Foundation

/// A typed, machine-readable error. `code` is a stable public contract.
public struct LutinError: Error, Codable, Equatable {
    public let code: String
    public let message: String
    public var details: [String: String]?

    public init(code: String, message: String, details: [String: String]? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}

/// Used when a command has a successful result but no structured payload.
public struct EmptyPayload: Codable { public init() {} }

/// The `--json` output envelope: `{ "ok", "data", "error" }`.
public struct JSONEnvelope<Payload: Encodable>: Encodable {
    public let ok: Bool
    public let data: Payload?
    public let error: LutinError?

    public static func success(_ data: Payload) -> JSONEnvelope {
        JSONEnvelope(ok: true, data: data, error: nil)
    }

    public static func failure(_ error: LutinError) -> JSONEnvelope {
        JSONEnvelope(ok: false, data: nil, error: error)
    }
}

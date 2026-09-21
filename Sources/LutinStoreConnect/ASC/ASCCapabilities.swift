import Foundation
import LutinCore

/// What asc says it can do.
///
/// Lookup is keyed by **command string**, matched against the `commands` array
/// asc emits, rather than by an abstract feature name — a hand-maintained
/// feature map would drift from the tool it describes.
public enum ASCCapabilityStatus: String, Codable, Sendable {
    case cliSupported = "cli-supported"
    case webSession = "web-session"
    case partial
    case notPublicAPI = "not-public-api"
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ASCCapabilityStatus(rawValue: raw) ?? .unknown
    }

    /// Blocked outright — asc has said this is not available over a public API.
    public var isBlocked: Bool { self == .notPublicAPI }

    /// Available only with an authenticated Apple ID web session, which is a
    /// different credential from the ASC API key. 28 of asc 5.3.0's 48
    /// capabilities are in this state.
    public var requiresWebSession: Bool { self == .webSession }
}

public struct ASCCapability: Codable, Equatable, Sendable {
    public let area: String
    public let capability: String
    public let status: ASCCapabilityStatus
    public let commands: [String]
    public let notes: [String]?
    public let nextAction: String?

    // Deviation from the brief's verbatim struct (see task report): the real
    // `capabilities.json` omits `commands` on one item (the `not-public-api`
    // "Direct REST build upload" entry, which names no asc command). Decoding
    // it as `[]` keeps `status(forCommand:)` total over the real fixture.
    private enum CodingKeys: String, CodingKey {
        case area, capability, status, commands, notes, nextAction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        area = try container.decode(String.self, forKey: .area)
        capability = try container.decode(String.self, forKey: .capability)
        status = try container.decode(ASCCapabilityStatus.self, forKey: .status)
        commands = try container.decodeIfPresent([String].self, forKey: .commands) ?? []
        notes = try container.decodeIfPresent([String].self, forKey: .notes)
        nextAction = try container.decodeIfPresent(String.self, forKey: .nextAction)
    }
}

public struct ASCCapabilities: Codable, Equatable, Sendable {
    public let capabilities: [ASCCapability]

    public static func parse(_ data: Data) throws -> ASCCapabilities {
        do {
            return try JSONDecoder().decode(ASCCapabilities.self, from: data)
        } catch {
            throw LutinError(
                code: "store_asc_failed",
                message: "Could not read `asc capabilities --output json`: \(error)",
                details: nil)
        }
    }

    public static func load(ascPath: String,
                            runner: CommandRunning) throws -> ASCCapabilities {
        let result = try runner.runAllowingFailure(ascPath, ["capabilities", "--output", "json"])
        guard result.exitCode == 0 else {
            throw LutinError(
                code: "store_asc_failed",
                message: "`asc capabilities` failed with exit \(result.exitCode).",
                details: ["stderr": result.stderr])
        }
        return try parse(Data(result.stdout.utf8))
    }

    /// The entry governing a command, matched on the longest registered
    /// command that the query starts with. Longest-match matters because
    /// `asc metadata` and `asc metadata validate` are distinct entries.
    ///
    /// A leading `asc` token is normalized away on **both** sides, so
    /// `"metadata validate"` and `"asc metadata validate"` resolve to the
    /// same entry. The bridge queries unprefixed, while asc's own `commands`
    /// array is `asc `-prefixed — 110/110 in the recorded fixture.
    public func capability(forCommand command: String) -> ASCCapability? {
        let query = normalized(command.split(whereSeparator: \.isWhitespace).map(String.init))
        var best: (length: Int, entry: ASCCapability)?
        for entry in capabilities {
            for registered in entry.commands {
                let parts = normalized(registered.split(whereSeparator: \.isWhitespace).map(String.init))
                guard !parts.isEmpty, parts.count <= query.count,
                      Array(query.prefix(parts.count)) == parts else { continue }
                if parts.count > (best?.length ?? 0) {
                    best = (parts.count, entry)
                }
            }
        }
        return best?.entry
    }

    /// The status governing a command. Absence of a matching entry is
    /// `.unknown` — allowed through, never blocked.
    public func status(forCommand command: String) -> ASCCapabilityStatus {
        capability(forCommand: command)?.status ?? .unknown
    }

    private func normalized(_ parts: [String]) -> [String] {
        parts.first == "asc" ? Array(parts.dropFirst()) : parts
    }
}

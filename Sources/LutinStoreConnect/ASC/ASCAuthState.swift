import Foundation
import LutinCore

public struct ASCCredential: Codable, Equatable, Sendable {
    public let name: String
    public let keyId: String
    public let isDefault: Bool

    public init(name: String, keyId: String, isDefault: Bool) {
        self.name = name; self.keyId = keyId; self.isDefault = isDefault
    }
}

/// Whether asc can authenticate — and with which of its two credential systems.
///
/// Lutin only reads this. It never stores, reads, or forwards credentials
/// (invariant 2 of the spec): the `.p8` key, the keychain entry, and the Apple
/// ID web session all belong to asc.
public struct ASCAuthState: Codable, Equatable, Sendable {
    public let storageBackend: String
    public let credentials: [ASCCredential]
    public let environmentCredentialsProvided: Bool
    public let environmentCredentialsComplete: Bool?

    public var hasUsableCredential: Bool {
        !credentials.isEmpty || environmentCredentialsProvided
    }

    public var defaultCredential: ASCCredential? {
        credentials.first { $0.isDefault } ?? credentials.first
    }

    public static func parse(_ data: Data) throws -> ASCAuthState {
        do {
            return try JSONDecoder().decode(ASCAuthState.self, from: data)
        } catch {
            throw LutinError(
                code: "store_asc_failed",
                message: "Could not read `asc auth status --output json`: \(error)",
                details: nil)
        }
    }

    public static func load(ascPath: String,
                            runner: CommandRunning) throws -> ASCAuthState {
        let result = try runner.runAllowingFailure(ascPath, ["auth", "status", "--output", "json"])
        guard result.exitCode == 0 else {
            throw LutinError(
                code: "store_asc_failed",
                message: "`asc auth status` failed with exit \(result.exitCode). "
                       + "Run `asc auth login`.",
                details: ["stderr": result.stderr])
        }
        return try parse(Data(result.stdout.utf8))
    }
}

/// Whether an Apple ID web session is available.
///
/// Separate from `ASCAuthState` on purpose. `asc` has two credential systems —
/// ASC API keys and Apple ID web sessions — and they authenticate different
/// command families. 28 of asc 5.3.0's 48 capabilities are `web-session`,
/// including app creation, privacy declarations, and the richer review-rejection
/// surfaces, so "authenticated" is not a single boolean.
public struct ASCWebSessionState: Codable, Equatable, Sendable {
    public let authenticated: Bool
    public let passwordStored: Bool?
    public let appleId: String?
    public let developerTeamId: String?

    public var isAvailable: Bool { authenticated }

    public static func parse(_ data: Data) throws -> ASCWebSessionState {
        do {
            return try JSONDecoder().decode(ASCWebSessionState.self, from: data)
        } catch {
            throw LutinError(
                code: "store_asc_failed",
                message: "Could not read `asc web auth status --output json`: \(error)",
                details: nil)
        }
    }

    public static func load(ascPath: String,
                            runner: CommandRunning) throws -> ASCWebSessionState {
        let result = try runner.runAllowingFailure(
            ascPath, ["web", "auth", "status", "--output", "json"])
        guard result.exitCode == 0 else {
            throw LutinError(
                code: "store_web_session_missing",
                message: "`asc web auth status` failed with exit \(result.exitCode). "
                       + "Run `asc web auth login --apple-id <email>`.",
                details: ["stderr": result.stderr])
        }
        return try parse(Data(result.stdout.utf8))
    }

    /// - Throws: `LutinError(code: "store_web_session_missing")` when no session
    ///   is available. Called before any capability that `requiresWebSession`.
    public func assertAvailable(forCapability capability: String) throws {
        guard isAvailable else {
            throw LutinError(
                code: "store_web_session_missing",
                message: "'\(capability)' needs an Apple ID web session, which is a "
                       + "different credential from your App Store Connect API key. "
                       + "Run `asc web auth login --apple-id <email>` and retry.",
                details: ["capability": capability])
        }
    }
}

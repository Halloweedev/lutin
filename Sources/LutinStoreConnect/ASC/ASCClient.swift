import Foundation
import LutinCore

public struct ASCResult<Payload: Decodable & Sendable>: Sendable {
    public let payload: Payload
    public let raw: String
    public let command: [String]
}

/// A typed invocation of `asc`.
///
/// Exit-code handling is centralised here so no caller has to remember that
/// `validate` exits 1 on findings, or that exit 2 carries no JSON at all.
public struct ASCClient: Sendable {

    public let ascPath: String
    private let runner: CommandRunning

    public init(ascPath: String, runner: CommandRunning) {
        self.ascPath = ascPath
        self.runner = runner
    }

    /// Runs asc and decodes its JSON.
    ///
    /// - Throws: a mapped `store_*` error for any non-zero exit, or
    ///   `store_asc_failed` when the output does not decode.
    public func runJSON<Payload: Decodable>(_ arguments: [String],
                                            as type: Payload.Type) throws -> ASCResult<Payload> {
        let result = try runner.runAllowingFailure(ascPath, arguments + ["--output", "json"])
        guard result.exitCode == 0 else {
            throw ASCErrorMapping.map(result: result, command: arguments,
                                      fallbackCode: "store_asc_failed")
        }
        let data = Data(result.stdout.utf8)
        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            return ASCResult(payload: payload, raw: result.stdout, command: arguments)
        } catch {
            throw LutinError(
                code: "store_asc_failed",
                message: "Could not decode `asc \(arguments.joined(separator: " "))` output: \(error)",
                details: ["ascCommand": (["asc"] + arguments).joined(separator: " ")])
        }
    }

    /// Runs asc and returns stdout verbatim.
    public func run(_ arguments: [String]) throws -> String {
        let result = try runner.runAllowingFailure(ascPath, arguments)
        guard result.exitCode == 0 else {
            throw ASCErrorMapping.map(result: result, command: arguments,
                                      fallbackCode: "store_asc_failed")
        }
        return result.stdout
    }

    /// Runs asc where exit **1** is a legitimate result.
    ///
    /// `asc metadata validate` exits 1 when the listing has errors, and the
    /// JSON on stdout is exactly what the caller needs to render. Exit 2 (schema
    /// error, no JSON) still throws.
    public func runAllowingValidationFailure(_ arguments: [String])
        throws -> (stdout: String, exitCode: Int32) {
        let result = try runner.runAllowingFailure(ascPath, arguments + ["--output", "json"])
        switch result.exitCode {
        case 0, 1:
            return (result.stdout, result.exitCode)
        default:
            throw ASCErrorMapping.map(result: result, command: arguments,
                                      fallbackCode: "store_asc_failed")
        }
    }
}

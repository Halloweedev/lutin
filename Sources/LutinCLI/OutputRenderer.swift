import Foundation
import LutinCore

/// Renders command results as human text or `--json` envelopes.
/// Commands never print directly — they hand results to this type.
public struct OutputRenderer {
    public let json: Bool
    public let verbose: Bool

    public init(json: Bool, verbose: Bool) {
        self.json = json
        self.verbose = verbose
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    public static func jsonString<D: Encodable>(success data: D) -> String {
        let envelope = JSONEnvelope.success(data)
        let bytes = (try? encoder().encode(envelope)) ?? Data()
        return String(decoding: bytes, as: UTF8.self)
    }

    public static func jsonString(failure error: LutinError) -> String {
        let envelope = JSONEnvelope<EmptyPayload>.failure(error)
        let bytes = (try? encoder().encode(envelope)) ?? Data()
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Emits a success result to stdout.
    public func success<D: Encodable>(_ data: D, human: String) {
        if json {
            print(OutputRenderer.jsonString(success: data))
        } else {
            print(human)
        }
    }

    /// Emits a failure to stderr.
    public func failure(_ error: LutinError) {
        if json {
            FileHandle.standardError.write(Data((OutputRenderer.jsonString(failure: error) + "\n").utf8))
        } else {
            FileHandle.standardError.write(Data(("Error: " + error.message + "\n").utf8))
        }
    }

    /// Prints a line only when `--verbose` is set (human mode only).
    public func verboseLine(_ line: String) {
        if verbose && !json { print(line) }
    }
}

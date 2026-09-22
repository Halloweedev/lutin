import Foundation
import LutinCore

/// A `CommandRunning` test double. Records every invocation and returns
/// scripted results. Defaults to an exit-0 empty result for unstubbed commands.
public final class FakeCommandRunner: CommandRunning {
    public struct Invocation: Equatable {
        public let executable: String
        public let arguments: [String]
    }

    public private(set) var invocations: [Invocation] = []

    private enum Outcome {
        case success(ShellResult)
        case failure(LutinError)
    }
    /// Exact-argument matches, keyed by executable then by the full argument
    /// list as one space-joined string.
    private var stubs: [String: [String: Outcome]] = [:]
    /// The per-executable catch-all, keyed by executable.
    private var catchAll: [String: Outcome] = [:]
    /// Argument-fragment matches, in insertion order.
    private var matchedStubs: [(executable: String, fragment: String, outcome: Outcome)] = []

    public init() {}

    /// Scripts a successful result for an executable path.
    public func stub(executable: String, result: ShellResult) {
        catchAll[executable] = .success(result)
    }

    /// Scripts a thrown error for an executable path.
    public func stubFailure(executable: String, error: LutinError) {
        catchAll[executable] = .failure(error)
    }

    /// Scripts a result for invocations whose exact argument list matches.
    /// Checked before the argument-fragment stubs.
    public func stub(executable: String, arguments: [String], result: ShellResult) {
        stubs[executable, default: [:]][Self.key(arguments)] = .success(result)
    }

    /// Scripts a result for invocations whose argument list contains `fragment`
    /// as an element (not a substring). Checked before the executable
    /// catch-all, after an exact-argument match — one refresh now runs several
    /// asc commands through one executable.
    public func stub(executable: String, argumentsContaining fragment: String,
                     result: ShellResult) {
        matchedStubs.append((executable, fragment, .success(result)))
    }

    public func run(_ executable: String, _ arguments: [String]) throws -> ShellResult {
        invocations.append(Invocation(executable: executable, arguments: arguments))
        switch resolve(executable, arguments) {
        case .failure(let error): throw error
        case .success(let result): return result
        case nil: return ShellResult(exitCode: 0, stdout: "", stderr: "")
        }
    }

    public func runAllowingFailure(_ executable: String,
                                   _ arguments: [String]) throws -> ShellResult {
        invocations.append(Invocation(executable: executable, arguments: arguments))
        switch resolve(executable, arguments) {
        case .failure(let error): throw error
        case .success(let result): return result
        case nil: return ShellResult(exitCode: 0, stdout: "", stderr: "")
        }
    }

    /// Exact-argument stub → argument-fragment stub (first match, in insertion
    /// order) → executable catch-all → empty success.
    private func resolve(_ executable: String,
                         _ arguments: [String]) -> Outcome? {
        if let exact = stubs[executable]?[Self.key(arguments)] { return exact }
        if let fragment = matchedStubs.first(where: {
            $0.executable == executable && arguments.contains($0.fragment)
        }) {
            return fragment.outcome
        }
        return catchAll[executable]
    }

    private static func key(_ arguments: [String]) -> String {
        arguments.joined(separator: " ")
    }

    /// Convenience: all executables invoked, in order.
    public var executables: [String] { invocations.map(\.executable) }
}

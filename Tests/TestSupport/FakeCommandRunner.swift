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
    private var stubs: [String: Outcome] = [:]

    public init() {}

    /// Scripts a successful result for an executable path.
    public func stub(executable: String, result: ShellResult) {
        stubs[executable] = .success(result)
    }

    /// Scripts a thrown error for an executable path.
    public func stubFailure(executable: String, error: LutinError) {
        stubs[executable] = .failure(error)
    }

    public func run(_ executable: String, _ arguments: [String]) throws -> ShellResult {
        invocations.append(Invocation(executable: executable, arguments: arguments))
        switch stubs[executable] {
        case .failure(let error): throw error
        case .success(let result): return result
        case nil: return ShellResult(exitCode: 0, stdout: "", stderr: "")
        }
    }

    public func runAllowingFailure(_ executable: String,
                                   _ arguments: [String]) throws -> ShellResult {
        invocations.append(Invocation(executable: executable, arguments: arguments))
        switch stubs[executable] {
        case .failure(let error): throw error
        case .success(let result): return result
        case nil: return ShellResult(exitCode: 0, stdout: "", stderr: "")
        }
    }

    /// Convenience: all executables invoked, in order.
    public var executables: [String] { invocations.map(\.executable) }
}

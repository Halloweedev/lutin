import Foundation

/// Abstraction over running an external command. Production wraps `Shell`;
/// tests inject a fake so the pipeline runs without real `codesign`/`hdiutil`.
public protocol CommandRunning {
    /// Runs `executable` with `arguments`. A non-zero exit throws a `LutinError`.
    func run(_ executable: String, _ arguments: [String]) throws -> ShellResult

    /// Runs `executable`; a non-zero exit returns the result instead of throwing.
    func runAllowingFailure(_ executable: String, _ arguments: [String]) throws -> ShellResult
}

/// Production `CommandRunning` — delegates to `Shell`.
public struct ShellCommandRunner: CommandRunning {
    public init() {}

    public func run(_ executable: String, _ arguments: [String]) throws -> ShellResult {
        try Shell.run(executable, arguments)
    }

    public func runAllowingFailure(_ executable: String,
                                   _ arguments: [String]) throws -> ShellResult {
        try Shell.run(executable, arguments, checkExit: false)
    }
}

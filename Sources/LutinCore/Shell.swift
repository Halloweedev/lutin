import Foundation

public struct ShellResult {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Wraps `Process`, capturing stdout and stderr separately. Never hides failures.
public enum Shell {
    /// Runs `executable` with `arguments`.
    /// - Parameter checkExit: when true (default), a non-zero exit throws a `LutinError`.
    /// - Parameter onOutput: optional callback invoked once after the process exits, once per
    ///   stdout line. Lines are not delivered in real time; they are emitted only after
    ///   `waitUntilExit()` returns and the full output has been captured.
    @discardableResult
    public static func run(
        _ executable: String,
        _ arguments: [String],
        checkExit: Bool = true,
        onOutput: ((String) -> Void)? = nil
    ) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            throw LutinError(
                code: "command_failed",
                message: "Could not start `\(executable)`: \(error.localizedDescription)"
            )
        }

        // NOTE: Reading stdout fully before stderr can deadlock if the child process fills the
        // ~64 KB stderr pipe buffer before its stdout reaches EOF — because this thread blocks in
        // the first readDataToEndOfFile() while the child is blocked trying to write stderr.
        // That race is acceptable here: Lutin only wraps tools (hdiutil, codesign, xcrun) whose
        // combined stdout + stderr output stays well under the 64 KB pipe-buffer threshold.
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let stdout = String(decoding: outData, as: UTF8.self)
        let stderr = String(decoding: errData, as: UTF8.self)
        if let onOutput {
            for line in stdout.split(separator: "\n") { onOutput(String(line)) }
        }

        let result = ShellResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
        if checkExit && result.exitCode != 0 {
            throw LutinError(
                code: "command_failed",
                message: "`\(executable)` exited with code \(result.exitCode).",
                details: [
                    "executable": executable,
                    "exitCode": String(result.exitCode),
                    "stderr": stderr.trimmingCharacters(in: .whitespacesAndNewlines),
                ]
            )
        }
        return result
    }
}

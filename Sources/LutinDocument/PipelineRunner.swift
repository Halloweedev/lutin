import Foundation
import Observation
import LutinCore
import LutinConfig
import LutinRelease

@Observable
public final class PipelineRunner {
    public struct LogLine: Equatable {
        public enum Kind: Equatable { case stdout, stderr, stage, success, error }
        public let kind: Kind
        public let text: String
        public let timestamp: Date
        public init(kind: Kind, text: String, timestamp: Date = Date()) {
            self.kind = kind; self.text = text; self.timestamp = timestamp
        }
    }

    public enum State: Equatable {
        case idle
        case running(stage: String, progress: Double)
        case succeeded(dmgPath: String)
        case failed(LutinError)

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.running(let s1, let p1), .running(let s2, let p2)): return s1 == s2 && p1 == p2
            case (.succeeded(let a), .succeeded(let b)): return a == b
            case (.failed(let a), .failed(let b)): return a.code == b.code
            default: return false
            }
        }
    }

    public private(set) var state: State = .idle
    public private(set) var log: [LogLine] = []
    public private(set) var lastSummary: ReleaseSummary?

    @ObservationIgnored
    private let logCapacity: Int

    public init(logCapacity: Int = 10_000) {
        self.logCapacity = logCapacity
    }

    public func append(_ line: LogLine) {
        log.append(line)
        if log.count > logCapacity { log.removeFirst(log.count - logCapacity) }
    }

    public func fail(_ error: LutinError) {
        append(LogLine(kind: .error, text: "[\(error.code)] \(error.message)"))
        state = .failed(error)
    }

    @MainActor
    public func run(mode: ReleasePipeline.Mode,
                    config: LutinConfig,
                    projectDirectory: URL) async {
        state = .running(stage: "Starting", progress: 0)
        log.removeAll()
        let runner = ShellCommandRunner()
        // DMGBuilder detaches /Volumes/<volumeName> defensively before mounting
        // its writable image, so we don't need to repeat that here. The preview
        // mount-and-open step below is GUI-specific and not part of the shared
        // pipeline (the CLI does the equivalent in CommandLogic.preview).
        do {
            let result = try await Task.detached(priority: .userInitiated) { () -> ReleasePipeline.Result in
                try ReleasePipeline.run(config: config, projectDirectory: projectDirectory,
                                        mode: mode, runner: runner) { line in
                    Task { @MainActor in
                        self.append(LogLine(kind: .stdout, text: line))
                    }
                }
            }.value
            lastSummary = result.summary
            append(LogLine(kind: .success, text: "✓ Wrote \(result.dmgPath.path)"))

            // Preview mode mirrors the CLI: mount the produced DMG and open
            // its volume in Finder so the user gets the real Finder-rendered
            // result. Use `hdiutil attach -autoopen` — Finder needs the
            // -autoopen signal to read the volume's .DS_Store fresh and show
            // the baked-in background + icon positions; without it Finder
            // serves a cached default layout on re-mounts of the same name.
            if mode == .preview {
                _ = try? runner.runAllowingFailure(
                    "/usr/bin/hdiutil",
                    ["attach", result.dmgPath.path, "-autoopen"])
                append(LogLine(kind: .stage,
                               text: "Opened \(result.dmgPath.lastPathComponent) in Finder"))
            }
            state = .succeeded(dmgPath: result.dmgPath.path)
        } catch let error as LutinError {
            fail(error)
        } catch {
            fail(LutinError(code: SP4ErrorCodes.guiRendererFailed,
                            message: error.localizedDescription))
        }
    }
}

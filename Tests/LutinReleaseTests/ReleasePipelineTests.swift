import XCTest
import CryptoKit
import TestSupport
import LutinCore
import LutinConfig
@testable import LutinRelease

final class ReleasePipelineTests: XCTestCase {
    private final class MutatingReleaseRunner: CommandRunning {
        struct Invocation: Equatable {
            let executable: String
            let arguments: [String]
        }

        private let acceptedNotaryOutput = ShellResult(
            exitCode: 0, stdout: "status: Accepted", stderr: "")

        private(set) var invocations: [Invocation] = []

        func run(_ executable: String, _ arguments: [String]) throws -> ShellResult {
            invocations.append(.init(executable: executable, arguments: arguments))
            mutateDmgArgumentIfPresent(in: arguments)
            if executable == "/usr/bin/xcrun", arguments.first == "notarytool" {
                return acceptedNotaryOutput
            }
            return ShellResult(exitCode: 0, stdout: "", stderr: "")
        }

        func runAllowingFailure(_ executable: String,
                                _ arguments: [String]) throws -> ShellResult {
            invocations.append(.init(executable: executable, arguments: arguments))
            if executable == "/usr/bin/security" {
                return ShellResult(
                    exitCode: 0,
                    stdout: "Developer ID Application: Acme (TEAM)",
                    stderr: "")
            }
            return ShellResult(exitCode: 0, stdout: "", stderr: "")
        }

        private func mutateDmgArgumentIfPresent(in arguments: [String]) {
            guard let dmgPath = arguments.first(where: { $0.hasSuffix(".dmg") }) else {
                return
            }
            let url = URL(fileURLWithPath: dmgPath)
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data("mutated\n".utf8))
        }
    }

    /// A config pointing at the Barry fixture, output in a temp dir.
    private func makeConfig(signing: Bool, notarization: Bool) -> LutinConfig {
        LutinConfig(
            project: .init(name: "Barry", bundleId: "com.anotheragence.barry"),
            app: .init(path: "./Barry.app"),
            output: .init(directory: "./release", dmgName: "Barry-${version}.dmg",
                          volumeName: "Barry"),
            window: LutinConfig.WindowInfo(width: 680, height: 420, iconSize: 96,
                textSize: 13, showToolbar: false, showSidebar: false),
            background: nil,
            items: [.init(type: "app", id: "app", x: 180, y: 220, label: "Barry"),
                    .init(type: "applications", id: "applications", x: 500, y: 220,
                          label: "Applications")],
            decorations: nil,
            signing: signing ? LutinConfig.SigningInfo(
                enabled: true, identity: "Developer ID Application: Acme (TEAM)",
                hardenedRuntime: true, entitlements: nil, signDmg: true) : nil,
            notarization: notarization ? LutinConfig.NotarizationInfo(
                enabled: true, profile: "lutin-notary", staple: true) : nil,
            sparkle: nil)
    }

    func testBuildPathProducesDmgAndSummary() throws {
        let projectDir = Fixtures.barryProject
        let outDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: outDir) }
        var config = makeConfig(signing: false, notarization: false)
        config.output.directory = outDir.path

        let result = try ReleasePipeline.run(
            config: config, projectDirectory: projectDir,
            mode: .build, runner: ShellCommandRunner())

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.summary.dmgPath))
        XCTAssertEqual(result.summary.signingStatus, "skipped")
        XCTAssertEqual(result.summary.notarizationStatus, "skipped")
    }

    func testReleasePathSignsAndNotarizesViaRunner() throws {
        let projectDir = Fixtures.barryProject
        let outDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: outDir) }
        var config = makeConfig(signing: true, notarization: true)
        config.output.directory = outDir.path

        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/security",
                  result: ShellResult(exitCode: 0,
                    stdout: "Developer ID Application: Acme (TEAM)", stderr: ""))
        fake.stub(executable: "/usr/bin/xcrun",
                  result: ShellResult(exitCode: 0, stdout: "status: Accepted", stderr: ""))

        let result = try ReleasePipeline.run(
            config: config, projectDirectory: projectDir,
            mode: .release, runner: fake, dmgRunner: ShellCommandRunner())

        XCTAssertEqual(result.summary.signingStatus, "signed")
        XCTAssertEqual(result.summary.notarizationStatus, "stapled")
        XCTAssertTrue(fake.invocations.contains { $0.executable.hasSuffix("codesign") })
        XCTAssertTrue(fake.invocations.contains {
            $0.executable.hasSuffix("xcrun") && $0.arguments.first == "notarytool" })
    }

    func testReleaseSummaryUsesFinalDmgMetadataAfterSigningAndStapling() throws {
        let projectDir = Fixtures.barryProject
        let outDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: outDir) }
        var config = makeConfig(signing: true, notarization: true)
        config.output.directory = outDir.path

        let runner = MutatingReleaseRunner()
        let result = try ReleasePipeline.run(
            config: config, projectDirectory: projectDir,
            mode: .release, runner: runner, dmgRunner: ShellCommandRunner())

        let finalData = try Data(contentsOf: result.dmgPath)
        let finalHash = SHA256.hash(data: finalData)
            .map { String(format: "%02x", $0) }
            .joined()
        XCTAssertEqual(result.summary.dmgSizeBytes, finalData.count)
        XCTAssertEqual(result.summary.sha256, finalHash)

        let summaryURL = outDir.appendingPathComponent("release-summary.json")
        let writtenSummary = try JSONDecoder().decode(
            ReleaseSummary.self,
            from: Data(contentsOf: summaryURL))
        XCTAssertEqual(writtenSummary.dmgSizeBytes, finalData.count)
        XCTAssertEqual(writtenSummary.sha256, finalHash)

        let checksums = try String(
            contentsOf: outDir.appendingPathComponent("checksums.txt"),
            encoding: .utf8)
        XCTAssertEqual(checksums, "\(finalHash)  \(result.dmgPath.lastPathComponent)\n")
    }

    func testReleaseSignsStagedAppCopyWithoutMutatingConfiguredApp() throws {
        let projectDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: projectDir) }
        let sourceApp = projectDir.appendingPathComponent("Barry.app")
        try FileManager.default.copyItem(at: Fixtures.barryApp, to: sourceApp)
        let rootBundle = sourceApp.appendingPathComponent("Lutin_LutinUI.bundle")
        try FileManager.default.createDirectory(
            at: rootBundle.appendingPathComponent("Resources"),
            withIntermediateDirectories: true)

        let outDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: outDir) }
        var config = makeConfig(signing: true, notarization: false)
        config.output.directory = outDir.path

        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/security",
                  result: ShellResult(exitCode: 0,
                    stdout: "Developer ID Application: Acme (TEAM)", stderr: ""))

        _ = try ReleasePipeline.run(
            config: config,
            projectDirectory: URL(fileURLWithPath: projectDir.path, isDirectory: true),
            mode: .release, runner: fake, dmgRunner: ShellCommandRunner())

        XCTAssertTrue(FileManager.default.fileExists(atPath: rootBundle.path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: sourceApp
                .appendingPathComponent("Contents/Resources/Lutin_LutinUI.bundle")
                .path))
    }

    func testReleaseThrowsInvalidConfigWhenSigningEnabledButIdentityNil() throws {
        let projectDir = Fixtures.barryProject
        let outDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: outDir) }
        // Build a config with signing.enabled = true but signing.identity = nil.
        var config = LutinConfig(
            project: .init(name: "Barry", bundleId: "com.anotheragence.barry"),
            app: .init(path: "./Barry.app"),
            output: .init(directory: outDir.path, dmgName: "Barry-${version}.dmg",
                          volumeName: "Barry"),
            window: LutinConfig.WindowInfo(width: 680, height: 420, iconSize: 96,
                textSize: 13, showToolbar: false, showSidebar: false),
            background: nil,
            items: [.init(type: "app", id: "app", x: 180, y: 220, label: "Barry"),
                    .init(type: "applications", id: "applications", x: 500, y: 220,
                          label: "Applications")],
            decorations: nil,
            signing: LutinConfig.SigningInfo(
                enabled: true, identity: nil,
                hardenedRuntime: true, entitlements: nil, signDmg: false),
            notarization: nil,
            sparkle: nil)
        config.output.directory = outDir.path

        let fake = FakeCommandRunner()
        XCTAssertThrowsError(
            try ReleasePipeline.run(config: config, projectDirectory: projectDir,
                                    mode: .release, runner: fake,
                                    dmgRunner: ShellCommandRunner())
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "invalid_config")
        }
    }

    func testReleaseWithSigningAndNotarizationDisabledStillBuilds() throws {
        let projectDir = Fixtures.barryProject
        let outDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: outDir) }
        var config = makeConfig(signing: false, notarization: false)
        config.output.directory = outDir.path
        let result = try ReleasePipeline.run(
            config: config, projectDirectory: projectDir,
            mode: .release, runner: ShellCommandRunner())
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.summary.dmgPath))
        XCTAssertEqual(result.summary.signingStatus, "skipped")
        XCTAssertEqual(result.summary.notarizationStatus, "skipped")
    }

    func testReleaseThrowsInvalidConfigWhenNotarizationEnabledWithoutSigning() throws {
        let projectDir = Fixtures.barryProject
        let outDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: outDir) }
        var config = makeConfig(signing: false, notarization: true)
        config.output.directory = outDir.path
        let runner = FakeCommandRunner()

        XCTAssertThrowsError(
            try ReleasePipeline.run(config: config, projectDirectory: projectDir,
                                    mode: .release, runner: runner,
                                    dmgRunner: runner)
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "invalid_config")
        }
        XCTAssertTrue(runner.invocations.isEmpty)
    }
}

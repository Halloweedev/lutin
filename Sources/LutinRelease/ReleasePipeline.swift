import Foundation
import LutinCore
import LutinConfig
import LutinBuilder
import LutinSigning
import LutinNotarization
import LutinRender

/// Orchestrates the build / release pipeline over the builder, signer, and
/// notarizer. The single entry point the CLI (and later the GUI) calls.
public enum ReleasePipeline {
    public enum Mode { case build, release, preview }

    public struct Result {
        public let summary: ReleaseSummary
        public let dmgPath: URL
        public let plannedSteps: [String]
    }

    /// Runs the pipeline.
    /// - Parameters:
    ///   - runner: used for signing/notarization tools (fakeable in tests).
    ///   - dmgRunner: used for `hdiutil` (defaults to the same runner; tests
    ///     pass a real `ShellCommandRunner` so DMGs are genuinely built).
    public static func run(config: LutinConfig, projectDirectory: URL,
                           mode: Mode, runner: CommandRunning,
                           dmgRunner: CommandRunning? = nil,
                           onOutput: ((String) -> Void)? = nil) throws -> Result {
        let dmgRunner = dmgRunner ?? runner

        // Resolve app bundle + version.
        let appURL = URL(fileURLWithPath: config.app.path, relativeTo: projectDirectory)
            .standardizedFileURL
        let info = try InfoPlistReader.read(appBundle: appURL)
        let tokenContext = TokenResolver.Context(version: info.shortVersion,
                                                 name: config.project.name)
        let dmgName = TokenResolver.resolve(config.output.dmgName, tokenContext)
        let volumeName = TokenResolver.resolve(config.output.volumeName, tokenContext)
        let outDir = URL(fileURLWithPath: config.output.directory,
                         relativeTo: projectDirectory).standardizedFileURL

        // release mode: sign the app first (inner-to-outer).
        var signingStatus = "skipped"
        if mode == .release, let signing = config.signing, signing.enabled {
            guard let identity = signing.identity, !identity.isEmpty else {
                throw LutinError(code: "invalid_config",
                                 message: "signing.identity is required when signing.enabled is true.")
            }
            try CodeSigner.verifyIdentityExists(identity, runner: runner)
            let entitlements = signing.entitlements.map {
                URL(fileURLWithPath: $0, relativeTo: projectDirectory).path
            }
            try CodeSigner.signApp(appURL, identity: identity,
                                   entitlements: entitlements, runner: runner)
            signingStatus = "signed"
        }

        // Resolve layout + background, then build the DMG (real hdiutil).
        let layout = try LayoutResolver.resolve(config: config,
                                                appFileName: appURL.lastPathComponent)
        let background = try renderedBackground(config: config,
                                                projectDirectory: projectDirectory,
                                                onOutput: onOutput)
        let volumeIcon = resolveVolumeIcon(projectDirectory: projectDirectory)
        let request = BuildRequest(
            appBundle: appURL, outputDirectory: outDir, dmgName: dmgName,
            volumeName: volumeName, layout: layout, backgroundImage: background,
            volumeIcon: volumeIcon)
        let build = try DMGBuilder.build(request, dryRun: false, runner: dmgRunner, onOutput: onOutput)
        guard let dmgPath = build.dmgPath else {
            throw LutinError(code: "convert_failed",
                             message: "The build did not produce a DMG.")
        }

        // release mode: sign the DMG, notarize, staple.
        var notarizationStatus = "skipped"
        if mode == .release {
            if let signing = config.signing, signing.enabled,
               signing.signDmg == true {
                guard let identity = signing.identity, !identity.isEmpty else {
                    throw LutinError(code: "invalid_config",
                                     message: "signing.identity is required when signing.enabled is true.")
                }
                try CodeSigner.signDMG(dmgPath, identity: identity,
                                       runner: runner)
            }
            if let notarization = config.notarization, notarization.enabled {
                guard let profile = notarization.profile, !profile.isEmpty else {
                    throw LutinError(code: "invalid_config",
                                     message: "notarization.profile is required when notarization.enabled is true.")
                }
                try Notarizer.submit(dmg: dmgPath,
                                     profile: profile,
                                     runner: runner)
                notarizationStatus = "notarized"
                if notarization.staple == true {
                    try Stapler.staple(dmgPath, runner: runner)
                    notarizationStatus = "stapled"
                }
            }
        }

        // Build the summary; write it for release mode.
        let formatter = ISO8601DateFormatter()
        let summary = ReleaseSummary(
            projectName: config.project.name,
            appName: appURL.lastPathComponent,
            bundleId: config.project.bundleId,
            version: info.shortVersion,
            buildNumber: info.bundleVersion,
            dmgPath: dmgPath.path,
            dmgSizeBytes: build.sizeBytes ?? 0,
            sha256: build.sha256 ?? "",
            signingStatus: signingStatus,
            notarizationStatus: notarizationStatus,
            timestamp: formatter.string(from: Date()))
        if mode == .release {
            try summary.write(toDirectory: outDir)
        }
        return Result(summary: summary, dmgPath: dmgPath, plannedSteps: build.plannedSteps)
    }

    /// Produces the background image to embed. Renders via `LutinRender` when
    /// the config asks for a generated background or carries decorations;
    /// otherwise falls back to the plain user-image resolution.
    static func renderedBackground(config: LutinConfig, projectDirectory: URL,
                                   onOutput: ((String) -> Void)?) throws -> URL? {
        let hasDecorations = !(config.decorations ?? []).isEmpty
        let isGenerated = (config.background?.type ?? "") == "generated"
        if isGenerated || hasDecorations {
            return try LutinRenderer.renderBackground(
                config: config, projectDirectory: projectDirectory, onOutput: onOutput)
        }
        return resolveBackground(config: config, projectDirectory: projectDirectory)
    }

    /// Resolves the background image: explicit `background.path`, else the
    /// `assets/background.png` convention, else none.
    public static func resolveBackground(config: LutinConfig,
                                         projectDirectory: URL) -> URL? {
        if let path = config.background?.path {
            return URL(fileURLWithPath: path, relativeTo: projectDirectory)
                .standardizedFileURL
        }
        let convention = projectDirectory
            .appendingPathComponent("assets/background.png")
        return FileManager.default.fileExists(atPath: convention.path)
            ? convention : nil
    }

    /// Resolves the volume icon via the `assets/VolumeIcon.icns` convention.
    public static func resolveVolumeIcon(projectDirectory: URL) -> URL? {
        let convention = projectDirectory
            .appendingPathComponent("assets/VolumeIcon.icns")
        return FileManager.default.fileExists(atPath: convention.path)
            ? convention : nil
    }
}

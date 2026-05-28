import Foundation
import LutinCore

/// Makes a packaged `.app` self-contained by embedding the dynamic
/// frameworks its binary links against via `@rpath` (e.g. SwiftPM-built
/// `KeylightSDK.framework`). Without this, the bundle launches and `dyld`
/// immediately aborts with "Library not loaded: @rpath/…".
public enum FrameworkEmbedder {
    /// Names of `@rpath/<Name>.framework` dependencies in `otool -L` output.
    /// System frameworks (absolute `/System/...` paths) are ignored — only
    /// `@rpath` entries are candidates for embedding.
    public static func rpathFrameworkNames(fromOtoolOutput output: String) -> [String] {
        var names: [String] = []
        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("@rpath/") else { continue }
            // "@rpath/KeylightSDK.framework/Versions/A/KeylightSDK (compatibility …)"
            let path = line.split(separator: " ", maxSplits: 1).first.map(String.init) ?? line
            guard let fwComponent = path.split(separator: "/")
                .first(where: { $0.hasSuffix(".framework") }) else { continue }
            let name = String(fwComponent.dropLast(".framework".count))
            if !name.isEmpty, !names.contains(name) { names.append(name) }
        }
        return names
    }

    /// Embeds each `@rpath` framework the app binary links against, copying it
    /// from `searchDirectory` into `Contents/Frameworks/`, then adds the
    /// `@executable_path/../Frameworks` rpath to the binary if it isn't already
    /// present. Returns the names actually embedded.
    ///
    /// No-op for binaries with no `@rpath` framework deps (e.g. a pure CLI).
    /// Frameworks not found in `searchDirectory` are skipped — only what sits
    /// alongside the build output gets bundled.
    @discardableResult
    public static func embed(appBundle: URL, binaryName: String,
                             searchDirectory: URL,
                             onOutput: ((String) -> Void)? = nil) throws -> [String] {
        let fm = FileManager.default
        let appBinary = appBundle.appendingPathComponent("Contents/MacOS/\(binaryName)")
        guard fm.fileExists(atPath: appBinary.path) else { return [] }

        let linked = rpathFrameworkNames(
            fromOtoolOutput: try runTool("/usr/bin/otool", ["-L", appBinary.path]))
        guard !linked.isEmpty else { return [] }

        let frameworksDir = appBundle
            .appendingPathComponent("Contents/Frameworks", isDirectory: true)
        var embedded: [String] = []
        for name in linked {
            let src = searchDirectory.appendingPathComponent("\(name).framework")
            guard fm.fileExists(atPath: src.path) else { continue }
            if !fm.fileExists(atPath: frameworksDir.path) {
                try fm.createDirectory(at: frameworksDir, withIntermediateDirectories: true)
            }
            let dest = frameworksDir.appendingPathComponent("\(name).framework")
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.copyItem(at: src, to: dest)
            embedded.append(name)
            onOutput?("Embedded \(name).framework")
        }
        guard !embedded.isEmpty else { return [] }

        // install_name_tool errors if the rpath already exists, so check first.
        let loadCommands = try runTool("/usr/bin/otool", ["-l", appBinary.path])
        if !loadCommands.contains("@executable_path/../Frameworks") {
            _ = try runTool("/usr/bin/install_name_tool",
                            ["-add_rpath", "@executable_path/../Frameworks", appBinary.path])
            onOutput?("Added rpath @executable_path/../Frameworks")
        }
        return embedded
    }

    private static func runTool(_ launchPath: String, _ args: [String]) throws -> String {
        let proc = Process()
        proc.launchPath = launchPath
        proc.arguments = args
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        try proc.run()
        proc.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        if proc.terminationStatus != 0 {
            let errText = String(data: err.fileHandleForReading.readDataToEndOfFile(),
                                 encoding: .utf8) ?? ""
            throw LutinError(
                code: "app_packager_framework_embed_failed",
                message: "\(launchPath) failed (\(proc.terminationStatus)): "
                       + errText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

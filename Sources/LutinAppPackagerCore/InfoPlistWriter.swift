import Foundation
import LutinCore

/// Writes a macOS `Info.plist` for a Lutin-produced `.app` bundle.
///
/// The dict mirrors what `xcodebuild` would emit for a SwiftUI app:
/// the standard CFBundle/LS keys, the `DT*` and `BuildMachineOSBuild`
/// provenance keys (read from the current Xcode CLT via `xcrun`),
/// and any partial dictionary from `actool` (icon keys) merged in.
///
/// macOS Finder / LaunchServices treat apps missing the `DT*` fingerprint
/// as suspicious; that downgrades trust in ways that can affect e.g. DMG
/// window decoration on macOS 14+. Matching Xcode's output as closely as
/// possible keeps lutin-packaged apps in the trusted lane.
///
/// Error codes emitted:
/// - `app_packager_layout_invalid`: serialization or write failed.
public enum InfoPlistWriter {
    public static func write(_ spec: AppBundleSpec, to url: URL,
                             extraKeys: [String: Any] = [:]) throws {
        var dict: [String: Any] = [
            "CFBundleName": spec.bundleName,
            "CFBundleDisplayName": spec.bundleName,
            "CFBundleExecutable": spec.bundleName,
            "CFBundleIdentifier": spec.bundleIdentifier,
            "CFBundleVersion": spec.buildNumber,
            "CFBundleShortVersionString": spec.shortVersion,
            "CFBundlePackageType": "APPL",
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleDevelopmentRegion": "en",
            "CFBundleSupportedPlatforms": ["MacOSX"],
            "LSMinimumSystemVersion": spec.minimumSystemVersion,
            "NSHighResolutionCapable": true,
            "NSPrincipalClass": "NSApplication",
            "CFBundleIconFile": "AppIcon",
        ]

        // Xcode build-provenance keys — read from the current toolchain so
        // the values match what an `xcodebuild` invocation right now would
        // produce. Missing tools just skip the key.
        let provenance = readProvenance()
        for (k, v) in provenance { dict[k] = v }

        // Merge actool's partial Info.plist (icon-related keys).
        for (k, v) in extraKeys { dict[k] = v }

        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: dict, format: .xml, options: 0)
            try data.write(to: url, options: .atomic)
        } catch {
            throw LutinError(code: "app_packager_layout_invalid",
                             message: "Could not write Info.plist: \(error.localizedDescription)")
        }
    }

    /// Reads the active Xcode + SDK + OS-build identifiers via `xcrun` /
    /// `xcodebuild` / `sw_vers`. Returns the keys Xcode would auto-populate.
    /// All probes are best-effort — a missing tool returns no key.
    private static func readProvenance() -> [String: Any] {
        var out: [String: Any] = ["DTPlatformName": "macosx",
                                  "DTCompiler": "com.apple.compilers.llvm.clang.1_0"]

        if let xcv = run("/usr/bin/xcodebuild", ["-version"])?
                .split(separator: "\n").map(String.init) {
            // Lines look like:
            //   Xcode 26.3
            //   Build version 17C529
            if let line1 = xcv.first,
               let ver = line1.split(separator: " ").dropFirst().first {
                out["DTXcode"] = String(ver).replacingOccurrences(of: ".", with: "")
            }
            if xcv.count > 1, let last = xcv.last?.split(separator: " ").last {
                out["DTXcodeBuild"] = String(last)
            }
        }
        if let sdkVer = run("/usr/bin/xcrun",
                            ["--sdk", "macosx", "--show-sdk-version"]) {
            out["DTSDKName"] = "macosx\(sdkVer.trimmingCharacters(in: .whitespacesAndNewlines))"
            out["DTPlatformVersion"] = sdkVer.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let sdkBuild = run("/usr/bin/xcrun",
                              ["--sdk", "macosx", "--show-sdk-build-version"]) {
            let trimmed = sdkBuild.trimmingCharacters(in: .whitespacesAndNewlines)
            out["DTSDKBuild"] = trimmed
            out["DTPlatformBuild"] = trimmed
        }
        if let osb = run("/usr/bin/sw_vers", ["-buildVersion"]) {
            out["BuildMachineOSBuild"] = osb.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return out
    }

    private static func run(_ launchPath: String, _ args: [String]) -> String? {
        let proc = Process()
        proc.launchPath = launchPath
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do { try proc.run() } catch { return nil }
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}

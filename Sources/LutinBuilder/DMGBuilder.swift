import Foundation
import CryptoKit
import LutinCore

/// Inputs for a minimal DMG build. All token resolution happens before this.
public struct BuildRequest {
    public let appBundle: URL
    public let outputDirectory: URL
    public let dmgName: String
    public let volumeName: String

    public init(appBundle: URL, outputDirectory: URL, dmgName: String, volumeName: String) {
        self.appBundle = appBundle
        self.outputDirectory = outputDirectory
        self.dmgName = dmgName
        self.volumeName = volumeName
    }
}

public struct BuildResult {
    public let dryRun: Bool
    public let plannedSteps: [String]
    public let dmgPath: URL?
    public let sizeBytes: Int?
    public let sha256: String?
}

/// Minimal builder: staging folder + `/Applications` symlink + `hdiutil create`.
/// No signing, no Finder layout, no background — those arrive in sub-project 2/3.
public enum DMGBuilder {
    public static func build(_ request: BuildRequest, dryRun: Bool,
                             onOutput: ((String) -> Void)? = nil) throws -> BuildResult {
        let dmgPath = request.outputDirectory.appendingPathComponent(request.dmgName)
        let steps = [
            "Validate app bundle at \(request.appBundle.path)",
            "Create staging folder with \(request.appBundle.lastPathComponent) + /Applications symlink",
            "hdiutil create -format UDZO -volname \(request.volumeName) → \(dmgPath.path)",
            "Compute size and SHA-256",
        ]
        if dryRun {
            return BuildResult(dryRun: true, plannedSteps: steps,
                               dmgPath: nil, sizeBytes: nil, sha256: nil)
        }

        // 1. Validate the app bundle.
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: request.appBundle.path, isDirectory: &isDir)
        guard exists, isDir.boolValue, request.appBundle.pathExtension == "app" else {
            throw LutinError(
                code: "app_bundle_invalid",
                message: "Not a valid .app bundle: \(request.appBundle.path).",
                details: ["path": request.appBundle.path]
            )
        }

        let fm = FileManager.default
        // 2. Staging folder.
        let staging = fm.temporaryDirectory.appendingPathComponent("lutin-stage-\(UUID().uuidString)")
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }

        try fm.copyItem(at: request.appBundle,
                        to: staging.appendingPathComponent(request.appBundle.lastPathComponent))
        try fm.createSymbolicLink(at: staging.appendingPathComponent("Applications"),
                                  withDestinationURL: URL(fileURLWithPath: "/Applications"))

        // 3. Output directory + hdiutil.
        try fm.createDirectory(at: request.outputDirectory, withIntermediateDirectories: true)
        if fm.fileExists(atPath: dmgPath.path) { try fm.removeItem(at: dmgPath) }

        try Shell.run("/usr/bin/hdiutil", [
            "create", "-format", "UDZO", "-fs", "HFS+",
            "-volname", request.volumeName,
            "-srcfolder", staging.path,
            dmgPath.path,
        ], onOutput: onOutput)

        // 4. Size + SHA-256.
        let attrs = try fm.attributesOfItem(atPath: dmgPath.path)
        let size = (attrs[.size] as? Int) ?? 0
        let digest = SHA256.hash(data: try Data(contentsOf: dmgPath))
        let hex = digest.map { String(format: "%02x", $0) }.joined()

        return BuildResult(dryRun: false, plannedSteps: steps,
                           dmgPath: dmgPath, sizeBytes: size, sha256: hex)
    }
}

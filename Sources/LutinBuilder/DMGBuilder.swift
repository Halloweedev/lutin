import Foundation
import CryptoKit
import LutinCore

/// Inputs for a full laid-out DMG build. All token resolution and layout
/// resolution happen upstream.
public struct BuildRequest {
    public let appBundle: URL
    public let outputDirectory: URL
    public let dmgName: String
    public let volumeName: String
    public let layout: DMGLayout
    /// A background image to embed, or nil for a plain background.
    public let backgroundImage: URL?
    /// A `.icns` volume icon to apply, or nil to leave the default.
    public let volumeIcon: URL?

    public init(appBundle: URL, outputDirectory: URL, dmgName: String,
                volumeName: String, layout: DMGLayout,
                backgroundImage: URL?, volumeIcon: URL?) {
        self.appBundle = appBundle
        self.outputDirectory = outputDirectory
        self.dmgName = dmgName
        self.volumeName = volumeName
        self.layout = layout
        self.backgroundImage = backgroundImage
        self.volumeIcon = volumeIcon
    }
}

public struct BuildResult {
    public let dryRun: Bool
    public let plannedSteps: [String]
    public let dmgPath: URL?
    public let sizeBytes: Int?
    public let sha256: String?
}

extension BuildResult: Encodable {
    enum CodingKeys: String, CodingKey {
        case dryRun, plannedSteps, dmgPath, sizeBytes, sha256
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(dryRun, forKey: .dryRun)
        try c.encode(plannedSteps, forKey: .plannedSteps)
        try c.encodeIfPresent(dmgPath?.path, forKey: .dmgPath)
        try c.encodeIfPresent(sizeBytes, forKey: .sizeBytes)
        try c.encodeIfPresent(sha256, forKey: .sha256)
    }
}

/// Builds a full laid-out DMG: writable image → stage app + symlink +
/// background + `.DS_Store` → convert to compressed.
public enum DMGBuilder {
    public static func build(_ request: BuildRequest, dryRun: Bool,
                             runner: CommandRunning = ShellCommandRunner(),
                             onOutput: ((String) -> Void)? = nil) throws -> BuildResult {
        let dmgPath = request.outputDirectory.appendingPathComponent(request.dmgName)
        let steps = [
            "Validate app bundle at \(request.appBundle.path)",
            "Create writable DMG and mount it",
            "Copy \(request.appBundle.lastPathComponent) + /Applications symlink",
            request.backgroundImage == nil
                ? "No background image" : "Embed background image",
            request.volumeIcon == nil
                ? "No volume icon" : "Apply volume icon",
            "Write .DS_Store window layout",
            "Unmount and convert to compressed UDZO",
            "Compute size and SHA-256",
        ]
        if dryRun {
            return BuildResult(dryRun: true, plannedSteps: steps,
                               dmgPath: nil, sizeBytes: nil, sha256: nil)
        }

        let fm = FileManager.default

        // 1. Validate the app bundle.
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: request.appBundle.path, isDirectory: &isDir),
              isDir.boolValue, request.appBundle.pathExtension == "app" else {
            throw LutinError(code: "app_bundle_invalid",
                             message: "Not a valid .app bundle: \(request.appBundle.path).",
                             details: ["path": request.appBundle.path])
        }

        // 1b. Validate the background image up front.
        if let bg = request.backgroundImage, !fm.fileExists(atPath: bg.path) {
            throw LutinError(code: "background_not_found",
                             message: "Background image not found at \(bg.path).",
                             details: ["path": bg.path])
        }

        // 2. Create + mount a writable image. Size it generously from the app.
        let workDir = fm.temporaryDirectory
            .appendingPathComponent("lutin-build-\(UUID().uuidString)")
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: workDir) }

        let rwDMG = workDir.appendingPathComponent("work.dmg")
        let appSize = directorySizeBytes(request.appBundle)
        // 20 MB floor; 30 MB headroom for .background, .DS_Store, symlink, and filesystem overhead.
        let megabytes = max(20, appSize / 1_000_000 + 30)
        try DiskImage.createWritable(at: rwDMG, volumeName: request.volumeName,
                                     megabytes: megabytes, runner: runner)
        let mount = try DiskImage.mount(rwDMG, runner: runner)
        var unmounted = false
        defer { if !unmounted { try? DiskImage.unmount(mount, runner: runner) } }

        // 3. Stage: copy the app, create the /Applications symlink.
        try fm.copyItem(at: request.appBundle,
                        to: mount.mountPoint.appendingPathComponent(
                            request.appBundle.lastPathComponent))
        try fm.createSymbolicLink(
            at: mount.mountPoint.appendingPathComponent("Applications"),
            withDestinationURL: URL(fileURLWithPath: "/Applications"))

        // 4. Embed the background image into a hidden .background folder.
        var background: DSStoreRecords.Background = .none
        if let bg = request.backgroundImage {
            let bgDir = mount.mountPoint.appendingPathComponent(".background")
            try fm.createDirectory(at: bgDir, withIntermediateDirectories: true)
            try fm.copyItem(at: bg, to: bgDir.appendingPathComponent("background.png"))
            let alias = AliasRecord.encode(
                volumeName: request.volumeName,
                fileName: "background.png",
                posixPath: "/Volumes/\(request.volumeName)/.background/background.png")
            background = .image(alias: alias)
        }

        // 4b. Apply the volume icon, if one was provided and exists.
        //     Best-effort: a missing icon or a missing `SetFile` is not fatal.
        if let icon = request.volumeIcon, fm.fileExists(atPath: icon.path) {
            let dest = mount.mountPoint.appendingPathComponent(".VolumeIcon.icns")
            if (try? fm.copyItem(at: icon, to: dest)) != nil {
                // Set the volume's "has custom icon" Finder flag (best-effort).
                _ = try? runner.runAllowingFailure(
                    "/usr/bin/SetFile", ["-a", "C", mount.mountPoint.path])
                onOutput?("Applied volume icon")
            } else {
                onOutput?("Warning: could not copy volume icon — skipped")
            }
        }

        // 5. Write the .DS_Store.
        let dsStore = try DSStoreEncoder.encode(layout: request.layout,
                                                background: background)
        do {
            try dsStore.write(to: mount.mountPoint.appendingPathComponent(".DS_Store"))
        } catch {
            throw LutinError(code: "layout_failed",
                             message: "Could not write the .DS_Store layout: \(error).")
        }

        // 6. Unmount and convert.
        try DiskImage.unmount(mount, runner: runner)
        unmounted = true
        try fm.createDirectory(at: request.outputDirectory, withIntermediateDirectories: true)
        try DiskImage.convertToCompressed(source: rwDMG, destination: dmgPath, runner: runner)

        // 7. Size + SHA-256.
        let attrs = try fm.attributesOfItem(atPath: dmgPath.path)
        let size = (attrs[.size] as? Int) ?? 0
        // Maps the whole DMG into memory — acceptable for typical app-DMG sizes;
        // revisit if targeting multi-GB payloads.
        let digest = SHA256.hash(data: try Data(contentsOf: dmgPath))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        onOutput?("Built \(dmgPath.lastPathComponent)")

        return BuildResult(dryRun: false, plannedSteps: steps,
                           dmgPath: dmgPath, sizeBytes: size, sha256: hex)
    }

    /// Recursive byte size of a directory tree.
    private static func directorySizeBytes(_ url: URL) -> Int {
        let fm = FileManager.default
        // Returning 0 on enumerator failure is intentional: the max(20, …) floor covers it,
        // and an invalid app bundle is caught earlier by validation.
        guard let walker = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        else { return 0 }
        var total = 0
        for case let item as URL in walker {
            total += (try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        }
        return total
    }
}

import Foundation
import LutinCore

/// A mounted disk image: the device node and the mount-point directory.
public struct MountedImage {
    public let device: String
    public let mountPoint: URL
}

/// Thin wrappers over `hdiutil` for the writable-DMG → mount → convert flow.
public enum DiskImage {
    private static let hdiutil = "/usr/bin/hdiutil"

    /// Creates an empty writable (`UDRW`) HFS+ disk image.
    public static func createWritable(at url: URL, volumeName: String,
                                      megabytes: Int, runner: CommandRunning) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        do {
            // -layout NONE suppresses the Apple Partition Map; the writable DMG is an intermediate artifact.
            _ = try runner.run(hdiutil, [
                "create", "-size", "\(megabytes)m", "-fs", "HFS+",
                "-volname", volumeName, "-layout", "NONE", url.path,
            ])
        } catch let error as LutinError {
            throw LutinError(code: "create_failed",
                             message: "Could not create the writable DMG: \(error.message)",
                             details: error.details)
        }
    }

    /// Mounts an image and returns its device + mount point.
    /// Parses `hdiutil attach -plist` output for the mount point.
    public static func mount(_ url: URL, runner: CommandRunning) throws -> MountedImage {
        let result: ShellResult
        do {
            result = try runner.run(hdiutil, [
                "attach", url.path, "-nobrowse", "-noverify", "-noautoopen", "-plist",
            ])
        } catch let error as LutinError {
            throw LutinError(code: "mount_failed",
                             message: "Could not mount \(url.lastPathComponent): \(error.message)",
                             details: error.details)
        }
        guard let plistData = result.stdout.data(using: .utf8) else {
            throw LutinError(code: "mount_failed",
                             message: "Could not parse hdiutil attach output for \(url.path).")
        }
        let rawPlist: Any
        do {
            rawPlist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)
        } catch {
            throw LutinError(code: "mount_failed",
                             message: "Could not parse hdiutil output: \(error.localizedDescription)")
        }
        guard let plist = rawPlist as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]]
        else {
            throw LutinError(code: "mount_failed",
                             message: "Could not parse hdiutil attach output for \(url.path).")
        }
        // The entity carrying a mount-point is the mounted volume.
        for entity in entities {
            if let mountPoint = entity["mount-point"] as? String,
               let device = entity["dev-entry"] as? String {
                return MountedImage(device: device,
                                    mountPoint: URL(fileURLWithPath: mountPoint))
            }
        }
        throw LutinError(code: "mount_failed",
                         message: "hdiutil attach produced no mount point for \(url.path).")
    }

    /// Detaches a mounted image.
    public static func unmount(_ image: MountedImage, runner: CommandRunning) throws {
        do {
            _ = try runner.run(hdiutil, ["detach", image.device])
        } catch let firstError as LutinError {
            // Retry once with -force before giving up.
            let forced = try runner.runAllowingFailure(hdiutil, ["detach", image.device, "-force"])
            if forced.exitCode != 0 {
                throw LutinError(
                    code: "unmount_failed",
                    message: "Could not detach \(image.device): \(firstError.message)",
                    details: firstError.details
                )
            }
        }
    }

    /// Converts a writable image to a compressed read-only `UDZO` image.
    public static func convertToCompressed(source: URL, destination: URL,
                                           runner: CommandRunning) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        var converted = false
        // If `hdiutil convert` fails mid-write, drop the truncated output so it
        // doesn't linger in the user's output directory.
        defer { if !converted { try? FileManager.default.removeItem(at: destination) } }
        do {
            _ = try runner.run(hdiutil, [
                "convert", source.path, "-format", "UDZO", "-o", destination.path,
            ])
        } catch let error as LutinError {
            throw LutinError(code: "convert_failed",
                             message: "Could not compress the DMG: \(error.message)",
                             details: error.details)
        }
        converted = true
    }
}

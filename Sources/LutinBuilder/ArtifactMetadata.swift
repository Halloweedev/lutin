import Foundation
import CryptoKit
import LutinCore

/// File metadata that must describe the bytes currently on disk.
public struct ArtifactMetadata: Equatable {
    public let sizeBytes: Int
    public let sha256: String

    public init(sizeBytes: Int, sha256: String) {
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
    }

    public static func read(from url: URL) throws -> ArtifactMetadata {
        let fm = FileManager.default
        do {
            let attrs = try fm.attributesOfItem(atPath: url.path)
            let size = (attrs[.size] as? Int) ?? 0
            let digest = try sha256(url)
            let hex = digest.map { String(format: "%02x", $0) }.joined()
            return ArtifactMetadata(sizeBytes: size, sha256: hex)
        } catch {
            throw LutinError(
                code: "artifact_metadata_failed",
                message: "Could not read artifact metadata for \(url.path): \(error).",
                details: ["path": url.path])
        }
    }

    private static func sha256(_ url: URL) throws -> SHA256.Digest {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize()
    }
}

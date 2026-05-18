import Foundation

/// Repo-relative paths for test fixtures, derived from this file's location.
public enum Fixtures {
    /// Repo root, computed by walking up from this source file.
    public static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)        // .../Tests/TestSupport/Fixtures.swift
            .deletingLastPathComponent()        // .../Tests/TestSupport
            .deletingLastPathComponent()        // .../Tests
            .deletingLastPathComponent()        // repo root
    }

    public static var examplesDirectory: URL {
        repoRoot.appendingPathComponent("Examples")
    }

    /// The Barry example project directory.
    public static var barryProject: URL {
        examplesDirectory.appendingPathComponent("Barry")
    }

    public static var barryConfig: URL {
        barryProject.appendingPathComponent("lutin.yml")
    }

    public static var barryApp: URL {
        barryProject.appendingPathComponent("Barry.app")
    }

    /// The Barry fixture's assets directory.
    public static var barryAssets: URL {
        barryProject.appendingPathComponent("assets")
    }

    /// The Barry fixture background image.
    public static var barryBackground: URL {
        barryAssets.appendingPathComponent("background.png")
    }

    /// Creates a unique empty temporary directory; caller is responsible for cleanup.
    public static func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutin-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

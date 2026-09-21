import Foundation
import LutinCore

/// Reads the canonical metadata tree.
///
/// The layout is defined here and **nowhere else** — the published asc
/// documentation contradicts itself on the version directory name, so a single
/// definition plus the runtime guard in `StoreMetadataGuard` is what keeps
/// Lutin honest.
///
/// ```
/// <root>/
/// ├── app-info/<locale>.json
/// └── version/<version>/<locale>.json      ← singular
/// ```
public struct StoreMetadataDirectory: Sendable {

    /// The reserved locale name for fallback values. Never reported as a locale.
    public static let defaultLocale = "default"

    public let root: URL

    public init(root: URL) { self.root = root }

    // MARK: - Paths

    private var appInfoURL: URL { root.appendingPathComponent("app-info") }
    private func versionURL(_ version: String) -> URL {
        root.appendingPathComponent("version").appendingPathComponent(version)
    }

    // MARK: - Enumeration

    private func locales(in directory: URL) throws -> [String] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory,
                                                           includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { $0 != Self.defaultLocale }
            .sorted()
    }

    public func appInfoLocales() throws -> [String] { try locales(in: appInfoURL) }

    public func versionLocales(version: String) throws -> [String] {
        try locales(in: versionURL(version))
    }

    /// Every explicit locale in the tree, `default` excluded, deduplicated.
    public var allLocales: [String] {
        let appInfo = (try? appInfoLocales()) ?? []
        let version = (try? versionDirectories())
            .flatMap { $0.flatMap { (try? versionLocales(version: $0)) ?? [] } } ?? []
        return Array(Set(appInfo + version)).sorted()
    }

    /// Names of every `version/<v>/` directory present.
    public func versionDirectories() throws -> [String] {
        let base = root.appendingPathComponent("version")
        guard FileManager.default.fileExists(atPath: base.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: base,
                                                           includingPropertiesForKeys: [.isDirectoryKey])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { $0.lastPathComponent }
            .sorted()
    }

    /// True when a `default.json` exists in either scope.
    public var hasDefaultFallback: Bool {
        let paths = [appInfoURL.appendingPathComponent("default.json").path]
            + ((try? versionDirectories()) ?? []).map {
                versionURL($0).appendingPathComponent("default.json").path
            }
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    /// Counts every `*.json` asc would recognise: directly under `app-info/`,
    /// and directly under each `version/<v>/`. Nested files are **not** counted,
    /// because asc does not read them — see `strayDirectories()`.
    public func enumeratedFileCount() throws -> Int {
        var count = try jsonFileCount(in: appInfoURL)
        for version in try versionDirectories() {
            count += try jsonFileCount(in: versionURL(version))
        }
        return count
    }

    private func jsonFileCount(in directory: URL) throws -> Int {
        guard FileManager.default.fileExists(atPath: directory.path) else { return 0 }
        return try FileManager.default.contentsOfDirectory(at: directory,
                                                           includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .count
    }

    /// Directories whose contents asc would **silently ignore**: the plural
    /// `versions/`, a locale directory nested one level too deep, and any
    /// unrecognised top-level directory.
    ///
    /// This exists because asc's silence is the dangerous part. A tree with a
    /// stray `versions/` validates clean and pushes nothing.
    public func strayDirectories() throws -> [String] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        let fm = FileManager.default
        var stray: [String] = []

        for entry in try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) {
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            switch entry.lastPathComponent {
            case "app-info":
                // Only files may live here.
                for child in try fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: [.isDirectoryKey])
                where (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    stray.append(child.path)
                }
            case "version":
                for versionDir in try fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: [.isDirectoryKey])
                where (try? versionDir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    for child in try fm.contentsOfDirectory(at: versionDir, includingPropertiesForKeys: [.isDirectoryKey])
                    where (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                        stray.append(child.path)
                    }
                }
            default:
                stray.append(entry.path)
            }
        }
        return stray.sorted()
    }

    // MARK: - Reading

    public func localization(scope: StoreMetadataScope,
                             locale: String,
                             version: String?) throws -> StoreMetadataLocalization {
        let url: URL
        switch scope {
        case .appInfo: url = appInfoURL.appendingPathComponent("\(locale).json")
        case .version:
            guard let version else {
                throw LutinError(code: "store_metadata_missing",
                                 message: "A version is required to read a version localization.",
                                 details: ["locale": locale])
            }
            url = versionURL(version).appendingPathComponent("\(locale).json")
        }
        guard let data = try? Data(contentsOf: url) else {
            throw LutinError(code: "store_metadata_missing",
                             message: "No metadata file at \(url.path).",
                             details: ["path": url.path, "locale": locale])
        }
        return try StoreMetadataLocalization.decode(data, scope: scope, locale: locale)
    }
}

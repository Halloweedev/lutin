import Foundation

/// Reads metadata out of an `.app/Contents/Info.plist`. Pure I/O — no UI
/// references. Used by `CreateProjectSheet` to auto-fill the new-project
/// form from a picked bundle.
public enum AppBundleInfo {
    public struct Metadata: Equatable, Sendable {
        public let displayName: String
        public let bundleIdentifier: String
        public let shortVersion: String?
        public let build: String?

        public init(displayName: String, bundleIdentifier: String,
                    shortVersion: String? = nil, build: String? = nil) {
            self.displayName = displayName
            self.bundleIdentifier = bundleIdentifier
            self.shortVersion = shortVersion
            self.build = build
        }
    }

    public enum ReadError: Error, CustomStringConvertible {
        case notABundle(URL)
        case missingInfoPlist(URL)
        case unreadable(URL, underlying: String)
        case missingBundleIdentifier(URL)
        public var description: String {
            switch self {
            case .notABundle(let url):
                return "\(url.lastPathComponent) is not a .app bundle"
            case .missingInfoPlist(let url):
                return "No Info.plist inside \(url.lastPathComponent)"
            case .unreadable(let url, let m):
                return "Could not read \(url.lastPathComponent)/Contents/Info.plist: \(m)"
            case .missingBundleIdentifier(let url):
                return "\(url.lastPathComponent) has no CFBundleIdentifier"
            }
        }
    }

    /// Reads `Contents/Info.plist` from the given .app URL.
    public static func read(_ appURL: URL) throws -> Metadata {
        guard appURL.pathExtension.lowercased() == "app" else {
            throw ReadError.notABundle(appURL)
        }
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            throw ReadError.missingInfoPlist(appURL)
        }
        let data: Data
        do { data = try Data(contentsOf: plistURL) }
        catch { throw ReadError.unreadable(appURL, underlying: error.localizedDescription) }
        let raw: Any
        do {
            raw = try PropertyListSerialization.propertyList(from: data,
                                                             options: [],
                                                             format: nil)
        } catch {
            throw ReadError.unreadable(appURL, underlying: error.localizedDescription)
        }
        guard let dict = raw as? [String: Any] else {
            throw ReadError.unreadable(appURL, underlying: "Info.plist root is not a dictionary")
        }
        guard let bundleId = dict["CFBundleIdentifier"] as? String, !bundleId.isEmpty else {
            throw ReadError.missingBundleIdentifier(appURL)
        }
        // Display name preference: CFBundleDisplayName > CFBundleName > filename.
        let displayName = (dict["CFBundleDisplayName"] as? String).nonEmpty
            ?? (dict["CFBundleName"] as? String).nonEmpty
            ?? appURL.deletingPathExtension().lastPathComponent
        let shortVersion = (dict["CFBundleShortVersionString"] as? String).nonEmpty
        let build = (dict["CFBundleVersion"] as? String).nonEmpty
        return Metadata(displayName: displayName,
                        bundleIdentifier: bundleId,
                        shortVersion: shortVersion,
                        build: build)
    }
}

private extension Optional where Wrapped == String {
    /// Returns nil for empty strings — common in Info.plist values that are
    /// declared but blank in default templates.
    var nonEmpty: String? {
        guard let s = self, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return s
    }
}

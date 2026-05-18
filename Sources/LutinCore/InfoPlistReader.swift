import Foundation

public struct InfoPlistData {
    public let bundleName: String
    public let bundleIdentifier: String
    public let shortVersion: String
    public let bundleVersion: String
}

/// Reads the fields Lutin needs from an app bundle's `Contents/Info.plist`.
public enum InfoPlistReader {
    public static func read(appBundle: URL) throws -> InfoPlistData {
        let plistURL = appBundle
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")

        guard let data = try? Data(contentsOf: plistURL),
              let raw = try? PropertyListSerialization
                .propertyList(from: data, format: nil),
              let dict = raw as? [String: Any]
        else {
            throw LutinError(
                code: "info_plist_unreadable",
                message: "Could not read Info.plist at \(plistURL.path).",
                details: ["path": plistURL.path]
            )
        }

        func string(_ key: String) -> String { (dict[key] as? String) ?? "" }
        return InfoPlistData(
            bundleName: string("CFBundleName"),
            bundleIdentifier: string("CFBundleIdentifier"),
            shortVersion: string("CFBundleShortVersionString"),
            bundleVersion: string("CFBundleVersion")
        )
    }
}

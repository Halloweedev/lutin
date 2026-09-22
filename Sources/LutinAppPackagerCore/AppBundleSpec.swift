import Foundation

public struct AppBundleSpec {
    public let binaryURL: URL
    public let resourcesURL: URL
    public let outputDirectory: URL
    public let bundleName: String
    public let bundleIdentifier: String
    public let shortVersion: String
    public let buildNumber: String
    public let minimumSystemVersion: String
    /// The **source** `Assets.xcassets`, when the caller has one. Only
    /// `actool` can turn it into the app's `AppIcon.icns` and the icon keys in
    /// `Info.plist`; a built SwiftPM resource bundle carries the compiled
    /// catalog but no icon. Nil means "stage resources only".
    public let assetCatalogURL: URL?

    public init(binaryURL: URL, resourcesURL: URL, outputDirectory: URL,
                bundleName: String, bundleIdentifier: String,
                shortVersion: String, buildNumber: String, minimumSystemVersion: String,
                assetCatalogURL: URL? = nil) {
        self.binaryURL = binaryURL
        self.resourcesURL = resourcesURL
        self.outputDirectory = outputDirectory
        self.bundleName = bundleName
        self.bundleIdentifier = bundleIdentifier
        self.shortVersion = shortVersion
        self.buildNumber = buildNumber
        self.minimumSystemVersion = minimumSystemVersion
        self.assetCatalogURL = assetCatalogURL
    }
}

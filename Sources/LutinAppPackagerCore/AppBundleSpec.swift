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

    public init(binaryURL: URL, resourcesURL: URL, outputDirectory: URL,
                bundleName: String, bundleIdentifier: String,
                shortVersion: String, buildNumber: String, minimumSystemVersion: String) {
        self.binaryURL = binaryURL
        self.resourcesURL = resourcesURL
        self.outputDirectory = outputDirectory
        self.bundleName = bundleName
        self.bundleIdentifier = bundleIdentifier
        self.shortVersion = shortVersion
        self.buildNumber = buildNumber
        self.minimumSystemVersion = minimumSystemVersion
    }
}

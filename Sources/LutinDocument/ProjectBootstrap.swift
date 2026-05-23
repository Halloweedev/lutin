import Foundation
import LutinConfig

/// Creates a brand-new project from a small set of inputs: writes a starter
/// `lutin.yml` under `~/Lutin/<slug>/` seeded with two items (app +
/// Applications) and an arrow between them, so the canvas isn't blank on
/// first open. Pure I/O — no UI references.
public enum ProjectBootstrap {
    public struct Inputs: Sendable {
        public let projectName: String
        public let bundleId: String
        public let appPath: String        // absolute path to the .app bundle
        public let windowWidth: Int
        public let windowHeight: Int

        public init(projectName: String, bundleId: String, appPath: String,
                    windowWidth: Int = 680, windowHeight: Int = 420) {
            self.projectName = projectName
            self.bundleId = bundleId
            self.appPath = appPath
            self.windowWidth = windowWidth
            self.windowHeight = windowHeight
        }
    }

    public enum BootstrapError: Error, CustomStringConvertible {
        case emptyName
        case alreadyExists(URL)
        public var description: String {
            switch self {
            case .emptyName: return "Project name cannot be empty"
            case .alreadyExists(let url): return "A project already exists at \(url.path)"
            }
        }
    }

    /// Returns the URL of the project directory (e.g. ~/Lutin/<slug>/).
    public static func projectDirectory(
        for projectName: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> URL {
        let slug = slugify(projectName)
        guard !slug.isEmpty else { throw BootstrapError.emptyName }
        return homeDirectory
            .appendingPathComponent("Lutin", isDirectory: true)
            .appendingPathComponent(slug, isDirectory: true)
    }

    /// Creates the project directory + writes lutin.yml. Returns the
    /// config file URL.
    @discardableResult
    public static func create(
        inputs: Inputs,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> URL {
        let dir = try projectDirectory(for: inputs.projectName, homeDirectory: homeDirectory)
        let configURL = dir.appendingPathComponent("lutin.yml")
        if FileManager.default.fileExists(atPath: configURL.path) {
            throw BootstrapError.alreadyExists(configURL)
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let config = starterConfig(for: inputs)
        try config.save(to: configURL)
        return configURL
    }

    public static func starterConfig(for inputs: Inputs) -> LutinConfig {
        let project = LutinConfig.ProjectInfo(name: inputs.projectName,
                                              bundleId: inputs.bundleId)
        let app = LutinConfig.AppInfo(path: inputs.appPath)
        let output = LutinConfig.OutputInfo(
            directory: "./release",
            dmgName: "\(slugify(inputs.projectName))-${version}.dmg",
            volumeName: inputs.projectName)
        let window = LutinConfig.WindowInfo(
            width: inputs.windowWidth,
            height: inputs.windowHeight,
            iconSize: 96,
            textSize: nil,
            showToolbar: nil,
            showSidebar: nil)
        let background = LutinConfig.BackgroundInfo(
            type: "template",
            template: "blueprint",
            path: nil,
            scale: 2,
            colorA: nil,
            colorB: nil,
            grid: nil,
            noise: nil,
            cornerRadius: nil,
            angle: nil)
        let appItem = LutinConfig.Item(
            type: "app", id: "app",
            x: inputs.windowWidth / 3,
            y: inputs.windowHeight / 2,
            label: inputs.projectName)
        let applicationsItem = LutinConfig.Item(
            type: "applications", id: "applications",
            x: (inputs.windowWidth * 2) / 3,
            y: inputs.windowHeight / 2,
            label: "Applications")

        // Seeded layout is just the two items. Arrows are decorative and
        // most projects don't need one — the user can drag-to-connect
        // from the canvas if they want.
        return LutinConfig(
            project: project,
            app: app,
            output: output,
            window: window,
            background: background,
            items: [appItem, applicationsItem],
            decorations: nil,
            signing: nil,
            notarization: nil,
            sparkle: nil)
    }

    /// Slug rule shared with `CanvasFileDropDelegate.slugify` so paths
    /// stay predictable: lowercase, hyphen-separated, no leading/trailing
    /// hyphens, collapses runs.
    public static func slugify(_ raw: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        var out = ""
        for scalar in raw.lowercased().unicodeScalars {
            if allowed.contains(scalar) { out.append(Character(scalar)) }
            else { out.append("-") }
        }
        while out.contains("--") { out = out.replacingOccurrences(of: "--", with: "-") }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Suggested reverse-DNS bundle id from a display name.
    /// "My App" → "com.example.my-app", "" → "com.example.app".
    public static func suggestedBundleId(for name: String) -> String {
        let slug = slugify(name)
        return slug.isEmpty ? "com.example.app" : "com.example.\(slug)"
    }
}

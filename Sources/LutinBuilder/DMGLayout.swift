import Foundation
import LutinConfig
import LutinCore

/// A resolved DMG window layout — the input to the `.DS_Store` encoder.
/// Decoupled from `LutinConfig` so it is reusable (e.g. by the future GUI).
public struct DMGLayout: Equatable {
    public struct Point: Equatable {
        public let x: Int
        public let y: Int
        public init(x: Int, y: Int) { self.x = x; self.y = y }
    }

    public let windowWidth: Int
    public let windowHeight: Int
    public let iconSize: Int
    public let textSize: Int
    public let showSidebar: Bool
    public let showToolbar: Bool
    /// Icon positions keyed by the on-disk filename (e.g. "Barry.app", "Applications").
    public let placements: [String: Point]

    public init(windowWidth: Int, windowHeight: Int, iconSize: Int, textSize: Int,
                showSidebar: Bool, showToolbar: Bool, placements: [String: Point]) {
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.iconSize = iconSize
        self.textSize = textSize
        self.showSidebar = showSidebar
        self.showToolbar = showToolbar
        self.placements = placements
    }
}

/// Maps a `LutinConfig` (window + items) onto a `DMGLayout`.
public enum LayoutResolver {
    /// - Parameter appFileName: the actual on-disk `.app` filename, so an
    ///   `items` entry of type `app` is keyed correctly.
    public static func resolve(config: LutinConfig, appFileName: String) throws -> DMGLayout {
        let w = config.window
        var placements: [String: DMGLayout.Point] = [:]
        for item in config.items ?? [] {
            let filename: String
            switch item.type {
            case "app": filename = appFileName
            case "applications": filename = "Applications"
            default:
                throw LutinError(
                    code: "invalid_config",
                    message: "Unknown item type '\(item.type)' in items.",
                    details: ["type": item.type])
            }
            placements[filename] = DMGLayout.Point(x: item.x, y: item.y)
        }
        return DMGLayout(
            windowWidth: w?.width ?? 680,
            windowHeight: w?.height ?? 420,
            iconSize: w?.iconSize ?? 96,
            textSize: w?.textSize ?? 13,
            showSidebar: w?.showSidebar ?? false,
            showToolbar: w?.showToolbar ?? false,
            placements: placements)
    }
}

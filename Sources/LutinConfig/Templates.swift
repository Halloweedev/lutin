import Foundation
import LutinCore

/// A fully-populated set of default values for a template.
public struct Template {
    public let name: String
    public let window: ResolvedWindow
    public let background: ResolvedBackground

    public struct ResolvedWindow {
        public let width: Int
        public let height: Int
        public let iconSize: Int
        public let textSize: Int
        public let showToolbar: Bool
        public let showSidebar: Bool
    }

    public struct ResolvedBackground {
        public let type: String
        public let template: String
        public let scale: Int
        public let colorA: String
        public let colorB: String
        public let grid: Bool
        public let noise: Double
        public let cornerRadius: Int
    }
}

public enum Templates {
    private static let all: [String: Template] = [
        "blueprint": Template(
            name: "blueprint",
            window: .init(width: 680, height: 420, iconSize: 96,
                          textSize: 13, showToolbar: false, showSidebar: false),
            background: .init(type: "solid", template: "", scale: 2,
                              colorA: "#EEF4FF", colorB: "#EEF4FF", grid: false,
                              noise: 0.0, cornerRadius: 0)
        ),
        "minimal": Template(
            name: "minimal",
            window: .init(width: 600, height: 400, iconSize: 96,
                          textSize: 13, showToolbar: false, showSidebar: false),
            background: .init(type: "solid", template: "", scale: 2,
                              colorA: "#FFFFFF", colorB: "#FFFFFF", grid: false,
                              noise: 0.0, cornerRadius: 0)
        ),
        "dark": Template(
            name: "dark",
            window: .init(width: 680, height: 420, iconSize: 96,
                          textSize: 13, showToolbar: false, showSidebar: false),
            background: .init(type: "solid", template: "", scale: 2,
                              colorA: "#1C1E26", colorB: "#1C1E26", grid: false,
                              noise: 0.0, cornerRadius: 0)
        ),
        "warm": Template(
            name: "warm",
            window: .init(width: 640, height: 400, iconSize: 96,
                          textSize: 13, showToolbar: false, showSidebar: false),
            background: .init(type: "solid", template: "", scale: 2,
                              colorA: "#FBEFE6", colorB: "#FBEFE6", grid: false,
                              noise: 0.0, cornerRadius: 0)
        ),
    ]

    public static let defaultTemplateName = "blueprint"

    public static func named(_ name: String) throws -> Template {
        guard let template = all[name] else {
            throw LutinError(
                code: "unknown_template",
                message: "Unknown template '\(name)'. Known: \(all.keys.sorted().joined(separator: ", ")).",
                details: ["template": name]
            )
        }
        return template
    }

    /// Fills missing `window`/`background` fields from the named template.
    /// The template name is `config.background?.template`, defaulting to `blueprint`.
    /// An empty or absent `template` field both fall back to `defaultTemplateName`.
    public static func applyDefaults(to config: LutinConfig) throws -> LutinConfig {
        var result = config
        let templateName = config.background?.template.flatMap { $0.isEmpty ? nil : $0 } ?? defaultTemplateName
        let template = try named(templateName)
        let w = template.window
        let b = template.background

        let cw = config.window
        result.window = LutinConfig.WindowInfo(
            width: cw?.width ?? w.width,
            height: cw?.height ?? w.height,
            iconSize: cw?.iconSize ?? w.iconSize,
            textSize: cw?.textSize ?? w.textSize,
            showToolbar: cw?.showToolbar ?? w.showToolbar,
            showSidebar: cw?.showSidebar ?? w.showSidebar
        )

        let cb = config.background
        result.background = LutinConfig.BackgroundInfo(
            type: cb?.type ?? b.type,
            template: cb?.template ?? b.template,
            path: cb?.path,
            scale: cb?.scale ?? b.scale,
            colorA: cb?.colorA ?? b.colorA,
            colorB: cb?.colorB ?? b.colorB,
            grid: cb?.grid ?? b.grid,
            noise: cb?.noise ?? b.noise,
            cornerRadius: cb?.cornerRadius ?? b.cornerRadius
        )
        return result
    }
}

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
    /// Sub-project 1 ships one usable template; the renderer adds the rest in SP3.
    private static let all: [String: Template] = [
        "blueprint": Template(
            name: "blueprint",
            window: .init(width: 680, height: 420, iconSize: 96,
                          textSize: 13, showToolbar: false, showSidebar: false),
            background: .init(type: "generated", template: "blueprint", scale: 2,
                              colorA: "#EEF4FF", colorB: "#DDE8FF", grid: true,
                              noise: 0.035, cornerRadius: 28)
        ),
        "minimal": Template(
            name: "minimal",
            window: .init(width: 600, height: 400, iconSize: 96,
                          textSize: 13, showToolbar: false, showSidebar: false),
            background: .init(type: "generated", template: "minimal", scale: 2,
                              colorA: "#FFFFFF", colorB: "#F2F2F2", grid: false,
                              noise: 0.0, cornerRadius: 24)
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
    public static func applyDefaults(to config: LutinConfig) throws -> LutinConfig {
        var result = config
        let template = try named(config.background?.template ?? defaultTemplateName)
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

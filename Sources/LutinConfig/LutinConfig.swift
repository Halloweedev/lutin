import Foundation

/// In-memory model of `lutin.yml`. Optional sections are filled by `Templates`.
public struct LutinConfig: Codable, Equatable {
    public var project: ProjectInfo
    public var app: AppInfo
    public var output: OutputInfo
    public var window: WindowInfo?
    public var background: BackgroundInfo?
    public var items: [Item]?
    public var decorations: [Decoration]?
    public var signing: SigningInfo?
    public var notarization: NotarizationInfo?
    public var sparkle: SparkleInfo?

    public struct ProjectInfo: Codable, Equatable {
        public var name: String
        public var bundleId: String
        public init(name: String, bundleId: String) {
            self.name = name; self.bundleId = bundleId
        }
    }

    public struct AppInfo: Codable, Equatable {
        public var path: String
        public init(path: String) { self.path = path }
    }

    public struct OutputInfo: Codable, Equatable {
        public var directory: String
        public var dmgName: String
        public var volumeName: String
        public init(directory: String, dmgName: String, volumeName: String) {
            self.directory = directory; self.dmgName = dmgName; self.volumeName = volumeName
        }
    }

    /// All fields optional in raw form; `Templates.merge` fills the gaps.
    ///
    /// **Sizing contract.** `width` and `height` are the **content area** of
    /// the Finder DMG window in points — i.e. the canvas a user designs a
    /// background for. A user-supplied background PNG should be exactly
    /// `width × height` (or `width*scale × height*scale` pixels for Retina,
    /// where `scale` comes from `background.scale`, default `2`). Lutin
    /// renders the background at that size 1:1 and grows the outer
    /// `WindowBounds` written to `.DS_Store` to leave that content area
    /// visible after Finder's title bar and bottom chrome are accounted for
    /// (see `LutinCore.FinderChrome`).
    public struct WindowInfo: Codable, Equatable {
        /// Content area width in points. Background PNG renders at this width.
        public var width: Int?
        /// Content area height in points. Background PNG renders at this height.
        public var height: Int?
        public var iconSize: Int?
        public var textSize: Int?
        public var showToolbar: Bool?
        public var showSidebar: Bool?
        public init(width: Int?, height: Int?, iconSize: Int?, textSize: Int?,
                    showToolbar: Bool?, showSidebar: Bool?) {
            self.width = width
            self.height = height
            self.iconSize = iconSize
            self.textSize = textSize
            self.showToolbar = showToolbar
            self.showSidebar = showSidebar
        }
    }

    public struct BackgroundInfo: Codable, Equatable {
        /// Valid values: `"solid"`, `"gradient"`, `"image"`.
        /// Legacy value `"generated"` is decoded and treated as `"solid"` by
        /// both the renderer and the UI — no pattern or grid is applied.
        public var type: String?
        /// **Legacy / no-op.** Previously selected a named preset by name.
        /// Retained for round-trip decode/encode of old project files; the
        /// renderer ignores it. New projects set this to `""`.
        public var template: String?
        public var path: String?
        public var scale: Int?
        public var colorA: String?
        public var colorB: String?
        /// **Reserved for future image-overlay support.** The renderer does not
        /// currently honour this field for `solid` or `gradient` backgrounds.
        /// It was previously used to draw a decorative grid overlay — that
        /// behaviour has been removed.
        public var grid: Bool?
        public var noise: Double?
        public var cornerRadius: Int?
        public var angle: Int?
        public init(type: String?, template: String?, path: String?, scale: Int?,
                    colorA: String?, colorB: String?, grid: Bool?, noise: Double?,
                    cornerRadius: Int?, angle: Int? = nil) {
            self.type = type; self.template = template; self.path = path
            self.scale = scale; self.colorA = colorA; self.colorB = colorB
            self.grid = grid; self.noise = noise; self.cornerRadius = cornerRadius
            self.angle = angle
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if type != nil { try container.encode(type, forKey: .type) }
            if template != nil { try container.encode(template, forKey: .template) }
            if path != nil { try container.encode(path, forKey: .path) }
            if scale != nil { try container.encode(scale, forKey: .scale) }
            if colorA != nil { try container.encode(colorA, forKey: .colorA) }
            if colorB != nil { try container.encode(colorB, forKey: .colorB) }
            if grid != nil { try container.encode(grid, forKey: .grid) }
            if noise != nil { try container.encode(noise, forKey: .noise) }
            if cornerRadius != nil { try container.encode(cornerRadius, forKey: .cornerRadius) }
            if angle != nil { try container.encode(angle, forKey: .angle) }
        }

        enum CodingKeys: String, CodingKey {
            case type, template, path, scale, colorA, colorB, grid, noise, cornerRadius, angle
        }
    }

    public struct Item: Codable, Equatable {
        public var type: String       // "app" | "applications"
        public var id: String
        public var x: Int
        public var y: Int
        public var label: String?
        public var hidden: Bool?
        public init(type: String, id: String, x: Int, y: Int, label: String?, hidden: Bool? = nil) {
            self.type = type
            self.id = id
            self.x = x
            self.y = y
            self.label = label
            self.hidden = hidden
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
            if label != nil { try container.encode(label, forKey: .label) }
            if hidden == true { try container.encode(true, forKey: .hidden) }
        }

        enum CodingKeys: String, CodingKey {
            case type, id, x, y, label, hidden
        }
    }

    public struct Decoration: Codable, Equatable {
        public var type: String                // "arrow" | "image"
        public var from: String?               // arrow: source item id
        public var to: String?                 // arrow: target item id
        public var label: String?              // arrow: optional text
        public var path: String?               // image: overlay file (project-relative)
        public var x: Int?                     // image: position, window points
        public var y: Int?                     // image: position, window points
        public var width: Int?                 // image: drawn width, window points
        public var hidden: Bool?
        public init(type: String, from: String? = nil, to: String? = nil,
                    label: String? = nil, path: String? = nil,
                    x: Int? = nil, y: Int? = nil, width: Int? = nil, hidden: Bool? = nil) {
            self.type = type
            self.from = from
            self.to = to
            self.label = label
            self.path = path
            self.x = x
            self.y = y
            self.width = width
            self.hidden = hidden
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            if from != nil { try container.encode(from, forKey: .from) }
            if to != nil { try container.encode(to, forKey: .to) }
            if label != nil { try container.encode(label, forKey: .label) }
            if path != nil { try container.encode(path, forKey: .path) }
            if x != nil { try container.encode(x, forKey: .x) }
            if y != nil { try container.encode(y, forKey: .y) }
            if width != nil { try container.encode(width, forKey: .width) }
            if hidden == true { try container.encode(true, forKey: .hidden) }
        }

        enum CodingKeys: String, CodingKey {
            case type, from, to, label, path, x, y, width, hidden
        }
    }

    public struct SigningInfo: Codable, Equatable {
        public var enabled: Bool
        public var identity: String?
        public var hardenedRuntime: Bool?
        public var entitlements: String?
        public var signDmg: Bool?
        public init(enabled: Bool, identity: String?, hardenedRuntime: Bool?,
                    entitlements: String?, signDmg: Bool?) {
            self.enabled = enabled
            self.identity = identity
            self.hardenedRuntime = hardenedRuntime
            self.entitlements = entitlements
            self.signDmg = signDmg
        }
    }

    public struct NotarizationInfo: Codable, Equatable {
        public var enabled: Bool
        public var profile: String?
        public var staple: Bool?
        public init(enabled: Bool, profile: String?, staple: Bool?) {
            self.enabled = enabled
            self.profile = profile
            self.staple = staple
        }
    }

    public struct SparkleInfo: Codable, Equatable {
        public var enabled: Bool
        public var appcastPath: String?
        public var releaseNotesDirectory: String?
        public var downloadBaseURL: String?
        public init(enabled: Bool, appcastPath: String?, releaseNotesDirectory: String?,
                    downloadBaseURL: String?) {
            self.enabled = enabled
            self.appcastPath = appcastPath
            self.releaseNotesDirectory = releaseNotesDirectory
            self.downloadBaseURL = downloadBaseURL
        }
    }

    public init(
        project: ProjectInfo,
        app: AppInfo,
        output: OutputInfo,
        window: WindowInfo?,
        background: BackgroundInfo?,
        items: [Item]?,
        decorations: [Decoration]?,
        signing: SigningInfo?,
        notarization: NotarizationInfo?,
        sparkle: SparkleInfo?
    ) {
        self.project = project
        self.app = app
        self.output = output
        self.window = window
        self.background = background
        self.items = items
        self.decorations = decorations
        self.signing = signing
        self.notarization = notarization
        self.sparkle = sparkle
    }
}

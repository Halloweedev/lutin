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
    public struct WindowInfo: Codable, Equatable {
        public var width: Int?
        public var height: Int?
        public var iconSize: Int?
        public var textSize: Int?
        public var showToolbar: Bool?
        public var showSidebar: Bool?
    }

    public struct BackgroundInfo: Codable, Equatable {
        public var type: String?
        public var template: String?
        public var scale: Int?
        public var colorA: String?
        public var colorB: String?
        public var grid: Bool?
        public var noise: Double?
        public var cornerRadius: Int?
        public init(type: String?, template: String?, scale: Int?, colorA: String?,
                    colorB: String?, grid: Bool?, noise: Double?, cornerRadius: Int?) {
            self.type = type; self.template = template; self.scale = scale
            self.colorA = colorA; self.colorB = colorB; self.grid = grid
            self.noise = noise; self.cornerRadius = cornerRadius
        }
    }

    public struct Item: Codable, Equatable {
        public var type: String       // "app" | "applications"
        public var id: String
        public var x: Int
        public var y: Int
        public var label: String?
    }

    public struct Decoration: Codable, Equatable {
        public var type: String       // "arrow"
        public var from: String
        public var to: String
        public var label: String?
    }

    public struct SigningInfo: Codable, Equatable {
        public var enabled: Bool
        public var identity: String?
        public var hardenedRuntime: Bool?
        public var entitlements: String?
        public var signDmg: Bool?
    }

    public struct NotarizationInfo: Codable, Equatable {
        public var enabled: Bool
        public var profile: String?
        public var staple: Bool?
    }

    public struct SparkleInfo: Codable, Equatable {
        public var enabled: Bool
        public var appcastPath: String?
        public var releaseNotesDirectory: String?
        public var downloadBaseURL: String?
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

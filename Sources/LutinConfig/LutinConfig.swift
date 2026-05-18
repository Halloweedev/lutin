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
    }

    public struct AppInfo: Codable, Equatable {
        public var path: String
    }

    public struct OutputInfo: Codable, Equatable {
        public var directory: String
        public var dmgName: String
        public var volumeName: String
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
}

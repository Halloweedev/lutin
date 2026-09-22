import Foundation

public enum EditorTab: String, CaseIterable, Sendable, Hashable {
    case design
    case window
    case project
    case release
    case store

    public var iconName: String {
        switch self {
        case .design:  "palette"
        case .window:  "app-window"
        case .project: "package"
        case .release: "rocket-launch"
        case .store:   "storefront"
        }
    }

    public var title: String {
        switch self {
        case .design:  "Design"
        case .window:  "Window"
        case .project: "Project"
        case .release: "Release"
        case .store:   "Store"
        }
    }
}

import Foundation

public enum EditorTab: String, CaseIterable, Sendable, Hashable {
    case design
    case window
    case project
    case release

    public var iconName: String {
        switch self {
        case .design:  "rectangle.3.offgrid"
        case .window:  "macwindow"
        case .project: "folder"
        case .release: "shippingbox.and.arrow.backward"
        }
    }

    public var title: String {
        switch self {
        case .design:  "Design"
        case .window:  "Window"
        case .project: "Project"
        case .release: "Release"
        }
    }
}

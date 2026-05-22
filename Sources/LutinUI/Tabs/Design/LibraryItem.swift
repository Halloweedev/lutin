import Foundation
import UniformTypeIdentifiers

public enum LibraryItem: String, CaseIterable, Sendable {
    case app
    case applications
    case image

    public var title: String {
        switch self {
        case .app: "App"
        case .applications: "Applications"
        case .image: "Image"
        }
    }

    public var iconSystemName: String {
        switch self {
        case .app: "app.dashed"
        case .applications: "folder"
        case .image: "photo"
        }
    }

    public static let dragType = UTType("com.lutin.library-item")!
}

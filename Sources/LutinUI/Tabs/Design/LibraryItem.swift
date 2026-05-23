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

    /// Process-local UTI. Using `importedAs(_:conformingTo:)` makes this
    /// work without an Info.plist declaration — the type system creates
    /// an in-memory entry for the current process. The previous
    /// `UTType("com.lutin.library-item")!` trapped on first use in a
    /// packaged .app where no UTExportedTypeDeclarations exist.
    public static let dragType = UTType(importedAs: "com.lutin.library-item",
                                         conformingTo: .text)
}

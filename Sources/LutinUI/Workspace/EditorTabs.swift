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
        // Was `shippingbox.and.arrow.backward` — the backward-arrow
        // variant reads as "return shipment", the wrong direction
        // for shipping a release out the door. Plain `shippingbox.fill`
        // is unambiguous and matches the canvas action-bar Release
        // button's glyph.
        case .release: "shippingbox.fill"
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

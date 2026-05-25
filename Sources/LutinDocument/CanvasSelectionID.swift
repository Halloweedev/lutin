import Foundation

/// Identifier for a single canvas element. Items have string ids; image
/// decorations are keyed by their position in `config.decorations[]`.
/// Arrows used to be a third case — they're gone now; render an arrow
/// by adding an image decoration of an arrow asset.
public enum CanvasSelectionID: Hashable, Sendable {
    case item(id: String)
    case image(index: Int)

    public var isMoveable: Bool { true }
}

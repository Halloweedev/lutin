import Foundation

/// Identifier for a single canvas element. Items have string ids; arrows are
/// keyed by their endpoint ids; image decorations are keyed by their position
/// in `config.decorations[]`.
///
/// Arrows are not moveable on their own — their geometry is derived from
/// their endpoint items. Callers checking whether to issue a `moveMany`
/// delta should use `isMoveable`.
public enum CanvasSelectionID: Hashable, Sendable {
    case item(id: String)
    case arrow(from: String, to: String)
    case image(index: Int)

    public var isMoveable: Bool {
        switch self {
        case .item, .image: return true
        case .arrow: return false
        }
    }
}

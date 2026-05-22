import Foundation
import LutinConfig

/// Typed mutations against a `LutinProjectDocument`. Views dispatch these
/// instead of mutating the config directly so undo/redo, dirty tracking,
/// and (later) FSEvents serialisation can hang off one funnel.
public enum DocumentIntent: Equatable {
    case moveItem(id: String, x: Int, y: Int)
    case renameItemLabel(id: String, label: String?)
    case addItem(LutinConfig.Item)
    case deleteItem(id: String)
    case addArrow(from: String, to: String, label: String?)
    case deleteArrow(from: String, to: String)
    case renameArrowLabel(from: String, to: String, label: String?)
    case setProjectName(String)
    case setOutputDirectory(String)
    case setBackgroundTemplate(String)
    case setIconSize(Int)
    case moveMany(deltas: [MoveTarget])
}

public extension DocumentIntent {
    /// A single move delta applied as part of a `moveMany` batch.
    /// Arrows have no own (x, y); they are never valid targets.
    struct MoveTarget: Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            case item(id: String)
            case imageDecoration(index: Int)
        }
        public var target: Kind
        public var dx: Int
        public var dy: Int
        public init(target: Kind, dx: Int, dy: Int) {
            self.target = target; self.dx = dx; self.dy = dy
        }
    }
}

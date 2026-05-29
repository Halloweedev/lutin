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
    case setProjectName(String)
    case setOutputDirectory(String)
    case setBackgroundTemplate(String)
    case setIconSize(Int)
    case moveMany(deltas: [MoveTarget])
    case deleteSelection(targets: [DeleteTarget])
    case setItemHidden(id: String, hidden: Bool)
    case setImageHidden(index: Int, hidden: Bool)
    case setItemID(old: String, new: String)
    case addImageDecoration(path: String, x: Int, y: Int, width: Int, height: Int?)
    case deleteImageDecoration(index: Int)
    case moveImageDecoration(index: Int, x: Int, y: Int, width: Int, height: Int?)
    case reorderItem(id: String, toIndex: Int)
    case reorderImageDecoration(fromIndex: Int, toIndex: Int)
    case setWindow(width: Int?, height: Int?, iconSize: Int?,
                   textSize: Int?, showToolbar: Bool?, showSidebar: Bool?)
    case setProjectMetadata(name: String, bundleId: String)
    case setApp(path: String)
    case setOutput(directory: String, dmgName: String, volumeName: String)
    case setBackground(LutinConfig.BackgroundInfo)
    case setSigning(LutinConfig.SigningInfo)
    case setNotarization(LutinConfig.NotarizationInfo)
    case setSparkle(LutinConfig.SparkleInfo)
}

public extension DocumentIntent {
    /// A single move delta applied as part of a `moveMany` batch.
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

    enum DeleteTarget: Equatable, Sendable {
        case item(id: String)
        case imageDecoration(index: Int)
    }
}

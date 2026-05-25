import Foundation
import LutinDocument
import LutinConfig

/// JSON envelope describing one intent. The bridge is the single source of
/// truth for `lutin apply-intents` and `lutin-app-headless` so the two CLI
/// paths cannot drift.
public struct IntentEnvelope: Decodable, Sendable {
    public let kind: String
    public let id: String?
    public let new: String?
    public let x: Int?
    public let y: Int?
    public let width: Int?
    public let height: Int?
    public let iconSize: Int?
    public let textSize: Int?
    public let showToolbar: Bool?
    public let showSidebar: Bool?
    public let hidden: Bool?
    public let index: Int?
    public let path: String?
    public let label: String?
    public let name: String?
    public let bundleId: String?
    public let directory: String?
    public let dmgName: String?
    public let volumeName: String?
    public let deltas: [DeltaEnv]?

    public struct DeltaEnv: Decodable, Sendable {
        public let kind: String   // "item" | "image"
        public let id: String?
        public let index: Int?
        public let dx: Int
        public let dy: Int
    }

    public func apply(to document: LutinProjectDocument) throws {
        switch kind {
        case "moveMany":
            let ds = (deltas ?? []).map { d -> DocumentIntent.MoveTarget in
                if d.kind == "item" {
                    return .init(target: .item(id: d.id ?? ""), dx: d.dx, dy: d.dy)
                } else {
                    return .init(target: .imageDecoration(index: d.index ?? 0), dx: d.dx, dy: d.dy)
                }
            }
            try document.apply(.moveMany(deltas: ds))
        case "setItemHidden":
            try document.apply(.setItemHidden(id: id ?? "", hidden: hidden ?? false))
        case "setImageHidden":
            try document.apply(.setImageHidden(index: index ?? 0, hidden: hidden ?? false))
        case "setItemID":
            try document.apply(.setItemID(old: id ?? "", new: new ?? ""))
        case "addImageDecoration":
            try document.apply(.addImageDecoration(path: path ?? "", x: x ?? 0, y: y ?? 0, width: width ?? 100))
        case "deleteImageDecoration":
            try document.apply(.deleteImageDecoration(index: index ?? 0))
        case "moveImageDecoration":
            try document.apply(.moveImageDecoration(index: index ?? 0, x: x ?? 0, y: y ?? 0, width: width ?? 100))
        case "reorderItem":
            try document.apply(.reorderItem(id: id ?? "", toIndex: index ?? 0))
        case "reorderImageDecoration":
            try document.apply(.reorderImageDecoration(fromIndex: x ?? 0, toIndex: index ?? 0))
        case "setWindow":
            try document.apply(.setWindow(width: width, height: height, iconSize: iconSize,
                                          textSize: textSize, showToolbar: showToolbar, showSidebar: showSidebar))
        case "setProjectMetadata":
            try document.apply(.setProjectMetadata(name: name ?? "", bundleId: bundleId ?? ""))
        case "setApp":
            try document.apply(.setApp(path: path ?? ""))
        case "setOutput":
            try document.apply(.setOutput(directory: directory ?? "",
                                          dmgName: dmgName ?? "",
                                          volumeName: volumeName ?? ""))
        case "moveItem":
            try document.apply(.moveItem(id: id ?? "", x: x ?? 0, y: y ?? 0))
        case "renameItemLabel":
            try document.apply(.renameItemLabel(id: id ?? "", label: label))
        case "deleteItem":
            try document.apply(.deleteItem(id: id ?? ""))
        case "deleteSelection":
            // deleteSelection with a tagged-union target list is not representable in
            // a flat JSON envelope. Use deleteItem / deleteImageDecoration individually.
            throw IntentBridgeError.unsupported("deleteSelection — use deleteItem / deleteImageDecoration individually")
        case "addArrow", "deleteArrow", "updateArrow", "moveArrowEndpoint",
             "setArrowHidden", "swapArrow", "renameArrowLabel":
            // Drawn arrows were removed. Add arrows as image decorations
            // instead (`addImageDecoration` with an arrow PNG).
            throw IntentBridgeError.unsupported("\(kind) — drawn arrows removed; use addImageDecoration with an arrow image")
        default:
            throw IntentBridgeError.unknown(kind)
        }
    }
}

public enum IntentBridgeError: Error, CustomStringConvertible {
    case unknown(String)
    case unsupported(String)
    public var description: String {
        switch self {
        case .unknown(let k): return "unknown intent kind: \(k)"
        case .unsupported(let k): return "unsupported intent in JSON envelope: \(k)"
        }
    }
}

public enum IntentBridge {
    /// Decode a JSON array of envelopes and apply each one in order.
    public static func applySequence(jsonData: Data, to document: LutinProjectDocument) throws {
        let envelopes = try JSONDecoder().decode([IntentEnvelope].self, from: jsonData)
        for env in envelopes {
            try env.apply(to: document)
        }
    }
}

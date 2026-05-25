import Foundation
import LutinConfig
import LutinDocument

public enum LayersOrdering {
    public struct Row: Equatable {
        public let id: CanvasSelectionID
        public let kind: Kind
        public let displayName: String
        public let hidden: Bool
    }
    public enum Kind { case item, image }

    public static func rows(from config: LutinConfig) -> [Row] {
        var rows: [Row] = []
        for item in (config.items ?? []) {
            rows.append(Row(
                id: .item(id: item.id),
                kind: .item,
                displayName: item.label ?? item.id,
                hidden: item.hidden ?? false))
        }
        for (i, deco) in (config.decorations ?? []).enumerated() where deco.type == "image" {
            let basename = (deco.path as NSString?)?.lastPathComponent ?? "image"
            rows.append(Row(
                id: .image(index: i),
                kind: .image,
                displayName: "image: \(basename)",
                hidden: deco.hidden ?? false))
        }
        return rows
    }
}

import Foundation
import Observation
import LutinConfig
import LutinDocument

@Observable
public final class CanvasSelectionModel {
    public var selection: CanvasSelection = .none

    public init() {}

    public func delete(in document: LutinProjectDocument) throws {
        switch selection {
        case .none: return
        case .item(let id):
            try document.apply(.deleteItem(id: id))
        case .arrow(let from, let to):
            try document.apply(.deleteArrow(from: from, to: to))
        }
        selection = .none
    }

    public func duplicate(in document: LutinProjectDocument) throws {
        guard case .item(let id) = selection,
              let original = document.config.items?.first(where: { $0.id == id }) else { return }
        let newID = uniqueID(base: original.id, existing: document.config.items ?? [])
        let copy = LutinConfig.Item(type: original.type, id: newID,
                                    x: original.x + 16, y: original.y + 16,
                                    label: original.label)
        try document.apply(.addItem(copy))
        selection = .item(id: newID)
    }

    private func uniqueID(base: String, existing: [LutinConfig.Item]) -> String {
        var n = 2
        let ids = Set(existing.map(\.id))
        while ids.contains("\(base)-\(n)") { n += 1 }
        return "\(base)-\(n)"
    }
}

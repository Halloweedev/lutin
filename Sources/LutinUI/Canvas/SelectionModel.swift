import Foundation
import Observation
import LutinDocument
import LutinConfig

@Observable
public final class CanvasSelectionModel {
    public private(set) var selection: Set<CanvasSelectionID> = []

    public init() {}

    public func select(_ id: CanvasSelectionID) {
        selection = [id]
    }

    public func toggle(_ id: CanvasSelectionID) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    public func replace(with ids: any Collection<CanvasSelectionID>) {
        selection = Set(ids)
    }

    public func clear() { selection.removeAll() }

    /// Subset that can participate in `moveMany` (items + images).
    public var moveableIDs: Set<CanvasSelectionID> {
        selection.filter(\.isMoveable)
    }

    /// Convenience for legacy single-select call sites — returns the
    /// only selected element if there is exactly one, otherwise nil.
    public var single: CanvasSelectionID? {
        selection.count == 1 ? selection.first : nil
    }

    /// Delete every selected element via one `deleteSelection` intent.
    public func delete(in document: LutinProjectDocument) throws {
        guard !selection.isEmpty else { return }
        let targets: [DocumentIntent.DeleteTarget] = selection.map { id in
            switch id {
            case .item(let i):  return .item(id: i)
            case .image(let i): return .imageDecoration(index: i)
            }
        }
        try document.apply(.deleteSelection(targets: targets))
        clear()
    }

    /// Duplicate selected items and image decorations. New copies land
    /// 16 pt offset from the original so they're visually distinct
    /// after the duplicate.
    public func duplicate(in document: LutinProjectDocument) throws {
        guard !selection.isEmpty else { return }
        for id in selection {
            switch id {
            case .item(let existingID):
                guard let existing = document.config.items?.first(where: { $0.id == existingID }) else { continue }
                var copy = existing
                let existingIDs = Set((document.config.items ?? []).map(\.id))
                copy.id = CanvasFileDropDelegate.uniqueID("\(existingID)-copy", existing: existingIDs)
                copy.x += 16; copy.y += 16
                try document.apply(.addItem(copy))
            case .image(let index):
                guard let d = document.config.decorations?[safe: index] else { continue }
                try document.apply(.addImageDecoration(path: d.path ?? "",
                                                       x: (d.x ?? 0) + 16,
                                                       y: (d.y ?? 0) + 16,
                                                       width: d.width ?? 100))
            }
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

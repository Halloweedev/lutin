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
            case .item(let i): return .item(id: i)
            case .arrow(let f, let t): return .arrow(from: f, to: t)
            case .image(let i): return .imageDecoration(index: i)
            }
        }
        try document.apply(.deleteSelection(targets: targets))
        clear()
    }

    /// Duplicate selected items (arrows/images handled in later tasks).
    public func duplicate(in document: LutinProjectDocument) throws {
        guard !selection.isEmpty else { return }
        for id in selection {
            if case .item(let existingID) = id,
               let existing = document.config.items?.first(where: { $0.id == existingID }) {
                var copy = existing
                copy.id = "\(existingID)-copy"
                copy.x += 16; copy.y += 16
                try document.apply(.addItem(copy))
            }
        }
    }
}

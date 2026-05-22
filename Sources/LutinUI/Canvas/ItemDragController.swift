import SwiftUI
import LutinConfig
import LutinDocument

public enum DragMath {
    public static func snap(_ value: CGFloat, grid: Int) -> Int {
        guard grid > 0 else { return Int(value.rounded()) }
        let v = (value / CGFloat(grid)).rounded() * CGFloat(grid)
        return Int(v)
    }

    public struct AlignmentResult: Equatable {
        public let vertical: Bool
        public let horizontal: Bool
    }

    public static func alignmentGuides(forCenter c: CGPoint,
                                       against others: [CGPoint],
                                       tolerance: CGFloat) -> AlignmentResult {
        let v = others.contains { abs($0.x - c.x) <= tolerance }
        let h = others.contains { abs($0.y - c.y) <= tolerance }
        return AlignmentResult(vertical: v, horizontal: h)
    }
}

/// View modifier that handles dragging of a canvas element, committing a
/// `moveMany` intent on drag-end for the full moveable selection.
public struct ItemDragController: ViewModifier {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel
    let myID: CanvasSelectionID
    let snapGrid: Int

    @State private var pendingDX: CGFloat = 0
    @State private var pendingDY: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .offset(x: pendingDX, y: pendingDY)
            .gesture(
                DragGesture(coordinateSpace: .named("canvas"))
                    .onChanged { v in
                        if !selectionModel.selection.contains(myID) {
                            selectionModel.select(myID)
                        }
                        pendingDX = v.translation.width
                        pendingDY = v.translation.height
                    }
                    .onEnded { v in
                        defer { pendingDX = 0; pendingDY = 0 }
                        let dx = Self.snap(Int(v.translation.width), gridSize: snapGrid)
                        let dy = Self.snap(Int(v.translation.height), gridSize: snapGrid)
                        guard dx != 0 || dy != 0 else { return }
                        let deltas = Self.deltas(forSelection: selectionModel.selection,
                                                 dx: dx, dy: dy)
                        guard !deltas.isEmpty else { return }
                        try? document.apply(.moveMany(deltas: deltas))
                    }
            )
    }

    public static func deltas(forSelection sel: Set<CanvasSelectionID>,
                              dx: Int, dy: Int) -> [DocumentIntent.MoveTarget] {
        sel.compactMap { id in
            switch id {
            case .item(let i): return .init(target: .item(id: i), dx: dx, dy: dy)
            case .image(let i): return .init(target: .imageDecoration(index: i), dx: dx, dy: dy)
            case .arrow: return nil
            }
        }
    }

    public static func snap(_ value: Int, gridSize: Int) -> Int {
        guard gridSize > 0 else { return value }
        let r = Int((Double(value) / Double(gridSize)).rounded())
        return r * gridSize
    }
}

/// Legacy single-item modifier kept for any call sites that haven't migrated.
/// New code should use `ItemDragController` via `draggableItem(document:selectionModel:id:snapGrid:)`.
public struct ItemDragModifier: ViewModifier {
    @Bindable var document: LutinProjectDocument
    let itemID: String
    let snapGrid: Int

    @State private var translation: CGSize = .zero
    @State private var baseX: Int = 0
    @State private var baseY: Int = 0

    public func body(content: Content) -> some View {
        content
            .offset(translation)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if translation == .zero {
                            let item = document.config.items?.first { $0.id == itemID }
                            baseX = item?.x ?? 0
                            baseY = item?.y ?? 0
                        }
                        translation = value.translation
                    }
                    .onEnded { value in
                        let newX = DragMath.snap(CGFloat(baseX) + value.translation.width, grid: snapGrid)
                        let newY = DragMath.snap(CGFloat(baseY) + value.translation.height, grid: snapGrid)
                        try? document.apply(.moveItem(id: itemID, x: newX, y: newY))
                        translation = .zero
                    }
            )
    }
}

public extension View {
    /// Multi-select aware drag: commits a `moveMany` intent for the full
    /// moveable selection when the drag ends.
    func draggableItem(document: LutinProjectDocument,
                       selectionModel: CanvasSelectionModel,
                       id: CanvasSelectionID,
                       snapGrid: Int) -> some View {
        modifier(ItemDragController(document: document,
                                    selectionModel: selectionModel,
                                    myID: id,
                                    snapGrid: snapGrid))
    }
}

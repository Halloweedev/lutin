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

    /// Canvas-center snap (single axis). Given an element's current origin
    /// on this axis, its bbox size on this axis, an unsnapped translation
    /// delta, and the canvas centerline on this axis, returns the
    /// *translation that lands the bbox center exactly on `canvasCenter`*
    /// when the element center is within `threshold`; `nil` otherwise.
    ///
    /// Pure function — no SwiftUI / document state. Run independently per
    /// axis. The caller substitutes the returned value for the raw drag
    /// translation on that axis.
    public static func canvasCenterSnap(elementOrigin: CGFloat,
                                        elementSize: CGFloat,
                                        rawTranslation: CGFloat,
                                        canvasCenter: CGFloat,
                                        threshold: CGFloat) -> CGFloat? {
        let proposedCenter = elementOrigin + rawTranslation + elementSize / 2
        guard abs(proposedCenter - canvasCenter) <= threshold else { return nil }
        return canvasCenter - elementOrigin - elementSize / 2
    }
}

/// View modifier that handles dragging of a canvas element, committing a
/// `moveMany` intent on drag-end for the full moveable selection.
public struct ItemDragController: ViewModifier {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel
    let myID: CanvasSelectionID
    let snapGrid: Int
    let guideState: CanvasGuideState

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
                        updateGuides(translation: v.translation)
                    }
                    .onEnded { v in
                        defer { pendingDX = 0; pendingDY = 0 }
                        guideState.guideX = nil
                        guideState.guideY = nil
                        guideState.equalSpacingX = nil
                        guideState.equalSpacingY = nil
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

    private func updateGuides(translation: CGSize) {
        // Snap candidates exclude the currently-selected set (an item can't
        // snap to itself or to others moving with it).
        let candidatesX = (document.config.items ?? [])
            .filter { item in !selectionModel.selection.contains(.item(id: item.id)) }
            .map(\.x)
        let candidatesY = (document.config.items ?? [])
            .filter { item in !selectionModel.selection.contains(.item(id: item.id)) }
            .map(\.y)
        // Snap relative to the dragged element's current position, not the
        // first moveable in the document. For multi-drag this means the
        // element under the cursor drives the guides — what the user
        // expects. For image overlays, look up by index in decorations.
        guard let (originX, originY) = currentOrigin() else { return }
        let newX = originX + Int(translation.width)
        let newY = originY + Int(translation.height)
        let snapX = AlignmentGuides.snap(value: newX, candidates: candidatesX, threshold: 4)
        let snapY = AlignmentGuides.snap(value: newY, candidates: candidatesY, threshold: 4)
        guideState.guideX = snapX.target
        guideState.guideY = snapY.target

        // Equal-spacing pills: only when the snap is the midpoint of two
        // candidates. Use the unselected-items' x/y as siblings; pick the
        // closest two flanking the snapped value.
        if let mid = AlignmentGuides.equalSpacing(value: newX, others: candidatesX, threshold: 4) {
            let (a, b) = closestFlanking(value: mid.snapped, in: candidatesX)
            guideState.equalSpacingX = .init(leftOrTop: a, rightOrBottom: b,
                                             midpoint: mid.snapped, distance: mid.distance)
        } else {
            guideState.equalSpacingX = nil
        }
        if let mid = AlignmentGuides.equalSpacing(value: newY, others: candidatesY, threshold: 4) {
            let (a, b) = closestFlanking(value: mid.snapped, in: candidatesY)
            guideState.equalSpacingY = .init(leftOrTop: a, rightOrBottom: b,
                                             midpoint: mid.snapped, distance: mid.distance)
        } else {
            guideState.equalSpacingY = nil
        }
    }

    /// The dragged element's current (x, y) in window-points. For items
    /// looked up by id; for image decorations by index.
    private func currentOrigin() -> (Int, Int)? {
        switch myID {
        case .item(let id):
            guard let item = (document.config.items ?? []).first(where: { $0.id == id }) else { return nil }
            return (item.x, item.y)
        case .image(let idx):
            guard let decos = document.config.decorations,
                  idx >= 0, idx < decos.count else { return nil }
            return (decos[idx].x ?? 0, decos[idx].y ?? 0)
        }
    }

    /// Returns the two values flanking `midpoint` in the candidates list.
    /// Used to draw equal-spacing pills between the dragged item and the
    /// nearest two neighbors that produced the midpoint snap.
    private func closestFlanking(value: Int, in candidates: [Int]) -> (Int, Int) {
        let sorted = candidates.sorted()
        // The midpoint sits between some (a, b) where a < value <= b.
        var lower = sorted.first ?? value
        var upper = sorted.last ?? value
        for c in sorted {
            if c <= value { lower = c }
            if c > value { upper = c; break }
        }
        return (lower, upper)
    }

    public static func deltas(forSelection sel: Set<CanvasSelectionID>,
                              dx: Int, dy: Int) -> [DocumentIntent.MoveTarget] {
        sel.compactMap { id in
            switch id {
            case .item(let i):  return .init(target: .item(id: i),               dx: dx, dy: dy)
            case .image(let i): return .init(target: .imageDecoration(index: i), dx: dx, dy: dy)
            }
        }
    }

    public static func snap(_ value: Int, gridSize: Int) -> Int {
        guard gridSize > 0 else { return value }
        let r = Int((Double(value) / Double(gridSize)).rounded())
        return r * gridSize
    }
}

public extension View {
    /// Multi-select aware drag: commits a `moveMany` intent for the full
    /// moveable selection when the drag ends.
    func draggableItem(document: LutinProjectDocument,
                       selectionModel: CanvasSelectionModel,
                       id: CanvasSelectionID,
                       snapGrid: Int,
                       guideState: CanvasGuideState) -> some View {
        modifier(ItemDragController(document: document,
                                    selectionModel: selectionModel,
                                    myID: id,
                                    snapGrid: snapGrid,
                                    guideState: guideState))
    }
}

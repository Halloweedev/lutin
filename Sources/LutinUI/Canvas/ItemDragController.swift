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

/// View modifier wrapping a `DragGesture` that mutates the document on
/// drag-end using `DocumentIntent.moveItem`. Snap grid comes from prefs.
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
    func draggableItem(document: LutinProjectDocument, id: String, snapGrid: Int) -> some View {
        modifier(ItemDragModifier(document: document, itemID: id, snapGrid: snapGrid))
    }
}

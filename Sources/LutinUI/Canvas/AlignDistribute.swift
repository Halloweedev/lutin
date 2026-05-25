import SwiftUI
import LutinDocument

public protocol AlignableElement {
    var x: Int { get }
    var y: Int { get }
    func selectionID() -> CanvasSelectionID
}

public enum AlignDistribute {
    public enum Anchor { case left, right, centerHorizontal, top, bottom, middleVertical }
    public enum Axis { case horizontal, vertical }

    public static func align(_ es: [some AlignableElement], anchor: Anchor) -> [DocumentIntent.MoveTarget] {
        guard es.count >= 2 else { return [] }
        let xs = es.map(\.x), ys = es.map(\.y)
        let targetX: Int?, targetY: Int?
        switch anchor {
        case .left: targetX = xs.min(); targetY = nil
        case .right: targetX = xs.max(); targetY = nil
        case .centerHorizontal: targetX = (xs.min()! + xs.max()!) / 2; targetY = nil
        case .top: targetX = nil; targetY = ys.min()
        case .bottom: targetX = nil; targetY = ys.max()
        case .middleVertical: targetX = nil; targetY = (ys.min()! + ys.max()!) / 2
        }
        return es.compactMap { e in
            if let tx = targetX {
                let dx = tx - e.x; return dx == 0 ? nil :
                    DocumentIntent.MoveTarget(target: kind(for: e), dx: dx, dy: 0)
            }
            if let ty = targetY {
                let dy = ty - e.y; return dy == 0 ? nil :
                    DocumentIntent.MoveTarget(target: kind(for: e), dx: 0, dy: dy)
            }
            return nil
        }
    }

    public static func distribute(_ es: [some AlignableElement], axis: Axis) -> [DocumentIntent.MoveTarget] {
        guard es.count >= 3 else { return [] }
        let sorted: [any AlignableElement] = axis == .horizontal
            ? es.sorted { $0.x < $1.x } : es.sorted { $0.y < $1.y }
        let first = sorted.first!, last = sorted.last!
        let span: Int = axis == .horizontal ? (last.x - first.x) : (last.y - first.y)
        let step = Double(span) / Double(sorted.count - 1)
        var result: [DocumentIntent.MoveTarget] = []
        for (i, e) in sorted.enumerated() where i != 0 && i != sorted.count - 1 {
            let ideal = (axis == .horizontal)
                ? first.x + Int((Double(i) * step).rounded())
                : first.y + Int((Double(i) * step).rounded())
            if axis == .horizontal {
                let dx = ideal - e.x
                if dx != 0 {
                    result.append(.init(target: kind(for: e), dx: dx, dy: 0))
                }
            } else {
                let dy = ideal - e.y
                if dy != 0 {
                    result.append(.init(target: kind(for: e), dx: 0, dy: dy))
                }
            }
        }
        return result
    }

    private static func kind(for e: any AlignableElement) -> DocumentIntent.MoveTarget.Kind {
        switch e.selectionID() {
        case .item(let id): return .item(id: id)
        case .image(let i): return .imageDecoration(index: i)
        }
    }
}

public struct AlignDistributeToolbar: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel

    public init(document: LutinProjectDocument, selectionModel: CanvasSelectionModel) {
        self.document = document; self.selectionModel = selectionModel
    }

    public var body: some View {
        HStack(spacing: Tokens.spacing(.xs)) {
            LutinIconButton(systemName: "align.horizontal.left",
                            accessibilityLabel: "Align left edges") { run(.left) }
            LutinIconButton(systemName: "align.horizontal.center",
                            accessibilityLabel: "Align horizontal centers") { run(.centerHorizontal) }
            LutinIconButton(systemName: "align.horizontal.right",
                            accessibilityLabel: "Align right edges") { run(.right) }
            Divider().frame(height: 12)
            LutinIconButton(systemName: "align.vertical.top",
                            accessibilityLabel: "Align top edges") { run(.top) }
            LutinIconButton(systemName: "align.vertical.center",
                            accessibilityLabel: "Align vertical centers") { run(.middleVertical) }
            LutinIconButton(systemName: "align.vertical.bottom",
                            accessibilityLabel: "Align bottom edges") { run(.bottom) }
            if elements.count >= 3 {
                Divider().frame(height: 12)
                LutinIconButton(systemName: "distribute.horizontal",
                                accessibilityLabel: "Distribute horizontally") { distribute(.horizontal) }
                LutinIconButton(systemName: "distribute.vertical",
                                accessibilityLabel: "Distribute vertically") { distribute(.vertical) }
            }
        }
        .padding(Tokens.spacing(.sm))
        .background(Tokens.color(.panelBackground))
        .overlay(SquareShape().stroke(Tokens.color(.divider), lineWidth: Tokens.Size.hairline))
    }

    private struct Element: AlignableElement {
        let id: CanvasSelectionID
        let x: Int
        let y: Int
        func selectionID() -> CanvasSelectionID { id }
    }

    private var elements: [Element] {
        selectionModel.moveableIDs.compactMap { id -> Element? in
            switch id {
            case .item(let i):
                guard let it = document.config.items?.first(where: { $0.id == i }) else { return nil }
                return Element(id: id, x: it.x, y: it.y)
            case .image(let i):
                guard let d = document.config.decorations?[safe: i] else { return nil }
                return Element(id: id, x: d.x ?? 0, y: d.y ?? 0)
            }
        }
    }

    private func run(_ anchor: AlignDistribute.Anchor) {
        let deltas = AlignDistribute.align(elements, anchor: anchor)
        guard !deltas.isEmpty else { return }
        try? document.apply(.moveMany(deltas: deltas))
    }
    private func distribute(_ axis: AlignDistribute.Axis) {
        let deltas = AlignDistribute.distribute(elements, axis: axis)
        guard !deltas.isEmpty else { return }
        try? document.apply(.moveMany(deltas: deltas))
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

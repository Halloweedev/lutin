import SwiftUI
import LutinConfig
import LutinDocument

public struct ArrowLayer: View {
    @Bindable var document: LutinProjectDocument
    @Binding var selection: CanvasSelection
    let iconSize: Int

    public init(document: LutinProjectDocument, selection: Binding<CanvasSelection>, iconSize: Int) {
        self.document = document
        self._selection = selection
        self.iconSize = iconSize
    }

    public var body: some View {
        let items = document.config.items ?? []
        let arrows = (document.config.decorations ?? []).filter { $0.type == "arrow" }
        ZStack {
            ForEach(Array(arrows.enumerated()), id: \.offset) { _, deco in
                if let from = deco.from, let to = deco.to,
                   let route = ArrowRouting.route(from: from, to: to, items: items, iconSize: iconSize) {
                    let isSelected = (selection == .arrow(from: from, to: to))
                    ArrowShape(start: route.start, end: route.end)
                        .stroke(isSelected ? Tokens.color(.arrowSelected) : Tokens.color(.arrowDefault),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .contentShape(ArrowShape(start: route.start, end: route.end).stroke(style: StrokeStyle(lineWidth: 16)))
                        .onTapGesture { selection = .arrow(from: from, to: to) }
                    if let label = deco.label, !label.isEmpty {
                        Text(label)
                            .font(Typography.canvasLabel)
                            .foregroundStyle(isSelected ? Tokens.color(.arrowSelected) : Tokens.color(.arrowDefault))
                            .position(x: (route.start.x + route.end.x) / 2,
                                      y: (route.start.y + route.end.y) / 2 - 10)
                    }
                }
            }
        }
        .allowsHitTesting(true)
    }
}

private struct ArrowShape: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: start)
        p.addLine(to: end)
        // arrow head
        let dx = end.x - start.x, dy = end.y - start.y
        let len = max(0.0001, sqrt(dx*dx + dy*dy))
        let ux = dx / len, uy = dy / len
        let head = end
        let back = CGPoint(x: head.x - ux * 12, y: head.y - uy * 12)
        let left = CGPoint(x: back.x - uy * 6, y: back.y + ux * 6)
        let right = CGPoint(x: back.x + uy * 6, y: back.y - ux * 6)
        p.move(to: head)
        p.addLine(to: left)
        p.move(to: head)
        p.addLine(to: right)
        return p
    }
}

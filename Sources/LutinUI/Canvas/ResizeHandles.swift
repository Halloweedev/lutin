import SwiftUI
import LutinDocument
import LutinConfig

public struct ResizeHandles: View {
    @Bindable var document: LutinProjectDocument
    let index: Int
    let deco: LutinConfig.Decoration
    /// Bounding-box width and height in canvas points. Width comes from
    /// `deco.width`; height is derived by the parent layer from the
    /// source image's aspect ratio. Pass both so the corner / edge dots
    /// land on the actual rectangle, not on a square inferred from
    /// `width × width` (which used to make the dots float off the image
    /// whenever the source wasn't 1:1).
    let widthPoints: CGFloat
    let heightPoints: CGFloat
    @State private var dragStartWidth: Int = 0

    public init(document: LutinProjectDocument,
                index: Int,
                deco: LutinConfig.Decoration,
                widthPoints: CGFloat,
                heightPoints: CGFloat) {
        self.document = document
        self.index = index
        self.deco = deco
        self.widthPoints = widthPoints
        self.heightPoints = heightPoints
    }

    public var body: some View {
        let halfW = widthPoints / 2
        let halfH = heightPoints / 2
        ZStack {
            handle(at: CGPoint(x: -halfW, y: -halfH), direction: .nw)
            handle(at: CGPoint(x: 0,      y: -halfH), direction: .n)
            handle(at: CGPoint(x: halfW,  y: -halfH), direction: .ne)
            handle(at: CGPoint(x: halfW,  y: 0),      direction: .e)
            handle(at: CGPoint(x: halfW,  y: halfH),  direction: .se)
            handle(at: CGPoint(x: 0,      y: halfH),  direction: .s)
            handle(at: CGPoint(x: -halfW, y: halfH),  direction: .sw)
            handle(at: CGPoint(x: -halfW, y: 0),      direction: .w)
        }
    }

    private enum Direction { case n, ne, e, se, s, sw, w, nw }

    private func handle(at offset: CGPoint, direction: Direction) -> some View {
        SquareShape()
            .fill(Tokens.color(.brandAccent))
            .frame(width: 8, height: 8)
            .offset(x: offset.x, y: offset.y)
            .gesture(
                DragGesture(coordinateSpace: .named("canvas"))
                    .onChanged { v in
                        if dragStartWidth == 0 { dragStartWidth = deco.width ?? 100 }
                        let newWidth = max(16, dragStartWidth + dxFor(direction, translation: v.translation))
                        try? document.apply(.moveImageDecoration(index: index,
                                                                 x: deco.x ?? 0,
                                                                 y: deco.y ?? 0,
                                                                 width: newWidth))
                    }
                    .onEnded { _ in dragStartWidth = 0 }
            )
    }

    private func dxFor(_ d: Direction, translation: CGSize) -> Int {
        switch d {
        case .e, .ne, .se: return Int(translation.width)
        case .w, .nw, .sw: return -Int(translation.width)
        case .n, .s: return Int(translation.height)
        }
    }
}

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
    @State private var dragStart: Rect?

    /// Frozen geometry captured at the first `.onChanged` so the whole
    /// drag resolves against a fixed anchor edge instead of compounding.
    struct Rect: Equatable { var x: Int; var y: Int; var width: Int; var height: Int }

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

    enum Direction { case n, ne, e, se, s, sw, w, nw }

    private static let minSize = 16

    private func handle(at offset: CGPoint, direction: Direction) -> some View {
        SquareShape()
            .fill(Tokens.color(.brandAccent))
            .frame(width: 8, height: 8)
            .offset(x: offset.x, y: offset.y)
            .gesture(
                DragGesture(coordinateSpace: .named("canvas"))
                    .onChanged { v in
                        let start = dragStart ?? Rect(x: deco.x ?? 0,
                                                      y: deco.y ?? 0,
                                                      width: deco.width ?? 100,
                                                      height: Int(heightPoints.rounded()))
                        if dragStart == nil { dragStart = start }
                        let r = Self.resized(start, direction: direction, translation: v.translation)
                        try? document.apply(.moveImageDecoration(index: index,
                                                                 x: r.x, y: r.y,
                                                                 width: r.width,
                                                                 height: r.height))
                    }
                    .onEnded { _ in dragStart = nil }
            )
    }

    /// Resizes `start` for a handle drag with the opposite edge anchored.
    /// `(x, y)` is the top-left corner. Corner handles change width and
    /// height; side handles change only their one axis. W/N drags shift
    /// `x`/`y` so the right/bottom edge stays put, even after clamping to
    /// the minimum size.
    static func resized(_ start: Rect, direction d: Direction, translation t: CGSize) -> Rect {
        let dx = Int(t.width.rounded())
        let dy = Int(t.height.rounded())
        var x = start.x, y = start.y, w = start.width, h = start.height
        let right = start.x + start.width
        let bottom = start.y + start.height

        switch d {
        case .e, .ne, .se: w = max(minSize, start.width + dx)
        case .w, .nw, .sw: w = max(minSize, start.width - dx); x = right - w
        default: break
        }
        switch d {
        case .s, .se, .sw: h = max(minSize, start.height + dy)
        case .n, .ne, .nw: h = max(minSize, start.height - dy); y = bottom - h
        default: break
        }
        return Rect(x: x, y: y, width: w, height: h)
    }
}

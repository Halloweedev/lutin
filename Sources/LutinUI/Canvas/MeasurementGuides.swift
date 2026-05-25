import SwiftUI
import CoreGraphics
import LutinConfig

/// Figma-style "hold Option, hover a sibling" overlay. Draws magenta
/// horizontal/vertical distance lines between the selection's bounding
/// box (`from`) and the hovered element (`to`). When the two boxes
/// overlap on one axis, that axis isn't measured — only the gap that
/// actually exists.
///
/// Each line is placed at a sensible anchor:
///   - Horizontal line's Y = midpoint of the vertical overlap if any,
///     otherwise the midpoint of the vertical gap between the boxes.
///   - Vertical line's X = symmetric on the X axis.
///
/// Pre-empts `MeasurementGuides` (canvas-edge readout) when active —
/// `CanvasView` chooses between the two based on whether a non-selected
/// element is currently hovered.
struct MeasurementBetweenGuides: View {
    let from: CGRect  // selection's bbox
    let to: CGRect    // hovered element's bbox

    var body: some View {
        ZStack {
            if let horiz = horizontalSegment {
                segment(start: horiz.start, end: horiz.end, distance: horiz.distance)
            }
            if let vert = verticalSegment {
                segment(start: vert.start, end: vert.end, distance: vert.distance)
            }
        }
        .allowsHitTesting(false)
    }

    private struct Segment {
        let start: CGPoint
        let end: CGPoint
        let distance: Int
    }

    /// Horizontal distance line — nil if the boxes overlap on X.
    private var horizontalSegment: Segment? {
        let y = horizontalLineY()
        if to.minX > from.maxX {
            return Segment(start: CGPoint(x: from.maxX, y: y),
                           end:   CGPoint(x: to.minX,  y: y),
                           distance: Int((to.minX - from.maxX).rounded()))
        }
        if to.maxX < from.minX {
            return Segment(start: CGPoint(x: to.maxX,  y: y),
                           end:   CGPoint(x: from.minX, y: y),
                           distance: Int((from.minX - to.maxX).rounded()))
        }
        return nil
    }

    /// Vertical distance line — nil if the boxes overlap on Y.
    private var verticalSegment: Segment? {
        let x = verticalLineX()
        if to.minY > from.maxY {
            return Segment(start: CGPoint(x: x, y: from.maxY),
                           end:   CGPoint(x: x, y: to.minY),
                           distance: Int((to.minY - from.maxY).rounded()))
        }
        if to.maxY < from.minY {
            return Segment(start: CGPoint(x: x, y: to.maxY),
                           end:   CGPoint(x: x, y: from.minY),
                           distance: Int((from.minY - to.maxY).rounded()))
        }
        return nil
    }

    /// Y at which the horizontal distance line lives. Prefers the
    /// vertical overlap's midpoint (so the line passes through both
    /// boxes), falls back to the midpoint of the vertical gap when
    /// there's no overlap on Y.
    private func horizontalLineY() -> CGFloat {
        let overlapMin = max(from.minY, to.minY)
        let overlapMax = min(from.maxY, to.maxY)
        if overlapMin <= overlapMax { return (overlapMin + overlapMax) / 2 }
        return from.maxY < to.minY
            ? (from.maxY + to.minY) / 2
            : (to.maxY + from.minY) / 2
    }

    private func verticalLineX() -> CGFloat {
        let overlapMin = max(from.minX, to.minX)
        let overlapMax = min(from.maxX, to.maxX)
        if overlapMin <= overlapMax { return (overlapMin + overlapMax) / 2 }
        return from.maxX < to.minX
            ? (from.maxX + to.minX) / 2
            : (to.maxX + from.minX) / 2
    }

    @ViewBuilder
    private func segment(start: CGPoint, end: CGPoint, distance: Int) -> some View {
        ZStack {
            Path { p in
                p.move(to: start); p.addLine(to: end)
            }
            .stroke(Tokens.color(.measurementGuide),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            if distance > 0 {
                Text("\(distance)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Tokens.color(.measurementGuide)))
                    .position(x: (start.x + end.x) / 2,
                              y: (start.y + end.y) / 2)
            }
        }
    }
}

/// Figma-style "hold Option to measure" overlay. While the modifier is
/// held and at least one element is selected, four dashed magenta lines
/// extend from each edge of the selection's union bounding box to the
/// corresponding canvas edge (= the Finder window's content rect), each
/// with a numeric distance label in window points.
///
/// Why magenta: the alignment guides during a drag are already blue
/// (`alignmentGuide`). Measurement is a different mode — quick read,
/// non-mutating — and Figma's pink/magenta convention is recognisable
/// enough to carry across without extra labelling.
///
/// Coordinate space: assumes parent is `.coordinateSpace(.named("canvas"))`
/// — same space the items use. `canvasSize` is the inner content size
/// of `FinderWindowChrome` (= `window.width` × `window.height`).
struct MeasurementGuides: View {
    let itemBounds: CGRect
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            // Top — from item.minY up to y=0.
            measurementSegment(
                start: CGPoint(x: itemBounds.midX, y: 0),
                end: CGPoint(x: itemBounds.midX, y: itemBounds.minY),
                distance: Int(itemBounds.minY.rounded())
            )
            // Bottom — from item.maxY down to canvas bottom.
            measurementSegment(
                start: CGPoint(x: itemBounds.midX, y: itemBounds.maxY),
                end: CGPoint(x: itemBounds.midX, y: canvasSize.height),
                distance: Int((canvasSize.height - itemBounds.maxY).rounded())
            )
            // Left — from x=0 to item.minX.
            measurementSegment(
                start: CGPoint(x: 0, y: itemBounds.midY),
                end: CGPoint(x: itemBounds.minX, y: itemBounds.midY),
                distance: Int(itemBounds.minX.rounded())
            )
            // Right — from item.maxX to canvas right.
            measurementSegment(
                start: CGPoint(x: itemBounds.maxX, y: itemBounds.midY),
                end: CGPoint(x: canvasSize.width, y: itemBounds.midY),
                distance: Int((canvasSize.width - itemBounds.maxX).rounded())
            )
        }
        .allowsHitTesting(false)
    }

    /// Single dashed line + centered distance pill. Skips the pill
    /// (and short-circuits) when the segment is degenerate (zero or
    /// negative distance — means the item edge is flush with, or
    /// outside, the canvas edge). Drawing a "0" pill in that case
    /// reads as noise.
    @ViewBuilder
    private func measurementSegment(start: CGPoint, end: CGPoint, distance: Int) -> some View {
        if distance > 0 {
            ZStack {
                Path { path in
                    path.move(to: start)
                    path.addLine(to: end)
                }
                .stroke(Tokens.color(.measurementGuide),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 2]))

                Text("\(distance)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Tokens.color(.measurementGuide)))
                    .position(x: (start.x + end.x) / 2,
                              y: (start.y + end.y) / 2)
            }
        }
    }
}

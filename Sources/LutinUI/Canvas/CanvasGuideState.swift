import Foundation
import Observation
import LutinDocument

@Observable
public final class CanvasGuideState {
    public var guideX: Int?  // a vertical line at this x
    public var guideY: Int?  // a horizontal line at this y

    /// Element under the mouse pointer. Set/cleared by `.onHover`
    /// handlers in `ItemLayer` / `ImageDecorationLayer`. Drives the
    /// Figma-style Option-hover measurement overlay — when the user
    /// is holding Option, the canvas shows the gap between the
    /// selection and *this* element instead of the canvas edges.
    /// Nil when the pointer isn't over any item.
    public var hoveredID: CanvasSelectionID?

    /// When an item being dragged sits midway between two others on an
    /// axis, we publish the two outer item positions + the snapped
    /// midpoint so the canvas can draw distance pills between them.
    public var equalSpacingX: EqualSpacingHint?  // horizontal axis
    public var equalSpacingY: EqualSpacingHint?  // vertical axis

    public struct EqualSpacingHint: Equatable, Sendable {
        public var leftOrTop: Int     // outer neighbor on the smaller side
        public var rightOrBottom: Int // outer neighbor on the larger side
        public var midpoint: Int      // snapped item position (== midpoint of the two)
        public var distance: Int      // half-span pill label
        public init(leftOrTop: Int, rightOrBottom: Int, midpoint: Int, distance: Int) {
            self.leftOrTop = leftOrTop
            self.rightOrBottom = rightOrBottom
            self.midpoint = midpoint
            self.distance = distance
        }
    }

    public init() {}
}

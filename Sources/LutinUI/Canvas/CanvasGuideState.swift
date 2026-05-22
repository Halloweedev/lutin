import Foundation
import Observation

@Observable
public final class CanvasGuideState {
    public var guideX: Int?  // a vertical line at this x
    public var guideY: Int?  // a horizontal line at this y
    public init() {}
}

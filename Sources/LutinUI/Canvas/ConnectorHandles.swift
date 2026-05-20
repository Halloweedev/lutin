import SwiftUI
import LutinConfig
import LutinDocument

public struct ConnectorHandles: View {
    @Bindable var document: LutinProjectDocument
    let item: LutinConfig.Item
    @Binding var dragState: ConnectorDragState

    public init(document: LutinProjectDocument, item: LutinConfig.Item, dragState: Binding<ConnectorDragState>) {
        self.document = document
        self.item = item
        self._dragState = dragState
    }

    public var body: some View {
        ZStack {
            ForEach(ConnectorEdge.allCases, id: \.self) { edge in
                Circle()
                    .fill(Tokens.color(.brandAccent))
                    .frame(width: 8, height: 8)
                    .offset(edge.offset(half: 26))
                    .gesture(DragGesture(coordinateSpace: .named("canvas"))
                        .onChanged { value in
                            dragState = .active(sourceID: item.id,
                                                 currentPoint: value.location)
                        }
                        .onEnded { value in
                            dragState = .ended(sourceID: item.id, releasePoint: value.location)
                        })
            }
        }
    }
}

public enum ConnectorEdge: CaseIterable {
    case top, right, bottom, left
    func offset(half: CGFloat) -> CGSize {
        switch self {
        case .top:    return CGSize(width: 0, height: -half)
        case .right:  return CGSize(width: half, height: 0)
        case .bottom: return CGSize(width: 0, height: half)
        case .left:   return CGSize(width: -half, height: 0)
        }
    }
}

public enum ConnectorDragState: Equatable {
    case idle
    case active(sourceID: String, currentPoint: CGPoint)
    case ended(sourceID: String, releasePoint: CGPoint)
}

/// Helper used by the canvas: given a release point, find the item the
/// cursor is over (if any), and create the arrow.
public enum ConnectorResolver {
    public static func itemAt(point: CGPoint, items: [LutinConfig.Item], iconSize: Int) -> LutinConfig.Item? {
        let half = CGFloat(iconSize) / 2.0
        return items.first { item in
            let center = CGPoint(x: CGFloat(item.x) + half, y: CGFloat(item.y) + half)
            return abs(center.x - point.x) <= half && abs(center.y - point.y) <= half
        }
    }
}

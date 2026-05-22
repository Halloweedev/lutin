import SwiftUI

public struct SidePanel<Content: View>: View {
    @Binding var width: CGFloat
    let content: Content

    public init(width: Binding<CGFloat>, @ViewBuilder content: () -> Content) {
        self._width = width
        self.content = content()
    }

    public static func clampWidth(_ w: CGFloat) -> CGFloat {
        max(Tokens.Size.sidePanelMin, min(Tokens.Size.sidePanelMax, w))
    }

    public var body: some View {
        HStack(spacing: 0) {
            content
                .frame(width: width)
                .background(Tokens.color(.panelBackground))
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(width: Tokens.Size.hairline)
                .overlay(
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 4)
                        .contentShape(Rectangle())
                        .onHover { inside in
                            if inside { NSCursor.resizeLeftRight.push() }
                            else { NSCursor.pop() }
                        }
                        .gesture(
                            DragGesture(coordinateSpace: .global)
                                .onChanged { v in
                                    width = SidePanel.clampWidth(width + v.translation.width)
                                }
                        )
                )
        }
    }
}

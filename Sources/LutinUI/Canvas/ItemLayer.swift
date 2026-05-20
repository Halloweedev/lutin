import SwiftUI
import LutinConfig
import LutinDocument

public struct ItemLayer: View {
    @Bindable var document: LutinProjectDocument
    @Binding var selection: CanvasSelection

    public init(document: LutinProjectDocument, selection: Binding<CanvasSelection>) {
        self.document = document
        self._selection = selection
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(document.config.items ?? [], id: \.id) { item in
                itemView(for: item)
                    .position(x: CGFloat(item.x), y: CGFloat(item.y))
                    .onTapGesture { selection = .item(id: item.id) }
            }
        }
    }

    private func itemView(for item: LutinConfig.Item) -> some View {
        let isSelected: Bool = (selection == .item(id: item.id))
        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .frame(width: 52, height: 52)
                .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
            Image(systemName: item.type == "applications" ? "folder.fill" : "shippingbox.fill")
                .font(.system(size: 24))
                .foregroundStyle(Tokens.color(.brandAccent))
            if let label = item.label, !label.isEmpty {
                Text(label)
                    .font(Typography.canvasLabel)
                    .offset(y: 36)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Tokens.color(.itemSelected), lineWidth: isSelected ? 2 : 0)
        )
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}

public enum CanvasSelection: Equatable {
    case none
    case item(id: String)
    case arrow(from: String, to: String)
}

import SwiftUI
import LutinConfig
import LutinDocument

public enum OffCanvasDetection {
    public static func outsiders(in config: LutinConfig) -> [CanvasSelectionID] {
        let w = CGFloat(config.window?.width ?? 680)
        let h = CGFloat(config.window?.height ?? 420)
        let iconSize = CGFloat(config.window?.iconSize ?? 96)
        let bounds = CGRect(x: 0, y: 0, width: w, height: h)
        var result: [CanvasSelectionID] = []
        for item in (config.items ?? []) {
            let bbox = CGRect(x: CGFloat(item.x) - iconSize / 2,
                              y: CGFloat(item.y) - iconSize / 2,
                              width: iconSize, height: iconSize)
            if !bounds.contains(bbox) { result.append(.item(id: item.id)) }
        }
        for (i, deco) in (config.decorations ?? []).enumerated() where deco.type == "image" {
            let dw = CGFloat(deco.width ?? 100)
            let bbox = CGRect(x: CGFloat(deco.x ?? 0) - dw / 2,
                              y: CGFloat(deco.y ?? 0) - dw / 2,
                              width: dw, height: dw)
            if !bounds.contains(bbox) { result.append(.image(index: i)) }
        }
        return result
    }
}

public struct OffCanvasStatusStrip: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel

    public init(document: LutinProjectDocument, selectionModel: CanvasSelectionModel) {
        self.document = document; self.selectionModel = selectionModel
    }

    public var body: some View {
        let outsiders = OffCanvasDetection.outsiders(in: document.config)
        if !outsiders.isEmpty {
            LutinButton(role: .secondary,
                        action: { selectionModel.replace(with: [outsiders[0]]) }) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Tokens.color(.offCanvasOutline))
                    Text("\(outsiders.count) outside canvas")
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textSecondary))
                    Spacer()
                    Text("Show").font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.brandAccent))
                }
                .padding(Tokens.spacing(.sm))
                .background(Tokens.color(.panelBackground))
            }
        }
    }
}

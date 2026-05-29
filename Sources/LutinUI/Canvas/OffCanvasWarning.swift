import SwiftUI
import LutinConfig
import LutinDocument

public enum OffCanvasDetection {
    public static func outsiders(in config: LutinConfig,
                                 projectDirectory: URL? = nil) -> [CanvasSelectionID] {
        let w = CGFloat(config.window?.width ?? 680)
        let h = CGFloat(config.window?.height ?? 420)
        let iconSize = CGFloat(config.window?.iconSize ?? 96)
        let bounds = CGRect(x: 0, y: 0, width: w, height: h)
        var result: [CanvasSelectionID] = []
        // Items are positioned by their CENTER (ItemLayer uses
        // `.position(x:item.x, y:item.y)`), so a half-iconSize inset
        // around (x, y) is the real bounding box.
        for item in (config.items ?? []) {
            let bbox = CGRect(x: CGFloat(item.x) - iconSize / 2,
                              y: CGFloat(item.y) - iconSize / 2,
                              width: iconSize, height: iconSize)
            if !bounds.contains(bbox) { result.append(.item(id: item.id)) }
        }
        // Image decorations are drawn with (x, y) as the TOP-LEFT corner
        // and a height that's either explicit (free stretch) or derived
        // from the source aspect ratio — never a width×width square.
        for (i, deco) in (config.decorations ?? []).enumerated() where deco.type == "image" {
            let dw = CGFloat(deco.width ?? 100)
            let dh = resolvedHeight(deco, width: dw, projectDirectory: projectDirectory)
            let bbox = CGRect(x: CGFloat(deco.x ?? 0), y: CGFloat(deco.y ?? 0),
                              width: dw, height: dh)
            if !bounds.contains(bbox) { result.append(.image(index: i)) }
        }
        return result
    }

    private static func resolvedHeight(_ deco: LutinConfig.Decoration,
                                       width: CGFloat,
                                       projectDirectory: URL?) -> CGFloat {
        if let h = deco.height { return CGFloat(h) }
        // Aspect-locked: derive height from the source aspect (cached so this
        // doesn't re-decode the file on every canvas re-render). The square
        // fallback only applies when no projectDirectory is supplied or the
        // image can't be decoded — callers in the live editor always pass one.
        if let path = deco.path, let base = projectDirectory,
           let aspect = ImageSizeCache.aspect(ofPath: path, relativeTo: base) {
            return width * aspect
        }
        return width
    }
}

public struct OffCanvasStatusStrip: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel

    public init(document: LutinProjectDocument, selectionModel: CanvasSelectionModel) {
        self.document = document; self.selectionModel = selectionModel
    }

    public var body: some View {
        let outsiders = OffCanvasDetection.outsiders(in: document.config,
                                                     projectDirectory: document.projectDirectory)
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

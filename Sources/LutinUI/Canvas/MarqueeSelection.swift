import SwiftUI
import LutinConfig
import LutinDocument

public enum MarqueeSelection {
    public static func hits(in config: LutinConfig, rect: CGRect) -> Set<CanvasSelectionID> {
        var result: Set<CanvasSelectionID> = []
        let iconSize = CGFloat(config.window?.iconSize ?? 96)

        for item in (config.items ?? []) {
            let bbox = CGRect(x: CGFloat(item.x) - iconSize/2,
                              y: CGFloat(item.y) - iconSize/2,
                              width: iconSize, height: iconSize)
            if rect.intersects(bbox) { result.insert(.item(id: item.id)) }
        }

        for (i, deco) in (config.decorations ?? []).enumerated() where deco.type == "image" {
            let w = CGFloat(deco.width ?? 100)
            let bbox = CGRect(x: CGFloat(deco.x ?? 0) - w/2,
                              y: CGFloat(deco.y ?? 0) - w/2,
                              width: w, height: w)
            if rect.intersects(bbox) { result.insert(.image(index: i)) }
        }

        for deco in (config.decorations ?? []) where deco.type == "arrow" {
            guard let from = deco.from, let to = deco.to,
                  let fromItem = config.items?.first(where: { $0.id == from }),
                  let toItem = config.items?.first(where: { $0.id == to }) else { continue }
            let bbox = CGRect(
                x: min(CGFloat(fromItem.x), CGFloat(toItem.x)) - 4,
                y: min(CGFloat(fromItem.y), CGFloat(toItem.y)) - 4,
                width: abs(CGFloat(toItem.x - fromItem.x)) + 8,
                height: abs(CGFloat(toItem.y - fromItem.y)) + 8)
            if rect.intersects(bbox) { result.insert(.arrow(from: from, to: to)) }
        }

        return result
    }
}

public struct MarqueeOverlay: View {
    let rect: CGRect?
    public init(rect: CGRect?) { self.rect = rect }
    public var body: some View {
        if let rect {
            SquareShape()
                .stroke(Tokens.color(.marqueeStroke), lineWidth: Tokens.Size.hairline)
                .fill(Tokens.color(.marqueeStroke).opacity(0.1))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
        }
    }
}

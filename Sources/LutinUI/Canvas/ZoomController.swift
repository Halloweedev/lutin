import CoreGraphics

public enum ZoomController {
    public static let steps: [Int] = [25, 50, 75, 100, 125, 150, 200]

    public static func stepUp(from current: Int) -> Int {
        for s in steps where s > current { return s }
        return current
    }

    public static func stepDown(from current: Int) -> Int {
        for s in steps.reversed() where s < current { return s }
        return current
    }

    public static func fitPercent(canvas: CGSize, pane: CGSize) -> Int {
        guard canvas.width > 0, canvas.height > 0 else { return 100 }
        let xFit = pane.width / canvas.width
        let yFit = pane.height / canvas.height
        let raw = min(xFit, yFit, 1.0) * 100
        var chosen = steps.first ?? 25
        for s in steps where Double(s) <= raw { chosen = s }
        return chosen
    }
}

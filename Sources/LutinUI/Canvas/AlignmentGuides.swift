import CoreGraphics

public enum AlignmentGuides {
    public struct SnapResult: Equatable {
        public var value: Int
        public var target: Int?    // nil = no snap fired
    }
    public struct EqualSpacing: Equatable {
        public var snapped: Int
        public var distance: Int
    }

    public static func snap(value: Int, candidates: [Int], threshold: Int) -> SnapResult {
        var best: (target: Int, dist: Int)?
        for c in candidates {
            let d = abs(c - value)
            if d <= threshold && (best == nil || d < best!.dist) {
                best = (c, d)
            }
        }
        if let b = best { return SnapResult(value: b.target, target: b.target) }
        return SnapResult(value: value, target: nil)
    }

    public static func equalSpacing(value: Int, others: [Int], threshold: Int) -> EqualSpacing? {
        let sorted = others.sorted()
        for i in 0..<sorted.count {
            for j in (i+1)..<sorted.count {
                let a = sorted[i], b = sorted[j]
                let mid = (a + b) / 2
                if abs(value - mid) <= threshold {
                    return EqualSpacing(snapped: mid, distance: abs(mid - a))
                }
            }
        }
        return nil
    }
}

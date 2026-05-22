import SwiftUI

/// Zero-corner-radius rectangle. Use this anywhere the codebase reaches for
/// `RoundedRectangle(cornerRadius: 0)` — names the intent and prevents the
/// "let me bump that to 4 pt" drift.
public struct SquareShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(rect) }
}

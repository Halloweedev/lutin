import SwiftUI

/// Forgiveness-padding modifier for every Lutin interactive control.
///
/// Enforces a minimum hit-target height (default `Tokens.Size.controlHeight`,
/// 28pt) and installs a rectangular `contentShape` so the entire frame is
/// clickable — not just the visible glyph or label. The visible chrome is
/// unchanged; only the click area grows. Applied uniformly inside the core
/// controls (`LutinButton`, `LutinIconButton`, `LutinToggle`) so callers
/// never have to think about it.
///
/// Ad-hoc tap rows (list rows, sheet rows) should call this directly:
///
///     HStack { … }
///         .padding(.vertical, Tokens.spacing(.xs))
///         .lutinHitTarget()
///         .onTapGesture { … }
///
/// Avoid stacking `.contentShape(Rectangle())` on top — this modifier
/// already installs one, and a duplicate just adds overhead.
public extension View {
    func lutinHitTarget(minHeight: CGFloat = Tokens.Size.controlHeight) -> some View {
        self
            .frame(minHeight: minHeight)
            .contentShape(Rectangle())
    }
}

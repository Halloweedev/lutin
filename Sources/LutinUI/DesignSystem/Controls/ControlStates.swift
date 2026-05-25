import SwiftUI
import AppKit

/// Shared interaction state machine for every Lutin custom control.
///
/// Owns the @State for hover/press/focus and reports the resolved
/// `State` value to the consumer via `onChange`. Consumers decide how to
/// translate that state into their own fill (text buttons darken a base
/// fill; icon buttons branch on `isInteracting`).
public struct ControlInteractionState: ViewModifier {
    // Tuned for pure-white chrome (2026-05-24): a 4% darken on white
    // (→ 0.96 grey) read as "is anything happening?" — the user explicitly
    // asked for clearly-greyer button hovers. 8/14 now lands the rest /
    // hover / press states at white → 0.92 → 0.86, which reads as
    // discrete steps without feeling heavy.
    public static let hoverDarken: Double = 0.08
    public static let pressDarken: Double = 0.14

    public struct State: Equatable, Sendable {
        public let isHovered: Bool
        public let isPressed: Bool
        public let isFocused: Bool

        public var isInteracting: Bool { isHovered || isPressed || isFocused }

        /// Pure resolution of the darken-on-interact rule. Press wins over
        /// hover/focus. Hover and focus apply the same ~4% darken — by
        /// design, keyboard and pointer users get the same affordance.
        public func resolvedFill(base: NSColor) -> NSColor {
            if isPressed { return Tokens.darken(base, by: ControlInteractionState.pressDarken) }
            if isHovered || isFocused { return Tokens.darken(base, by: ControlInteractionState.hoverDarken) }
            return base
        }
    }

    @SwiftUI.State private var isHovered = false
    @SwiftUI.State private var isPressed = false
    @FocusState private var isFocused: Bool

    private let onChange: (State) -> Void

    public init(onChange: @escaping (State) -> Void) {
        self.onChange = onChange
    }

    public func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isFocused)
            // `.focusEffectDisabled()` MUST live here, after `.focusable()`.
            // If callers apply it on their inner Button instead, SwiftUI
            // still paints its rounded-blue ring once focus settles on the
            // outer focusable this modifier installs — the disable scope
            // does not extend outward through later modifiers. Every Lutin
            // control that adopts this modifier gets the suppression for
            // free, and the bug can't recur in a new control.
            .focusEffectDisabled()
            .onHover { hovering in
                isHovered = hovering
                if !hovering { isPressed = false }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
            .onChange(of: state) { _, new in onChange(new) }
            .onAppear { onChange(state) }
    }

    private var state: State {
        .init(isHovered: isHovered, isPressed: isPressed, isFocused: isFocused)
    }
}

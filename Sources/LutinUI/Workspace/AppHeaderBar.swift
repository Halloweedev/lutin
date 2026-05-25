import SwiftUI
import AppKit

/// Thin strip at the very top of the workspace that holds the macOS
/// traffic lights (close / minimise / zoom) and a hairline divider
/// separating the title-bar zone from the workspace chrome below.
///
/// Height history:
///   - 28pt → 22pt (2026-05-25) — original felt chrome-heavy.
///   - 22pt → 14pt (2026-05-25) — paired with `TrafficLightPositioner`
///     to nudge the standard buttons upward by ~6pt; without that,
///     the 12pt glyphs would visually cross the bottom hairline. The
///     22pt was the "no-tricks" floor; 14pt is the "fits with light
///     repositioning" floor. Halving exactly to 11pt would crop the
///     buttons no matter where we put them.
///
/// The positioner is installed once at the workspace root (see
/// `WorkspaceShell.body`) and re-runs on every window state change.
public struct AppHeaderBar: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Traffic-light reservation — macOS draws close/min/max here when
            // the title bar is transparent. Empty content; the chrome that
            // used to live here moved into the SidePanel.
            Spacer().frame(width: 72)
            Spacer()
        }
        .frame(height: 14)
        .background(Tokens.color(.panelBackground))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(height: Tokens.Size.hairline)
        }
    }
}

/// Bridge that shifts the macOS standard window buttons (close /
/// minimise / zoom) upward in the title-bar coordinate space so they
/// fit inside a shorter `AppHeaderBar` without crossing its hairline.
///
/// Default macOS positioning puts the 12pt buttons ~3pt from the title
/// bar's bottom (= ~7pt from the window's top), which assumes a
/// 22pt-tall title bar. With our 14pt strip, the default would push the
/// buttons' bottom edge ~5pt below the hairline. We nudge them up by
/// roughly that amount so the cluster sits visually inside the strip.
///
/// Re-applies on `didBecomeKey`, `didResize`, and the four full-screen
/// / miniaturise transitions — AppKit recomputes the standard button
/// frames during those state changes and would otherwise revert the
/// offset. Cheap (~6 calls to `setFrameOrigin` per event).
public struct TrafficLightPositioner: NSViewRepresentable {
    /// Y offset within the title bar's bottom-up coord space. Default
    /// macOS value is ~3; a larger value pushes the buttons up toward
    /// the title bar's top edge.
    let buttonOriginY: CGFloat

    public init(buttonOriginY: CGFloat) {
        self.buttonOriginY = buttonOriginY
    }

    public func makeNSView(context: Context) -> NSView {
        let view = WindowAccessView()
        view.buttonOriginY = buttonOriginY
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        guard let access = nsView as? WindowAccessView else { return }
        access.buttonOriginY = buttonOriginY
        access.reposition()
    }
}

private final class WindowAccessView: NSView {
    var buttonOriginY: CGFloat = 3
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        guard let window = self.window else { return }
        let names: [NSNotification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResizeNotification,
            NSWindow.didEnterFullScreenNotification,
            NSWindow.didExitFullScreenNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
        ]
        for name in names {
            let token = NotificationCenter.default.addObserver(
                forName: name, object: window, queue: .main
            ) { [weak self] _ in
                self?.reposition()
            }
            observers.append(token)
        }
        // First pass after attach — AppKit may not have laid out the
        // buttons yet, so jump to the next runloop.
        DispatchQueue.main.async { [weak self] in self?.reposition() }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func reposition() {
        guard let window = self.window else { return }
        let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        for type in types {
            guard let button = window.standardWindowButton(type) else { continue }
            button.setFrameOrigin(NSPoint(x: button.frame.origin.x, y: buttonOriginY))
        }
    }
}

/// Header drawn just above the side panel content. Names the active
/// tab so the panel always knows what it's showing.
///
/// Height is fixed to `Tokens.Size.railWidth` (= 44pt) so the panel
/// header shares the same cell height as the rail's `LogoSlot` and
/// the project-switcher row above. Three stacked top-of-content
/// rows then all snap to the same 44pt rhythm:
///
///   [ 14pt traffic-light strip ]
///   [ 44pt logo + project switcher ]
///   [ 44pt PanelHeader ("Release") ]
///   ─ section content ─
///
/// Horizontal padding is `md` (14pt) — same as `LayersSection`,
/// `InspectorSection`, and `TabBody` — so the tab title's left edge
/// aligns with the section headers and field labels underneath it.
public struct PanelHeader: View {
    let title: String
    public init(_ title: String) { self.title = title }
    public var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Tokens.color(.textPrimary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Tokens.spacing(.md))
            .frame(height: Tokens.Size.railWidth)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Tokens.color(.divider))
                    .frame(height: Tokens.Size.hairline)
            }
    }
}

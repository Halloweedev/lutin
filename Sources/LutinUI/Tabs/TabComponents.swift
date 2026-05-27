import SwiftUI
import AppKit

/// Shared building blocks for tab side panels. Every Window / Project /
/// Release / Design field lays out through these so the four tabs share
/// one visual language: sentence-case section headers, label-above-input
/// rows, hairline-bordered controls with token colors, and a generous
/// vertical rhythm.

/// Outer container for a single tab body — wraps children in a vertical
/// scroll view with the panel background, and applies the standard
/// section gutter padding.
public struct TabBody<Content: View>: View {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            // `md` (14pt) matches the side-panel rhythm used by the Design
            // tab — section headers, field labels, and the panel title all
            // align to the same x. Was `lg` (20pt), creating a 6pt jog
            // when switching between Design and the other tabs.
            .padding(.horizontal, Tokens.spacing(.md))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Tokens.color(.panelBackground))
    }
}

/// A titled group of fields. Header is sentence-case + tertiary; section
/// body has consistent vertical breathing room between rows. Sections
/// separate with a hairline divider.
///
/// The `dense` parameter was retired 2026-05-25 along with the
/// two-density model — every settings tab now uses one rhythm:
///   • inter-row spacing: `sm` (8pt) — tight enough that 6-row
///     sections (Release tab) fit without scrolling, loose enough that
///     toggle-heavy rows (Window / Project) still breathe.
///   • section vertical padding: `md` (14pt) — same gutter on every
///     section boundary in every tab.
///   • header padding-bottom: 4pt — fixed offset between section title
///     and first content row.
public struct SettingsSection<Content: View,
                              HeaderTrailing: View,
                              HeaderMeta: View>: View {
    let title: String
    let footer: String?
    /// Read-only meta — pill, path, status — that sits next to the title and
    /// demotes typographically (`chromeSmall` `textTertiary`). Interactive
    /// controls go in `headerTrailing` instead.
    let headerMeta: HeaderMeta
    let headerTrailing: HeaderTrailing
    let content: Content

    public init(_ title: String,
                footer: String? = nil,
                @ViewBuilder headerMeta: () -> HeaderMeta = { EmptyView() },
                @ViewBuilder headerTrailing: () -> HeaderTrailing = { EmptyView() },
                @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.headerMeta = headerMeta()
        self.headerTrailing = headerTrailing()
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.sm)) {
            HStack(spacing: Tokens.spacing(.sm)) {
                Text(title)
                    .font(Typography.chromeSmall.weight(.medium))
                    .foregroundStyle(Tokens.color(.textTertiary))
                headerMeta
                Spacer()
                headerTrailing
            }
            .padding(.bottom, 4)
            content
            if let footer {
                Text(footer)
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, Tokens.spacing(.md))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(height: Tokens.Size.hairline)
        }
    }
}

/// Field with a label above its input. Used when the input needs the
/// full row width (long text, multi-step pickers, etc.).
public struct SettingsField<Content: View>: View {
    let label: String
    let helper: String?
    let content: Content
    public init(_ label: String,
                helper: String? = nil,
                @ViewBuilder content: () -> Content) {
        self.label = label
        self.helper = helper
        self.content = content()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
            content
            if let helper {
                Text(helper)
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Compact horizontal row: optional leading icon + label (left), and a
/// trailing control (right). Matches the reference's "Padding [slider]
/// 0px" / "Window Crop [toggle]" / "Border Radius [slider] 18px"
/// pattern. Use for boolean toggles, steppers, sliders, and short
/// pickers where the control fits beside the label.
///
/// Optional `helper` shows a tertiary-colored sentence beneath the label
/// — use for rows whose name alone doesn't tell you what they toggle
/// (e.g. "Show toolbar" — *whose* toolbar, exactly?). The helper wraps
/// to fit; the trailing control stays vertically centered against the
/// label + helper as a unit.
///
/// Optional `info` is a quieter alternative to `helper`: a small `ⓘ`
/// glyph next to the label surfaces the description as a system tooltip
/// on hover. Use when the surface is dense and inline sub-lines would
/// crowd it (e.g. the Release tab). `helper` and `info` are mutually
/// exclusive — pass one, not both.
public struct SettingsRow<Content: View>: View {
    let icon: String?
    let label: String
    let helper: String?
    let info: String?
    let content: Content
    public init(icon: String? = nil,
                _ label: String,
                helper: String? = nil,
                info: String? = nil,
                @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.label = label
        self.helper = helper
        self.info = info
        self.content = content()
    }
    public var body: some View {
        HStack(alignment: helper == nil ? .center : .firstTextBaseline,
               spacing: Tokens.spacing(.sm)) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Tokens.color(.textSecondary))
                    .frame(width: 18, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.system(size: 13))
                        .foregroundStyle(Tokens.color(.textPrimary))
                    if let info {
                        Image("info", bundle: LutinAssets.bundle)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(Tokens.color(.textTertiary))
                            .help(info)
                    }
                }
                if let helper {
                    Text(helper)
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textTertiary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Tokens.spacing(.md))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

/// Three-(four-)state status token shared by every readiness or health
/// indicator across the app. Both the dot color and the SF Symbol icon
/// are derived from this enum, so adding a new status case is one edit
/// rather than a search-and-replace across `ReleaseTab.statusRow`,
/// `DoctorSheet.icon`, and `NotaryProfileField.statusLine`.
///
/// • `ok` (green): the user's intent is satisfied.
/// • `warn` (amber/blue): something is unverified or off-default but
///   not strictly broken.
/// • `blocked` (red): a hard problem that will fail the next build.
/// • `inactive` (muted): the feature is off and nothing about its
///   configuration matters.
public enum StatusKind {
    case ok, warn, blocked, inactive

    public var color: Color {
        switch self {
        case .ok:       return Tokens.color(.logSuccess)
        case .warn:     return Tokens.color(.logProgress)
        case .blocked:  return Tokens.color(.logError)
        case .inactive: return Tokens.color(.textTertiary)
        }
    }

    /// Filled SF Symbol — used by surfaces that lead with an icon
    /// (Doctor checks, inline strips). Compact-dot surfaces use
    /// `color` against a plain `Circle()` instead.
    public var systemImage: String {
        switch self {
        case .ok:       return "checkmark.circle.fill"
        case .warn:     return "exclamationmark.triangle.fill"
        case .blocked:  return "xmark.octagon.fill"
        case .inactive: return "circle"
        }
    }
}

/// Compact "section health" indicator: an 8pt colored dot, a message
/// in `chromeSmall`, and an optional one-click "fix" button on the
/// trailing edge. Used at the bottom of every `SettingsSection` that
/// surfaces readiness — the dot color is exactly what the pipeline
/// guard refuses on, so the user sees the build outcome before they
/// trigger it.
public struct StatusRow: View {
    public struct Fix {
        public let label: String
        public let action: () -> Void
        public init(label: String, action: @escaping () -> Void) {
            self.label = label
            self.action = action
        }
    }

    let kind: StatusKind
    let message: String
    let fix: Fix?

    public init(_ kind: StatusKind, _ message: String, fix: Fix? = nil) {
        self.kind = kind
        self.message = message
        self.fix = fix
    }

    public var body: some View {
        HStack(spacing: 8) {
            Circle().fill(kind.color)
                .frame(width: 8, height: 8)
            Text(message)
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Tokens.spacing(.sm))
            if let fix {
                LutinButton(fix.label, action: fix.action)
            }
        }
        .padding(.top, 4)
    }
}

/// Bordered text field that matches the rest of the chrome's flat,
/// square-cornered language. Used everywhere a free-form string lands.
public struct SettingsTextField: View {
    let placeholder: String
    @Binding var text: String
    public init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }
    public var body: some View {
        LutinTextField(placeholder, text: $text)
    }
}

/// A truncated read-only path field with an optional trailing "Choose…"
/// button. Used for App path, Output directory, Entitlements, Appcast, etc.
///
/// Pass `onPick: nil` to render a pure read-only display (no button) —
/// used when the path is set at project-creation time and editing it
/// post-hoc would silently desync paired metadata (e.g. the `.app`
/// bundle ID + version that were sourced at creation).
public struct PathPickerRow: View {
    let value: String
    let placeholder: String
    let onPick: (() -> Void)?
    public init(value: String, placeholder: String = "Not chosen",
                onPick: (() -> Void)? = nil) {
        self.value = value
        self.placeholder = placeholder
        self.onPick = onPick
    }
    public var body: some View {
        HStack(spacing: 0) {
            Text(value.isEmpty ? placeholder : value.collapsedHome)
                .font(Typography.chromeSmall)
                .foregroundStyle(value.isEmpty
                                 ? Tokens.color(.textTertiary)
                                 : Tokens.color(.textPrimary))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            if let onPick {
                LutinIconButton(systemName: "folder",
                                accessibilityLabel: "Choose path",
                                action: onPick)
                    .padding(.trailing, 4)
                    .help("Choose…")
            }
        }
        .background(Tokens.color(.canvasBackground))
        .overlay(SquareShape().stroke(Tokens.color(.divider),
                                      lineWidth: Tokens.Size.hairline))
    }
}

import SwiftUI
import AppKit

/// Shared building blocks for tab side panels. Every Window / Project /
/// Release / Design field lays out through these so the four tabs share
/// one visual language: uppercase section headers, label-above-input
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Tokens.color(.panelBackground))
    }
}

/// A titled group of fields. Header is uppercase + tertiary; section
/// body has generous horizontal padding and vertical breathing room
/// between rows. Sections separate with a hairline divider.
public struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content
    public init(_ title: String,
                footer: String? = nil,
                @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
            Text(title)
                .font(Typography.chromeSmall.weight(.medium))
                .textCase(.uppercase)
                .foregroundStyle(Tokens.color(.textTertiary))
                .padding(.bottom, 4)
            content
            if let footer {
                Text(footer)
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, Tokens.spacing(.lg))
        .padding(.vertical, Tokens.spacing(.lg))
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
public struct SettingsRow<Content: View>: View {
    let icon: String?
    let label: String
    let content: Content
    public init(icon: String? = nil,
                _ label: String,
                @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.label = label
        self.content = content()
    }
    public var body: some View {
        HStack(spacing: Tokens.spacing(.sm)) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Tokens.color(.textSecondary))
                    .frame(width: 18, alignment: .leading)
            }
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Tokens.color(.textPrimary))
            Spacer(minLength: Tokens.spacing(.md))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
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
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(SquareShape().fill(Tokens.color(.canvasBackground)))
            .overlay(SquareShape().stroke(Tokens.color(.divider),
                                          lineWidth: Tokens.Size.hairline))
    }
}

/// A truncated read-only path field with a trailing "Choose…" button.
/// Used for App path, Output directory, Entitlements, Appcast, etc.
public struct PathPickerRow: View {
    let value: String
    let placeholder: String
    let onPick: () -> Void
    public init(value: String, placeholder: String = "Not chosen",
                onPick: @escaping () -> Void) {
        self.value = value
        self.placeholder = placeholder
        self.onPick = onPick
    }
    public var body: some View {
        HStack(spacing: Tokens.spacing(.sm)) {
            Text(value.isEmpty ? placeholder : value)
                .font(Typography.chromeSmall)
                .foregroundStyle(value.isEmpty
                                 ? Tokens.color(.textTertiary)
                                 : Tokens.color(.textPrimary))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(SquareShape().fill(Tokens.color(.canvasBackground)))
                .overlay(SquareShape().stroke(Tokens.color(.divider),
                                              lineWidth: Tokens.Size.hairline))
            LutinButton("Choose…", action: onPick)
        }
    }
}

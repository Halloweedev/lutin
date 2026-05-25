import SwiftUI

/// Header-collapsed content section with the toggle chevron pinned to the
/// trailing edge. Drop-in replacement for SwiftUI's DisclosureGroup with
/// reversed chevron alignment + lutin styling.
public struct LutinCollapsibleSection<Header: View, Content: View>: View {
    let isExpanded: Binding<Bool>
    let header: () -> Header
    let content: () -> Content

    public init(isExpanded: Binding<Bool>,
                @ViewBuilder header: @escaping () -> Header,
                @ViewBuilder content: @escaping () -> Content) {
        self.isExpanded = isExpanded
        self.header = header
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                header()
                Spacer()
                LutinIconButton(
                    systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down",
                    accessibilityLabel: isExpanded.wrappedValue ? "Collapse" : "Expand",
                    action: { isExpanded.wrappedValue.toggle() }
                )
            }
            // Horizontal `md` matches the section rows below (LayersSection,
            // InspectorCategory) so the chevron sits flush with the row's
            // trailing icon (eye, etc.). Was `sm` and the chevron drifted
            // ~6pt right of the eyes — visually noisy.
            .padding(.horizontal, Tokens.spacing(.md))
            .padding(.vertical, Tokens.spacing(.xs))
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.wrappedValue.toggle() }
            if isExpanded.wrappedValue {
                content()
            }
        }
    }
}

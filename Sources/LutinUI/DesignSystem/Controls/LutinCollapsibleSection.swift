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
            .padding(.horizontal, Tokens.spacing(.sm))
            .padding(.vertical, Tokens.spacing(.xs))
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.wrappedValue.toggle() }
            if isExpanded.wrappedValue {
                content()
            }
        }
    }
}

import SwiftUI
import UniformTypeIdentifiers

public struct LibrarySection: View {
    @State private var isExpanded: Bool = true

    public init() {}

    public var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            HStack(spacing: Tokens.spacing(.sm)) {
                ForEach(LibraryItem.allCases, id: \.self) { item in
                    chip(item)
                }
            }
            .padding(.horizontal, Tokens.spacing(.md))
            .padding(.vertical, Tokens.spacing(.sm))
        } label: {
            Text("Library").font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
                .textCase(.uppercase)
                .padding(.horizontal, Tokens.spacing(.md))
                .padding(.top, Tokens.spacing(.sm))
        }
    }

    private func chip(_ item: LibraryItem) -> some View {
        VStack(spacing: 4) {
            ZStack {
                SquareShape().fill(Tokens.color(.canvasBackground))
                Image(systemName: item.iconSystemName)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Tokens.color(.textPrimary))
            }
            .frame(width: 56, height: 56)
            .overlay(SquareShape().stroke(Tokens.color(.divider), lineWidth: Tokens.Size.hairline))
            Text(item.title).font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
        }
        .onDrag {
            NSItemProvider(object: item.rawValue as NSString)
        }
    }
}

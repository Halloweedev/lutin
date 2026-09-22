import SwiftUI

/// An approximation of an App Store product page, rendered from the same
/// `StoreMetadataLocalization` the validator reads.
///
/// This is the second implementation of the idea `FinderWindowChrome`
/// established for the DMG: the canvas shows what the artefact becomes, not a
/// diagram of it. It renders from the live model, holds no snapshot, and needs
/// no asc, no network and no auth — so it works while offline.
///
/// It is an approximation and says so on every render.
public struct ProductPagePreview: View {
    let model: StorePreviewModel
    let assets: StoreAssets

    public init(model: StorePreviewModel, assets: StoreAssets) {
        self.model = model
        self.assets = assets
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            screenshotStrip
            section(title: "Description", body: model.descriptionText)
            section(title: "What's New", body: model.whatsNew)
            honesty
        }
        .padding(20)
        .frame(width: model.pageWidth, alignment: .leading)
        .background(Tokens.color(.surface))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        // Applied last so it wraps everything above: the appearance axis
        // flips the tokens' dynamic NSColors for the whole page, not just the
        // parts drawn after it.
        .environment(\.colorScheme, model.appearance)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("App Store product page preview, \(model.device.displayName), \(model.locale)")
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            iconView
            VStack(alignment: .leading, spacing: 3) {
                Text(model.name ?? "Name not set")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Tokens.color(model.name == nil ? .textTertiary : .textPrimary))
                Text(model.subtitle ?? "Subtitle not set")
                    .font(Typography.chrome)
                    .foregroundStyle(Tokens.color(model.subtitle == nil ? .textTertiary : .textSecondary))
                if let note = model.truncationNote {
                    Text(note)
                        .font(Typography.inspectorLabel)
                        .foregroundStyle(Tokens.color(.logProgress))
                        .padding(.top, 1)
                }
            }
            Spacer(minLength: 8)
            Text(model.locale)
                .font(Typography.inspectorValue)
                .foregroundStyle(Tokens.color(.textSecondary))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Tokens.color(.surfaceElevated),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let image = assets.icon {
            Image(nsImage: image)
                .resizable()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Tokens.color(.surfaceElevated))
                .frame(width: 76, height: 76)
                .overlay(
                    Image(systemName: "app.dashed")
                        .font(.system(size: 26))
                        .foregroundStyle(Tokens.color(.textTertiary)))
        }
    }

    // MARK: - Screenshots

    @ViewBuilder
    private var screenshotStrip: some View {
        if model.showsScreenshotPlaceholder {
            emptyScreenshotSlot
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(assets.screenshots.enumerated()), id: \.offset) { _, shot in
                        Image(nsImage: shot)
                            .resizable()
                            .aspectRatio(model.screenshotAspectRatio, contentMode: .fit)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    /// The slot is explicit, never absent: it is the completeness signal, the
    /// place where a missing screenshot is visible rather than implied.
    private var emptyScreenshotSlot: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Tokens.color(.divider),
                          style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .aspectRatio(model.screenshotAspectRatio, contentMode: .fit)
            .frame(height: 260)
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 22))
                    Text("No screenshots")
                        .font(Typography.controlLabel)
                    Text("This listing has none yet — the slot stays visible so the gap is too.")
                        .font(Typography.inspectorLabel)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                }
                .foregroundStyle(Tokens.color(.textTertiary))
            )
    }

    // MARK: - Text sections

    @ViewBuilder
    private func section(title: String, body text: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typography.chrome.weight(.semibold))
                .foregroundStyle(Tokens.color(.textPrimary))
            if let text {
                Text(text)
                    .font(Typography.chrome)
                    .foregroundStyle(Tokens.color(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Not set")
                    .font(Typography.chrome)
                    .foregroundStyle(Tokens.color(.textTertiary))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Tokens.color(.divider),
                                          style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
        }
    }

    private var honesty: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
            Text(StorePreviewModel.honestyLabel)
                .font(Typography.inspectorLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Tokens.color(.textTertiary))
        .padding(.top, 2)
    }
}

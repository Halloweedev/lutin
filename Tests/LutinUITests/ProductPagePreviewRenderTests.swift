import AppKit
import SwiftUI
import XCTest
@testable import LutinUI

/// Render-level checks for the preview.
///
/// The model tests cover every variant's logic; these cover what only drawing
/// can answer: that each device and appearance variant actually paints, and
/// that the appearance axis genuinely flips the token-driven colours (a
/// dynamic `NSColor` resolved by AppKit does not have to follow a SwiftUI
/// environment change, so this is worth proving rather than assuming).
///
/// Set `LUTIN_PREVIEW_DUMP=1` to also write the renders to `/tmp` for eyeballing.
@MainActor
final class ProductPagePreviewRenderTests: XCTestCase {

    private func snapshot(_ model: StorePreviewModel,
                          size: CGSize = CGSize(width: 760, height: 640)) -> NSBitmapImageRep {
        let appearance = model.appearance == .dark ? "dark" : "light"
        return snapshotPNG(ProductPagePreview(model: model, assets: StoreAssets()),
                           size: size,
                           dumpName: "lutin-preview-\(model.device.rawValue)-\(appearance)")
    }

    private var fullListing: StoreListing {
        StoreListing(locale: "en-US",
                     name: "Sayrise",
                     subtitle: "Ship your app",
                     descriptionText: String(repeating: "A description of the app. ", count: 12),
                     whatsNew: "First release.")
    }

    func testEveryDeviceVariantPaintsContent() {
        for device in StorePreviewDevice.allCases {
            let model = StorePreviewModel(listing: fullListing, assets: StoreAssets(),
                                          device: device, appearance: .light)
            XCTAssertGreaterThan(sampledColors(snapshot(model)).count, 4,
                                 "\(device.displayName): the preview must paint more than a flat rectangle")
        }
    }

    func testTheEmptyScreenshotSlotStillPaintsAFullPage() {
        // Only a name: the screenshot slot, the three missing text slots and
        // the honesty line all still draw.
        let model = StorePreviewModel(listing: StoreListing(locale: "en-US", name: "Sayrise"),
                                      assets: StoreAssets(), device: .mac, appearance: .light)
        XCTAssertGreaterThan(sampledColors(snapshot(model)).count, 4)
    }

    func testTheAppearanceVariantFlipsTheRenderedTokens() {
        for device in StorePreviewDevice.allCases {
            let light = StorePreviewModel(listing: fullListing, assets: StoreAssets(),
                                          device: device, appearance: .light)
            let dark = StorePreviewModel(listing: fullListing, assets: StoreAssets(),
                                         device: device, appearance: .dark)
            XCTAssertNotEqual(sampledColors(snapshot(light)), sampledColors(snapshot(dark)),
                              "\(device.displayName): light and dark renders must genuinely differ")
        }
    }
}

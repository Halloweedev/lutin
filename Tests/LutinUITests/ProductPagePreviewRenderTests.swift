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
final class ProductPagePreviewRenderTests: XCTestCase {

    private func snapshot(_ model: StorePreviewModel,
                          size: CGSize = CGSize(width: 760, height: 640)) -> NSBitmapImageRep {
        let host = NSHostingView(rootView: ProductPagePreview(model: model, assets: StoreAssets()))
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        host.cacheDisplay(in: host.bounds, to: rep)

        if ProcessInfo.processInfo.environment["LUTIN_PREVIEW_DUMP"] == "1" {
            let appearance = model.appearance == .dark ? "dark" : "light"
            let name = "lutin-preview-\(model.device.rawValue)-\(appearance).png"
            try? rep.representation(using: .png, properties: [:])?
                .write(to: URL(fileURLWithPath: "/tmp/\(name)"))
        }
        return rep
    }

    /// A sampled colour signature: enough to tell "painted something" from
    /// "painted a flat rectangle", and light from dark.
    private func sampledColors(_ rep: NSBitmapImageRep) -> Set<UInt32> {
        var seen = Set<UInt32>()
        for x in stride(from: 0, to: rep.pixelsWide, by: 7) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: 7) {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                let packed = (UInt32(color.redComponent * 255) << 16)
                    | (UInt32(color.greenComponent * 255) << 8)
                    | UInt32(color.blueComponent * 255)
                seen.insert(packed)
            }
        }
        return seen
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

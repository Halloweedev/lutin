import AppKit
import SwiftUI
import XCTest
import LutinStoreMetadata
@testable import LutinUI

/// Spec 1a §8: the preview is a pure function of its inputs, so every locale,
/// device, appearance and truncation variant is asserted here without rendering.
final class StorePreviewTests: XCTestCase {

    private func listing(name: String? = "Sayrise",
                         subtitle: String? = "Ship your app",
                         descriptionText: String? = "A description of the app.",
                         whatsNew: String? = "First release.") -> StoreListing {
        StoreListing(locale: "en-US", name: name, subtitle: subtitle,
                     descriptionText: descriptionText, whatsNew: whatsNew)
    }

    private func model(_ listing: StoreListing,
                       assets: StoreAssets = StoreAssets(),
                       device: StorePreviewDevice = .mac,
                       appearance: ColorScheme = .light) -> StorePreviewModel {
        StorePreviewModel(listing: listing, assets: assets, device: device, appearance: appearance)
    }

    // MARK: - Truncation agrees with the declared limits

    func testNameAtItsDeclaredLimitIsNotTruncated() {
        let exact = String(repeating: "n", count: StoreMetadataField.name.limit!)
        let m = model(listing(name: exact))
        XCTAssertEqual(m.name, exact)
        XCTAssertFalse(m.nameWasTruncated)
        XCTAssertNil(m.truncationNote)
    }

    func testNameOverItsDeclaredLimitIsTruncatedToThatLimit() {
        let limit = StoreMetadataField.name.limit!
        let m = model(listing(name: String(repeating: "n", count: limit + 1)))
        XCTAssertTrue(m.nameWasTruncated)
        XCTAssertEqual(m.name?.count, limit, "the displayed value keeps exactly the declared budget")
        XCTAssertTrue(m.name?.hasSuffix("…") == true)
        XCTAssertEqual(m.truncationNote, "Apple truncates the name on the product page.")
    }

    func testSubtitleOverItsDeclaredLimitIsTruncatedToThatLimit() {
        let limit = StoreMetadataField.subtitle.limit!
        let m = model(listing(subtitle: String(repeating: "s", count: limit + 5)))
        XCTAssertTrue(m.subtitleWasTruncated)
        XCTAssertEqual(m.subtitle?.count, limit)
        XCTAssertEqual(m.truncationNote, "Apple truncates the subtitle on the product page.")
    }

    func testBothTruncatedFieldsAreNamedTogether() {
        let long = String(repeating: "x", count: 60)
        let m = model(listing(name: long, subtitle: long))
        XCTAssertEqual(m.truncationNote, "Apple truncates the name and subtitle on the product page.")
    }

    /// Description carries a validation limit but the product page renders it
    /// in full — only the two header fields are shortened.
    func testDescriptionIsNotTruncatedEvenThoughItHasALimit() {
        let long = String(repeating: "d", count: (StoreMetadataField.description.limit ?? 4000) + 200)
        let m = model(listing(descriptionText: long))
        XCTAssertEqual(m.descriptionText, long)
        XCTAssertNil(m.truncationNote)
    }

    // MARK: - The four variant axes

    func testEveryDeviceVariantIsCarriedAndGeometricallyDistinct() {
        let devices = StorePreviewDevice.allCases
        XCTAssertEqual(devices.count, 3)
        XCTAssertEqual(Set(devices.map { model(listing(), device: $0).pageWidth }).count, 3)
        XCTAssertEqual(Set(devices.map { model(listing(), device: $0).screenshotAspectRatio }).count, 3)
        for device in devices {
            XCTAssertEqual(model(listing(), device: device).device, device)
            XCTAssertFalse(device.displayName.isEmpty)
        }
    }

    func testEveryAppearanceVariantIsCarried() {
        XCTAssertEqual(model(listing(), appearance: .light).appearance, .light)
        XCTAssertEqual(model(listing(), appearance: .dark).appearance, .dark)
    }

    func testLocaleIsCarriedAndDistinguishesModels() {
        let en = model(StoreListing(locale: "en-US", name: "Sayrise"))
        let fr = model(StoreListing(locale: "fr-FR", name: "Sayrise"))
        XCTAssertEqual(en.locale, "en-US")
        XCTAssertEqual(fr.locale, "fr-FR")
        XCTAssertNotEqual(en, fr)
    }

    // MARK: - Completeness is explicit

    func testAnEmptyListingReportsEveryTextFieldAsMissing() {
        let m = model(StoreListing(locale: "en-US"))
        XCTAssertEqual(m.missingFields, [.name, .subtitle, .description, .whatsNew])
    }

    func testAPartialListingReportsOnlyWhatIsMissing() {
        let m = model(StoreListing(locale: "en-US", name: "Sayrise", descriptionText: "D"))
        XCTAssertEqual(m.missingFields, [.subtitle, .whatsNew])
    }

    func testTheScreenshotSlotIsExplicitWhenTheListingHasNoScreenshots() {
        let m = model(listing(), assets: StoreAssets(icon: nil, screenshots: []))
        XCTAssertEqual(m.screenshotCount, 0)
        XCTAssertTrue(m.showsScreenshotPlaceholder,
                      "the empty slot is the completeness signal, not an omission")
    }

    func testThePlaceholderGivesWayWhenScreenshotsArrive() {
        let shot = NSImage(size: CGSize(width: 100, height: 200))
        let m = model(listing(), assets: StoreAssets(screenshots: [shot, shot]))
        XCTAssertEqual(m.screenshotCount, 2)
        XCTAssertFalse(m.showsScreenshotPlaceholder,
                       "Spec 2's screenshots render in the same slot with no structural change")
    }

    // MARK: - Reading the canonical tree

    func testListingReadsNameFromAppInfoAndTextFromVersion() throws {
        let appInfo = try StoreMetadataLocalization.decode(
            Data(#"{"name":"Sayrise","subtitle":"Ship it"}"#.utf8), scope: .appInfo, locale: "en-US")
        let version = try StoreMetadataLocalization.decode(
            Data(#"{"description":"D","whatsNew":"W"}"#.utf8), scope: .version, locale: "en-US")

        let listing = StoreListing(locale: "en-US", appInfo: appInfo, version: version)
        XCTAssertEqual(listing.name, "Sayrise")
        XCTAssertEqual(listing.subtitle, "Ship it")
        XCTAssertEqual(listing.descriptionText, "D")
        XCTAssertEqual(listing.whatsNew, "W")
    }

    func testBlankValuesCountAsUnsetWhenReadingTheTree() throws {
        let appInfo = try StoreMetadataLocalization.decode(
            Data(#"{"name":"","subtitle":"   "}"#.utf8), scope: .appInfo, locale: "en-US")
        let listing = StoreListing(locale: "en-US", appInfo: appInfo, version: nil)
        XCTAssertNil(listing.name)
        XCTAssertNil(listing.subtitle)
    }

    // MARK: - Honesty

    func testTheHonestyLabelSaysItIsAnApproximation() {
        XCTAssertTrue(StorePreviewModel.honestyLabel.localizedCaseInsensitiveContains("approximation"))
        XCTAssertFalse(StorePreviewModel.honestyLabel.isEmpty)
    }
}

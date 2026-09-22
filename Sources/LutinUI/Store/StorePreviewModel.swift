import AppKit
import Foundation
import LutinStoreMetadata
import SwiftUI

/// The App Store surfaces Lutin can approximate.
///
/// Apple lays the product page out differently per family, so the device is a
/// variant axis rather than decoration: a Mac listing is a wide page with 16:10
/// shots, a phone listing a tall one.
public enum StorePreviewDevice: String, CaseIterable, Sendable, Identifiable {
    case iPhone, iPad, mac

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .iPhone: return "iPhone"
        case .iPad: return "iPad"
        case .mac: return "Mac"
        }
    }

    /// Screenshot proportions, following Apple's asset sizes: 6.9" portrait
    /// for iPhone, 3:4 for iPad, 16:10 for Mac.
    public var screenshotAspectRatio: CGFloat {
        switch self {
        case .iPhone: return 9.0 / 19.5
        case .iPad: return 3.0 / 4.0
        case .mac: return 16.0 / 10.0
        }
    }

    /// Width of the previewed page.
    public var pageWidth: CGFloat {
        switch self {
        case .iPhone: return 390
        case .iPad: return 540
        case .mac: return 680
        }
    }
}

/// Non-text material a listing points at.
///
/// Deliberately the single extension point for assets: Spec 1a carries the icon
/// only, and Spec 2 fills `screenshots` without the carousel changing shape.
public struct StoreAssets {
    public var icon: NSImage?
    public var screenshots: [NSImage]

    public init(icon: NSImage? = nil, screenshots: [NSImage] = []) {
        self.icon = icon
        self.screenshots = screenshots
    }

    /// Resolves the icon the way the create sheet and project switcher already do.
    public static func forApp(at url: URL) -> StoreAssets {
        StoreAssets(icon: NSWorkspace.shared.icon(forFile: url.path))
    }

    public var screenshotCount: Int { screenshots.count }
}

/// The text of one locale's listing, in the shape the preview renders.
public struct StoreListing: Equatable, Sendable {
    public var locale: String
    public var name: String?
    public var subtitle: String?
    public var descriptionText: String?
    public var whatsNew: String?

    public init(locale: String,
                name: String? = nil,
                subtitle: String? = nil,
                descriptionText: String? = nil,
                whatsNew: String? = nil) {
        self.locale = locale
        self.name = name
        self.subtitle = subtitle
        self.descriptionText = descriptionText
        self.whatsNew = whatsNew
    }

    /// Reads the canonical tree: `app-info` carries name/subtitle, `version`
    /// carries description/What's New. Blank counts as unset, matching asc.
    public init(locale: String,
                appInfo: StoreMetadataLocalization?,
                version: StoreMetadataLocalization?) {
        self.init(locale: locale,
                  name: Self.value(.name, in: appInfo),
                  subtitle: Self.value(.subtitle, in: appInfo),
                  descriptionText: Self.value(.description, in: version),
                  whatsNew: Self.value(.whatsNew, in: version))
    }

    private static func value(_ field: StoreMetadataField,
                              in localization: StoreMetadataLocalization?) -> String? {
        guard let raw = localization?.values[field]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return raw
    }
}

/// Everything the preview renders, derived purely from its inputs.
///
/// Pure on purpose: every variant — locale, device, appearance, truncation — is
/// asserted here without rendering a view, which is what makes the preview
/// testable at all.
public struct StorePreviewModel: Equatable {
    public let locale: String
    public let device: StorePreviewDevice
    public let appearance: ColorScheme
    public let name: String?
    public let subtitle: String?
    public let descriptionText: String?
    public let whatsNew: String?
    public let nameWasTruncated: Bool
    public let subtitleWasTruncated: Bool
    /// Fields the listing has no value for, in display order — the preview's
    /// completeness signal, shown as an explicit empty slot rather than a gap.
    public let missingFields: [StoreMetadataField]
    public let screenshotCount: Int
    public let showsScreenshotPlaceholder: Bool

    /// Said wherever the preview renders, so it is never mistaken for a guarantee.
    public static let honestyLabel =
        "Approximation of the App Store product page. Apple's layout changes — this is a guide, not a guarantee."

    public var pageWidth: CGFloat { device.pageWidth }
    public var screenshotAspectRatio: CGFloat { device.screenshotAspectRatio }

    /// One line naming what Apple will shorten, when it applies.
    public var truncationNote: String? {
        var fields: [String] = []
        if nameWasTruncated { fields.append("name") }
        if subtitleWasTruncated { fields.append("subtitle") }
        guard !fields.isEmpty else { return nil }
        return "Apple truncates the \(fields.joined(separator: " and ")) on the product page."
    }

    public init(listing: StoreListing,
                assets: StoreAssets,
                device: StorePreviewDevice,
                appearance: ColorScheme) {
        let name = Self.truncate(listing.name, to: StoreMetadataField.name.limit)
        let subtitle = Self.truncate(listing.subtitle, to: StoreMetadataField.subtitle.limit)

        var missing: [StoreMetadataField] = []
        if listing.name == nil { missing.append(.name) }
        if listing.subtitle == nil { missing.append(.subtitle) }
        if listing.descriptionText == nil { missing.append(.description) }
        if listing.whatsNew == nil { missing.append(.whatsNew) }

        self.locale = listing.locale
        self.device = device
        self.appearance = appearance
        self.name = name.text
        self.subtitle = subtitle.text
        self.descriptionText = listing.descriptionText
        self.whatsNew = listing.whatsNew
        self.nameWasTruncated = name.truncated
        self.subtitleWasTruncated = subtitle.truncated
        self.missingFields = missing
        self.screenshotCount = assets.screenshotCount
        self.showsScreenshotPlaceholder = assets.screenshotCount == 0
    }

    /// Apple shortens with an ellipsis once a value passes its declared limit.
    /// The displayed string keeps exactly `limit` characters, so the preview
    /// shows the same budget the validator enforces (single source: the field's
    /// own `limit`).
    static func truncate(_ value: String?, to limit: Int?) -> (text: String?, truncated: Bool) {
        guard let value else { return (nil, false) }
        guard let limit, value.count > limit else { return (value, false) }
        return (String(value.prefix(max(limit - 1, 1))) + "…", true)
    }
}

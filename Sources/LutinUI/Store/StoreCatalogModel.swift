import Foundation
import LutinStoreConnect

/// §7.2's App section, as data: the resolved app and platform.
public struct StoreAppModel: Equatable {
    public struct Row: Equatable, Identifiable {
        public let id: String
        public let label: String
        public let value: String
        public let isMonospaced: Bool

        public init(label: String, value: String, isMonospaced: Bool) {
            self.id = label
            self.label = label
            self.value = value
            self.isMonospaced = isMonospaced
        }
    }
    public let rows: [Row]
    public let note: String?

    public static func make(app: ASCApp?, appID: String?, bundleID: String?,
                            platform: String) -> StoreAppModel {
        var rows: [Row] = []
        rows.append(Row(label: "App ID", value: appID ?? "resolved by asc", isMonospaced: true))
        if let app {
            rows.append(Row(label: "Name", value: app.name ?? "—", isMonospaced: false))
            rows.append(Row(label: "Bundle ID", value: app.bundleID ?? "—", isMonospaced: true))
            if let sku = app.sku { rows.append(Row(label: "SKU", value: sku, isMonospaced: true)) }
            if let locale = app.primaryLocale {
                rows.append(Row(label: "Primary locale", value: locale, isMonospaced: true))
            }
        }
        rows.append(Row(label: "Platform", value: platform, isMonospaced: true))

        // `normalized` is the engine's own rule, so "stated" means the same
        // thing on both sides: a blank configured or record value never
        // produces a verification claim §4.2 did not make.
        let expected = StoreLogic.normalized(bundleID)
        let actual = StoreLogic.normalized(app?.bundleID)
        let note: String
        if StoreLogic.normalized(appID) == nil {
            note = "asc resolves the app (ASC_APP_ID or .asc/config.json). Set store.appID to pin it — bundleID can only be verified against a pinned app."
        } else if expected == nil {
            note = "Set store.bundleID to have Lutin verify the resolved app is the one you meant."
        } else if actual == nil {
            note = "asc returned no bundle ID for the resolved app, so store.bundleID could not be verified."
        } else {
            note = "store.bundleID is verified against the resolved app."
        }
        return StoreAppModel(rows: rows, note: note)
    }
}

/// §7.3's Versions section, as data: App Store versions and states, newest
/// first, read-only.
public struct StoreVersionsModel: Equatable {
    public struct Version: Equatable, Identifiable {
        public let id: String
        public let versionString: String
        public let state: String?
        public let releaseType: String?
        public let createdLabel: String?
        public var isLive: Bool { state == "READY_FOR_SALE" }

        public var detail: String {
            [state?.lowercased().replacingOccurrences(of: "_", with: " "),
             createdLabel, releaseType?.lowercased()]
                .compactMap { $0 }
                .joined(separator: " · ")
        }
    }
    public let versions: [Version]
    public let platform: String
    public let isEmpty: Bool

    public static func make(versions: [ASCAppStoreVersion], platform: String) -> StoreVersionsModel {
        StoreVersionsModel(
            versions: ASCAppStoreVersion.newestFirst(versions).map { version in
                Version(id: version.id, versionString: version.versionString,
                        state: version.state, releaseType: version.releaseType,
                        createdLabel: version.createdDate.map { String($0.prefix(10)) })
            },
            platform: platform, isEmpty: versions.isEmpty)
    }
}

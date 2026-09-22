import Foundation
import LutinConfig
import LutinCore
import LutinDocument
import LutinStoreConnect
import LutinStoreMetadata
import Network
import SwiftUI

/// Everything the Store tab renders, loaded once per open and refreshed on
/// demand.
///
/// The listing is re-read from the metadata directory rather than snapshotted:
/// the preview and the validator must not be able to disagree about what a push
/// would send (§4.5's reasoning, applied to the GUI).
@Observable
@MainActor
public final class StoreTabState {
    public private(set) var connection: StoreConnectionSnapshot?
    public private(set) var listing = StoreListing(locale: "en-US")
    public private(set) var assets = StoreAssets()
    /// Set when the metadata tree is missing, empty, or has nothing for the
    /// chosen locale — the honest explanation for a sparse preview.
    public private(set) var listingNote: String?
    public private(set) var isRefreshing = false

    /// Locales the metadata tree actually has — the only ones the preview can
    /// show, because the preview has no second data path.
    public private(set) var availableLocales: [String] = []
    public var device: StorePreviewDevice = .mac
    public var appearance: ColorScheme = .light
    public var locale: String = "en-US"

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "lutin.store.connectivity")
    public private(set) var isOnline = true
    /// Injected so the tab's loading is testable — and so a test can never
    /// reach the real `asc` by accident.
    private let runner: CommandRunning

    public init(runner: CommandRunning = ShellCommandRunner()) {
        self.runner = runner
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in self?.isOnline = online }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit { monitor.cancel() }

    public var previewModel: StorePreviewModel {
        StorePreviewModel(listing: listing, assets: assets,
                          device: device, appearance: appearance)
    }

    // MARK: - Loading

    public func refresh(document: LutinProjectDocument) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var status: StoreLogic.StoreStatusPayload?
        var failure: LutinError?
        do {
            status = try StoreLogic.status(configURL: document.configURL, runner: runner)
        } catch let error as LutinError {
            failure = error
        } catch {
            failure = LutinError(code: "store_asc_failed", message: "\(error)")
        }
        connection = StoreConnectionSnapshot.make(status: status, error: failure, isOnline: isOnline)

        loadListing(document: document)
    }

    /// Reads `app-info/<locale>.json` and the single `version/<v>/<locale>.json`
    /// if the tree has them. Anything absent stays absent — the preview renders
    /// gaps explicitly, so an incomplete listing is information, not an error.
    private func loadListing(document: LutinProjectDocument) {
        let store = document.config.store
        let root = document.projectDirectory
            .appendingPathComponent(store?.resolvedMetadataDir ?? StoreInfo.defaultMetadataDir)
        let tree = StoreMetadataDirectory(root: root)

        let locales = tree.allLocales
        availableLocales = locales
        if !locales.isEmpty, !locales.contains(locale) {
            locale = locales[0]
        }

        let versions = (try? tree.versionDirectories()) ?? []
        let version = versions.count == 1 ? versions[0] : nil
        let appInfo = try? tree.localization(scope: .appInfo, locale: locale, version: nil)
        let versionInfo = version.flatMap {
            try? tree.localization(scope: .version, locale: locale, version: $0)
        }
        listing = StoreListing(locale: locale, appInfo: appInfo, version: versionInfo)

        if appInfo == nil, versionInfo == nil {
            listingNote = "No metadata at \(root.path) yet. `lutin store pull` fills it."
        } else if appInfo == nil {
            listingNote = "No app-info/\(locale).json in the tree."
        } else if versions.count > 1 {
            listingNote = "\(versions.count) versions in the tree — the preview shows app-info only."
        } else {
            listingNote = nil
        }

        assets = StoreAssets.forApp(at: root.deletingLastPathComponent()
            .appendingPathComponent(document.config.app.path))
    }
}

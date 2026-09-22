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
    public private(set) var app: StoreSectionState<StoreAppModel> = .loading
    public private(set) var versions: StoreSectionState<StoreVersionsModel> = .loading
    public private(set) var validation: StoreSectionState<StoreValidationModel> = .loading
    public private(set) var review: StoreSectionState<StoreReviewModel> = .loading
    /// Whether asc's plan artifact exists. `false` with a loaded (empty) model
    /// is the "no plan yet" state — distinct from a plan with no changes.
    public private(set) var hasReviewPlan = false
    public var reviewerNote: String = ""
    public private(set) var isConfirmingApply = false
    public private(set) var isBusy = false
    public private(set) var applyResult: String?
    public private(set) var applyFailure: StoreFailure?
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
    /// The `asc`-resolution seam, threaded through to every engine call. The
    /// default is the real check; a test injects `{ _ in false }` so a machine
    /// with asc installed in `/opt/homebrew` cannot be reached by accident.
    private let isExecutable: (String) -> Bool

    public init(runner: CommandRunning = ShellCommandRunner(),
                isExecutable: @escaping (String) -> Bool = {
                    FileManager.default.isExecutableFile(atPath: $0)
                }) {
        self.runner = runner
        self.isExecutable = isExecutable
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
            status = try StoreLogic.status(configURL: document.configURL, runner: runner,
                                           isExecutable: isExecutable)
        } catch let error as LutinError {
            failure = error
        } catch {
            failure = LutinError(code: "store_asc_failed", message: "\(error)")
        }
        connection = StoreConnectionSnapshot.make(status: status, error: failure, isOnline: isOnline)

        // Each section loads in its own do/catch: one failure must never blank
        // the others (§7 — every section degrades to an explanation, alone).
        do {
            let resolved = try StoreLogic.app(configURL: document.configURL, runner: runner,
                                              isExecutable: isExecutable)
            app = .loaded(StoreAppModel.make(app: resolved, appID: document.config.store?.appID,
                                             bundleID: document.config.store?.bundleID,
                                             platform: document.config.store?.resolvedPlatform
                                                ?? StoreInfo.defaultPlatform))
        } catch let error as LutinError {
            app = .failed(StoreFailure(error))
        } catch {
            app = .failed(StoreFailure(code: "store_asc_failed", message: "\(error)"))
        }

        do {
            let list = try StoreLogic.versions(configURL: document.configURL, runner: runner,
                                               isExecutable: isExecutable)
            versions = .loaded(StoreVersionsModel.make(
                versions: list,
                platform: document.config.store?.resolvedPlatform ?? StoreInfo.defaultPlatform))
        } catch let error as LutinError {
            versions = .failed(StoreFailure(error))
        } catch {
            versions = .failed(StoreFailure(code: "store_asc_failed", message: "\(error)"))
        }

        do {
            let report = try StoreLogic.validate(configURL: document.configURL, runner: runner,
                                                 isExecutable: isExecutable)
            validation = .loaded(StoreValidationModel.make(report: report))
        } catch let error as LutinError {
            validation = .failed(StoreFailure(error))
        } catch {
            validation = .failed(StoreFailure(code: "store_asc_failed", message: "\(error)"))
        }

        loadReview(document: document)
        loadListing(document: document)
    }

    // MARK: - Review (§7.6–7.7)

    /// Reads asc's plan, status and approval artifacts. A malformed plan is a
    /// failed section; an unavailable status is not — the changes still
    /// render, and the Apply section says the approval state is unavailable
    /// rather than guessing (§7.7).
    public func loadReview(document: LutinProjectDocument) {
        do {
            guard let plan = try StoreLogic.reviewPlan(configURL: document.configURL,
                                                       runner: runner) else {
                hasReviewPlan = false
                review = .loaded(.empty)
                return
            }
            hasReviewPlan = true
            // Both reads are best-effort: asc's status is the only source of
            // approval facts, and its absence is reported, never inferred.
            let status = try? StoreLogic.reviewStatus(configURL: document.configURL,
                                                      runner: runner,
                                                      isExecutable: isExecutable)
            let approval = try? StoreLogic.reviewApproval(configURL: document.configURL,
                                                          runner: runner)
            review = .loaded(StoreReviewModel.make(plan: plan, status: status,
                                                   approval: approval))
        } catch let error as LutinError {
            hasReviewPlan = true
            review = .failed(StoreFailure(error))
        } catch {
            hasReviewPlan = true
            review = .failed(StoreFailure(code: "store_asc_failed", message: "\(error)"))
        }
    }

    /// Runs asc's plan (a local artifact write — no remote mutation) and
    /// reloads. `Run plan` exists so the section can produce the artifact, not
    /// merely display one made in the CLI.
    public func runPlan(document: LutinProjectDocument) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try StoreLogic.plan(configURL: document.configURL, reviewDir: nil,
                                    runner: runner, isExecutable: isExecutable)
            applyFailure = nil
            applyResult = nil
            loadReview(document: document)
        } catch let error as LutinError {
            review = .failed(StoreFailure(error))
        } catch {
            review = .failed(StoreFailure(code: "store_asc_failed", message: "\(error)"))
        }
    }

    /// Approves through asc (`--key` / `--scope` / `--all`) with the reviewer
    /// note, then reloads asc's status. A failure surfaces its fix and leaves
    /// the loaded plan alone.
    public func approve(document: LutinProjectDocument, all: Bool = false,
                        keys: [String] = [], scope: String? = nil) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try StoreLogic.approve(
                configURL: document.configURL, reviewDir: nil, all: all, keys: keys,
                scope: scope, note: reviewerNote.isEmpty ? nil : reviewerNote,
                runner: runner, isExecutable: isExecutable)
            applyFailure = nil
            loadReview(document: document)
        } catch let error as LutinError {
            applyFailure = StoreFailure(error)
        } catch {
            applyFailure = StoreFailure(code: "store_asc_failed", message: "\(error)")
        }
    }

    /// Arms the confirmation gate. The remote write happens only in
    /// `confirmApply` — the confirm is the UI's, the `--confirm` flag is asc's.
    public func beginApply() { isConfirmingApply = true }

    public func cancelApply() { isConfirmingApply = false }

    /// The only remote writer: `StoreLogic.apply(..., confirmed: true)`, then
    /// asc's status is re-read.
    public func confirmApply(document: LutinProjectDocument) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        isConfirmingApply = false
        do {
            let result = try StoreLogic.apply(configURL: document.configURL, reviewDir: nil,
                                              confirmed: true, runner: runner,
                                              isExecutable: isExecutable)
            let trimmed = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            applyResult = trimmed.isEmpty ? "asc applied the approved plan." : trimmed
            applyFailure = nil
            loadReview(document: document)
        } catch let error as LutinError {
            applyFailure = StoreFailure(error)
        } catch {
            applyFailure = StoreFailure(code: "store_asc_failed", message: "\(error)")
        }
    }

    /// Reads `app-info/<locale>.json` and the single `version/<v>/<locale>.json`
    /// if the tree has them. Anything absent stays absent — the preview renders
    /// gaps explicitly, so an incomplete listing is information, not an error.
    private func loadListing(document: LutinProjectDocument) {
        let store = document.config.store
        let projectDir = document.projectDirectory
        let root = Self.resolve(store?.resolvedMetadataDir ?? StoreInfo.defaultMetadataDir,
                                in: projectDir)
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

        // Only a real bundle gets an icon: `NSWorkspace` hands back a generic
        // document glyph for a path that isn't there, which reads as "your app
        // is a text file" rather than as "no app built yet".
        let appURL = Self.resolve(document.config.app.path, in: projectDir)
        assets = FileManager.default.fileExists(atPath: appURL.path)
            ? StoreAssets.forApp(at: appURL)
            : StoreAssets()
    }

    /// `store.metadataDir` and `app.path` are documented relative to the config
    /// file; an absolute path is honoured as-is, matching the CLI.
    static func resolve(_ path: String, in base: URL) -> URL {
        path.hasPrefix("/") ? URL(fileURLWithPath: path) : base.appendingPathComponent(path)
    }
}

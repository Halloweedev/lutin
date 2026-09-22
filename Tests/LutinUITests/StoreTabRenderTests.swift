import AppKit
import SwiftUI
import XCTest
import LutinCore
import LutinDocument
import LutinStoreConnect
import TestSupport
@testable import LutinUI

/// What the Store tab actually looks like, rendered offscreen.
///
/// The runner is injected and fake, so this can never reach a real `asc`.
/// Set `LUTIN_PREVIEW_DUMP=1` to write the render to `/tmp` for eyeballing.
@MainActor
final class StoreTabRenderTests: XCTestCase {

    /// A project with a pinned app, so the App section resolves instead of
    /// degrading — the render should show the section working, not failing.
    private func makeConfiguredDocument() throws -> LutinProjectDocument {
        let dir = try Fixtures.makeTempDirectory()
        let yaml = """
        project:
          name: Sayrise
          bundleId: com.example.sayrise
        app:
          path: ./build/Sayrise.app
        output:
          directory: ./release
          dmgName: Sayrise-${version}.dmg
          volumeName: Sayrise
        store:
          appID: "1234567890"
          bundleID: com.example.sayrise
          metadataDir: store/metadata
        """
        let url = dir.appendingPathComponent("lutin.yml")
        try Data(yaml.utf8).write(to: url)
        return try LutinProjectDocument(configURL: url)
    }

    private static let fakeAsc = "/fake/asc"

    /// One refresh runs several asc commands through one executable, so the
    /// Catalog responses are stubbed by argument fragment. `isExecutable` is
    /// pinned to the fake: a machine with a real asc in `/opt/homebrew` must
    /// never be reached, and the locator's known paths are checked for real.
    private func catalogState() throws -> StoreTabState {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 0, stdout: "\(Self.fakeAsc)\n", stderr: ""))
        fake.stub(executable: Self.fakeAsc, argumentsContaining: "apps",
                  result: ShellResult(exitCode: 0,
                                      stdout: #"{"type":"apps","id":"1234567890","attributes":{"name":"Sayrise","bundleId":"com.example.sayrise","sku":"SAYRISE","primaryLocale":"en-US"}}"#,
                                      stderr: ""))
        fake.stub(executable: Self.fakeAsc, argumentsContaining: "versions",
                  result: ShellResult(exitCode: 0,
                                      stdout: #"{"data":[{"type":"appStoreVersions","id":"1","attributes":{"platform":"MAC_OS","versionString":"1.2.3","appStoreState":"READY_FOR_SALE","createdDate":"2026-01-01T00:00:00Z","releaseType":"AFTER_APPROVAL"}},{"type":"appStoreVersions","id":"2","attributes":{"platform":"MAC_OS","versionString":"1.3.0","appStoreState":"","appVersionState":"IN_REVIEW","createdDate":"2026-02-01T00:00:00Z","releaseType":"MANUAL"}}]}"#,
                                      stderr: ""))
        return StoreTabState(runner: fake, isExecutable: { $0 == Self.fakeAsc },
                             cache: throwawayCache())
    }

    /// The real cache lives in `~/Library`; no test may read or write it.
    private func throwawayCache() -> ASCCapabilitiesCache {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lutin-asc-cache-\(UUID().uuidString).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return ASCCapabilitiesCache(url: url, ttl: 3600)
    }

    private func makeDocument() throws -> LutinProjectDocument {
        let dir = try Fixtures.makeTempDirectory()
        let yaml = """
        project:
          name: Sayrise
          bundleId: com.example.sayrise
        app:
          path: ./build/Sayrise.app
        output:
          directory: ./release
          dmgName: Sayrise-${version}.dmg
          volumeName: Sayrise
        store:
          metadataDir: store/metadata
        """
        let url = dir.appendingPathComponent("lutin.yml")
        try Data(yaml.utf8).write(to: url)
        return try LutinProjectDocument(configURL: url)
    }

    /// The whole surface as the shell composes it: column on the left, the
    /// product page on the canvas.
    @MainActor
    func testTheTabAndItsCanvasRender() async throws {
        let document = try makeConfiguredDocument()
        let state = try catalogState()
        await state.refresh(document: document)
        // The App section must be *shown working* here — a resolved row set,
        // not the loading placeholder over a failure banner.
        guard case .loaded = state.app else {
            return XCTFail("the App section should be loaded in the tab render, got \(state.app)")
        }

        let surface = HStack(spacing: 0) {
            StoreTab(document: document, state: state)
                .frame(width: 430)
            StoreCanvas(state: state)
        }
        let rep = snapshotPNG(surface, size: CGSize(width: 1100, height: 720),
                              dumpName: "lutin-storetab")
        XCTAssertGreaterThan(sampledColors(rep).count, 4,
                             "the tab must paint the column and the page, not a flat rectangle")
    }

    /// The shell's composition at a narrow window: rail + column + canvas.
    /// The Store surface must fit — a minimum wider than the window clips the
    /// rail and the panel, which is what a user sees as a "wrongly designed
    /// sidebar".
    @MainActor
    func testTheSurfaceFitsANarrowWindow() async throws {
        let document = try makeConfiguredDocument()
        let state = try catalogState()
        await state.refresh(document: document)

        let surface = HStack(spacing: 0) {
            EditorRail(selectedTab: .constant(.store))
            StoreTab(document: document, state: state)
                .frame(width: 430)
            StoreCanvas(state: state)
        }
        let rep = snapshotPNG(surface, size: CGSize(width: 850, height: 900),
                              dumpName: "lutin-storetab-narrow")
        XCTAssertGreaterThan(sampledColors(rep).count, 4)
    }

    /// A tree with a real listing: the preview should show the values, and the
    /// missing ones as slots.
    @MainActor
    func testTheCanvasRendersAListingFromTheTree() async throws {
        let document = try makeDocument()
        let tree = document.projectDirectory.appendingPathComponent("store/metadata")
        try FileManager.default.createDirectory(at: tree.appendingPathComponent("app-info"),
                                                withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tree.appendingPathComponent("version/1.2.3"),
                                                withIntermediateDirectories: true)
        try Data(#"{"name":"Sayrise","subtitle":"Ship your app"}"#.utf8)
            .write(to: tree.appendingPathComponent("app-info/en-US.json"))
        try Data(#"{"description":"A description of the app.","whatsNew":"First release."}"#.utf8)
            .write(to: tree.appendingPathComponent("version/1.2.3/en-US.json"))

        // `isExecutable` is pinned so the real `/opt/homebrew/bin/asc` cannot be
        // resolved, and the cache is a throwaway file: this test renders the
        // metadata tree it wrote, and must not depend on the developer's machine.
        let state = StoreTabState(runner: FakeCommandRunner(),
                                  isExecutable: { _ in false },
                                  cache: throwawayCache())
        await state.refresh(document: document)

        XCTAssertEqual(state.listing.name, "Sayrise", "the canvas reads the tree it was pointed at")
        XCTAssertEqual(state.availableLocales, ["en-US"])
        XCTAssertNil(state.listingNote)

        let rep = snapshotPNG(StoreCanvas(state: state), size: CGSize(width: 900, height: 720),
                              dumpName: "lutin-storecanvas-listing")
        XCTAssertGreaterThan(sampledColors(rep).count, 4)
    }
}

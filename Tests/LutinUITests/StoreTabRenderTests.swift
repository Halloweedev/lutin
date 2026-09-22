import AppKit
import SwiftUI
import XCTest
import LutinCore
import LutinDocument
import TestSupport
@testable import LutinUI

/// What the Store tab actually looks like, rendered offscreen.
///
/// The runner is injected and fake, so this can never reach a real `asc`.
/// Set `LUTIN_PREVIEW_DUMP=1` to write the render to `/tmp` for eyeballing.
final class StoreTabRenderTests: XCTestCase {

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

    private func snapshot<V: View>(_ view: V, size: CGSize, name: String) -> NSBitmapImageRep {
        let host = NSHostingView(rootView: view)
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
            try? rep.representation(using: .png, properties: [:])?
                .write(to: URL(fileURLWithPath: "/tmp/\(name).png"))
        }
        return rep
    }

    private func distinctColours(_ rep: NSBitmapImageRep) -> Int {
        var seen = Set<UInt32>()
        for x in stride(from: 0, to: rep.pixelsWide, by: 7) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: 7) {
                guard let c = rep.colorAt(x: x, y: y) else { continue }
                seen.insert((UInt32(c.redComponent * 255) << 16)
                    | (UInt32(c.greenComponent * 255) << 8)
                    | UInt32(c.blueComponent * 255))
            }
        }
        return seen.count
    }

    /// The whole surface as the shell composes it: column on the left, the
    /// product page on the canvas.
    @MainActor
    func testTheTabAndItsCanvasRender() async throws {
        let document = try makeDocument()
        let state = StoreTabState(runner: FakeCommandRunner())
        await state.refresh(document: document)

        let surface = HStack(spacing: 0) {
            StoreTab(document: document, state: state)
                .frame(width: 430)
            StoreCanvas(state: state)
        }
        let rep = snapshot(surface, size: CGSize(width: 1100, height: 720), name: "lutin-storetab")
        XCTAssertGreaterThan(distinctColours(rep), 4,
                             "the tab must paint the column and the page, not a flat rectangle")
    }

    /// The shell's composition at a narrow window: rail + column + canvas.
    /// The Store surface must fit — a minimum wider than the window clips the
    /// rail and the panel, which is what a user sees as a "wrongly designed
    /// sidebar".
    @MainActor
    func testTheSurfaceFitsANarrowWindow() async throws {
        let document = try makeDocument()
        let state = StoreTabState(runner: FakeCommandRunner())
        await state.refresh(document: document)

        let surface = HStack(spacing: 0) {
            EditorRail(selectedTab: .constant(.store))
            StoreTab(document: document, state: state)
                .frame(width: 430)
            StoreCanvas(state: state)
        }
        let rep = snapshot(surface, size: CGSize(width: 850, height: 900), name: "lutin-storetab-narrow")
        XCTAssertGreaterThan(distinctColours(rep), 4)
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

        let state = StoreTabState(runner: FakeCommandRunner())
        await state.refresh(document: document)

        XCTAssertEqual(state.listing.name, "Sayrise", "the canvas reads the tree it was pointed at")
        XCTAssertEqual(state.availableLocales, ["en-US"])
        XCTAssertNil(state.listingNote)

        let rep = snapshot(StoreCanvas(state: state), size: CGSize(width: 900, height: 720),
                           name: "lutin-storecanvas-listing")
        XCTAssertGreaterThan(distinctColours(rep), 4)
    }
}

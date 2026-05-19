import XCTest
import CoreGraphics
import ImageIO
import TestSupport
import LutinCore
import LutinConfig
import LutinBuilder
@testable import LutinRelease

final class RenderedBackgroundTests: XCTestCase {
    func testGeneratedBackgroundProducesADmgWithARenderedBackground() throws {
        let fm = FileManager.default
        // A project dir with ONLY the app — no assets/background.png — so a
        // background on the DMG can only come from the renderer.
        let projectDir = try Fixtures.makeTempDirectory()
        defer { try? fm.removeItem(at: projectDir) }
        try fm.copyItem(at: Fixtures.barryApp,
                        to: projectDir.appendingPathComponent("Barry.app"))
        let outDir = try Fixtures.makeTempDirectory()
        defer { try? fm.removeItem(at: outDir) }

        let config = LutinConfig(
            project: .init(name: "Barry", bundleId: "com.anotheragence.barry"),
            app: .init(path: "./Barry.app"),
            output: .init(directory: outDir.path, dmgName: "Barry.dmg", volumeName: "Barry"),
            window: .init(width: 680, height: 420, iconSize: 96, textSize: 13,
                          showToolbar: false, showSidebar: false),
            background: .init(type: "generated", template: "blueprint", path: nil,
                              scale: 2, colorA: "#EEF4FF", colorB: "#DDE8FF",
                              grid: true, noise: 0.03, cornerRadius: 24),
            items: [.init(type: "app", id: "app", x: 180, y: 220, label: "Barry"),
                    .init(type: "applications", id: "applications", x: 500, y: 220, label: nil)],
            decorations: [.init(type: "arrow", from: "app", to: "applications",
                                label: "Drag to install")],
            signing: nil, notarization: nil, sparkle: nil)

        // Ensure the URL is flagged as a directory so that relative paths like
        // "./Barry.app" inside the pipeline resolve correctly via Foundation's
        // URL(fileURLWithPath:relativeTo:) API.
        let projectDirURL = URL(fileURLWithPath: projectDir.path, isDirectory: true)
        let result = try ReleasePipeline.run(
            config: config, projectDirectory: projectDirURL,
            mode: .build, runner: ShellCommandRunner())

        let mount = try DiskImage.mount(result.dmgPath, runner: ShellCommandRunner())
        defer { try? DiskImage.unmount(mount, runner: ShellCommandRunner()) }
        let bg = mount.mountPoint.appendingPathComponent(".background/background.png")
        XCTAssertTrue(fm.fileExists(atPath: bg.path),
                      "the renderer must have produced a background")
        let src = CGImageSourceCreateWithURL(bg as CFURL, nil)
        let image = src.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
        XCTAssertEqual(image?.width, 1360)   // 680 * scale 2
        XCTAssertEqual(image?.height, 840)   // 420 * scale 2
    }
}

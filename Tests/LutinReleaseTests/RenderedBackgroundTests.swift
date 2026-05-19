import XCTest
import TestSupport
import LutinCore
import LutinConfig
import LutinBuilder
@testable import LutinRelease

final class RenderedBackgroundTests: XCTestCase {
    func testGeneratedBackgroundProducesADmgWithARenderedBackground() throws {
        let projectDir = Fixtures.barryProject
        let outDir = try Fixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: outDir) }

        var config = LutinConfig(
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
        config.output.directory = outDir.path

        let result = try ReleasePipeline.run(
            config: config, projectDirectory: projectDir,
            mode: .build, runner: ShellCommandRunner())

        let mount = try DiskImage.mount(result.dmgPath, runner: ShellCommandRunner())
        defer { try? DiskImage.unmount(mount, runner: ShellCommandRunner()) }
        let bg = mount.mountPoint.appendingPathComponent(".background/background.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: bg.path))
    }
}

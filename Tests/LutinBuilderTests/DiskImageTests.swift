import XCTest
import TestSupport
import LutinCore
@testable import LutinBuilder

final class DiskImageTests: XCTestCase {
    func testCreateMountWriteUnmountConvertRoundTrip() throws {
        let dir = try Fixtures.makeTempDirectory()
        let rwDMG = dir.appendingPathComponent("work.dmg")
        let finalDMG = dir.appendingPathComponent("final.dmg")
        let runner = ShellCommandRunner()

        // Create a 10 MB writable image.
        try DiskImage.createWritable(at: rwDMG, volumeName: "LutinTest",
                                     megabytes: 10, runner: runner)
        XCTAssertTrue(FileManager.default.fileExists(atPath: rwDMG.path))

        // Mount it; write a file; unmount.
        let mount = try DiskImage.mount(rwDMG, runner: runner)
        addTeardownBlock { try? DiskImage.unmount(mount, runner: runner) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: mount.mountPoint.path))
        try "hello".write(to: mount.mountPoint.appendingPathComponent("note.txt"),
                          atomically: true, encoding: .utf8)
        try DiskImage.unmount(mount, runner: runner)

        // Convert to compressed read-only.
        try DiskImage.convertToCompressed(source: rwDMG, destination: finalDMG, runner: runner)
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalDMG.path))

        // The converted image still mounts and contains the file.
        let remount = try DiskImage.mount(finalDMG, runner: runner)
        addTeardownBlock { try? DiskImage.unmount(remount, runner: runner) }
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: remount.mountPoint.appendingPathComponent("note.txt").path))
        try DiskImage.unmount(remount, runner: runner)
    }
}

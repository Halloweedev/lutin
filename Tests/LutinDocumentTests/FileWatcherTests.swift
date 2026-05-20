import XCTest
import TestSupport
@testable import LutinDocument

final class FileWatcherTests: XCTestCase {
    func testFiresOnExternalChange() throws {
        let dir = try Fixtures.makeTempDirectory()
        let file = dir.appendingPathComponent("lutin.yml")
        try "first".write(to: file, atomically: true, encoding: .utf8)

        let expectation = expectation(description: "watcher fires")
        let watcher = FileWatcher(fileURL: file) {
            expectation.fulfill()
        }
        try watcher.start()
        defer { watcher.stop() }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            try? "second".write(to: file, atomically: true, encoding: .utf8)
        }
        wait(for: [expectation], timeout: 5.0)
    }

    func testSuppressedWritesDoNotFire() throws {
        let dir = try Fixtures.makeTempDirectory()
        let file = dir.appendingPathComponent("lutin.yml")
        try "first".write(to: file, atomically: true, encoding: .utf8)

        let watcher = FileWatcher(fileURL: file) {
            XCTFail("watcher should be suppressed")
        }
        try watcher.start()
        defer { watcher.stop() }

        watcher.suppressNextChange(for: 1.0)
        try "second".write(to: file, atomically: true, encoding: .utf8)

        let exp = expectation(description: "no fire window")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
    }
}

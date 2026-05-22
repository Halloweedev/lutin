import XCTest
@testable import LutinUI
import LutinRegistry

final class ProjectSwitcherFilterTests: XCTestCase {
    private func entry(name: String, path: String) -> RegistryEntry {
        RegistryEntry(
            name: name,
            configPath: path,
            appPath: "",
            lastDetectedVersion: nil,
            lastReleaseStatus: nil,
            createdDate: Date(),
            lastOpenedDate: Date()
        )
    }

    func testEmptyQueryReturnsAll() {
        let entries = [entry(name: "Barry", path: "/p1/lutin.yml"),
                       entry(name: "Lutin", path: "/p2/lutin.yml")]
        XCTAssertEqual(ProjectSwitcherFilter.filter(entries, query: "").count, 2)
    }

    func testNameMatch() {
        let entries = [entry(name: "Barry", path: "/p1/lutin.yml"),
                       entry(name: "Lutin", path: "/p2/lutin.yml")]
        let r = ProjectSwitcherFilter.filter(entries, query: "barr")
        XCTAssertEqual(r.map(\.name), ["Barry"])
    }

    func testPathMatch() {
        let entries = [entry(name: "Barry", path: "/Coding/p1/lutin.yml"),
                       entry(name: "Lutin", path: "/Other/p2/lutin.yml")]
        let r = ProjectSwitcherFilter.filter(entries, query: "coding")
        XCTAssertEqual(r.map(\.name), ["Barry"])
    }

    func testCaseInsensitive() {
        let entries = [entry(name: "Barry", path: "/p1/lutin.yml")]
        XCTAssertEqual(ProjectSwitcherFilter.filter(entries, query: "BARRY").count, 1)
    }
}

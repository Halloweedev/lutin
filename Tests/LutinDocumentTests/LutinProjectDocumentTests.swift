import XCTest
import LutinCore
import LutinConfig
import TestSupport
@testable import LutinDocument

final class LutinProjectDocumentTests: XCTestCase {
    func testLoadsBarryConfig() throws {
        let doc = try LutinProjectDocument(configURL: Fixtures.barryConfig)
        XCTAssertEqual(doc.config.project.name, "Barry")
        XCTAssertEqual(doc.projectDirectory, Fixtures.barryProject.standardizedFileURL)
        XCTAssertFalse(doc.isDirty)
    }

    func testThrowsOnMissingFile() {
        let missing = URL(fileURLWithPath: "/nonexistent/lutin.yml")
        XCTAssertThrowsError(try LutinProjectDocument(configURL: missing)) { error in
            XCTAssertTrue(error is LutinError)
        }
    }
}

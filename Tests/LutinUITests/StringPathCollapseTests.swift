import XCTest
@testable import LutinUI

final class StringPathCollapseTests: XCTestCase {
    func testCollapsesHomePrefix() {
        let home = NSHomeDirectory()
        let input = "\(home)/Coding/Projects/Luce/lutin.yml"
        XCTAssertEqual(input.collapsedHome, "~/Coding/Projects/Luce/lutin.yml")
    }

    func testLeavesNonHomePathUntouched() {
        XCTAssertEqual("/Applications/Luce.app".collapsedHome,
                       "/Applications/Luce.app")
    }

    func testLeavesEmptyStringUntouched() {
        XCTAssertEqual("".collapsedHome, "")
    }

    func testLeavesUnrelatedPathUntouched() {
        // A path that happens to start with the user-name substring but
        // not the home dir itself should not be collapsed.
        XCTAssertEqual("/tmp/build.yml".collapsedHome, "/tmp/build.yml")
    }

    func testCollapsesExactHomeDir() {
        XCTAssertEqual(NSHomeDirectory().collapsedHome, "~")
    }
}

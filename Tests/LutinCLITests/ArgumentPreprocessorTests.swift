import XCTest
@testable import LutinCLI

final class ArgumentPreprocessorTests: XCTestCase {
    func testRewritesProjectNameForm() {
        // `lutin Barry build` → `lutin build --name Barry`
        let out = ArgumentPreprocessor.rewrite(["Barry", "build"])
        XCTAssertEqual(out, ["build", "--name", "Barry"])
    }

    func testLeavesPlainSubcommandUntouched() {
        XCTAssertEqual(ArgumentPreprocessor.rewrite(["build"]), ["build"])
        XCTAssertEqual(ArgumentPreprocessor.rewrite(["projects"]), ["projects"])
    }

    func testLeavesSubcommandWithFlagsUntouched() {
        let args = ["build", "--config", "./lutin.yml", "--json"]
        XCTAssertEqual(ArgumentPreprocessor.rewrite(args), args)
    }

    func testEmptyArgsUntouched() {
        XCTAssertEqual(ArgumentPreprocessor.rewrite([]), [])
    }
}

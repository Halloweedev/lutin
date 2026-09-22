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

    func testRewritesProjectNameWithValidate() {
        // `lutin Barry validate` → `lutin validate --name Barry`
        XCTAssertEqual(ArgumentPreprocessor.rewrite(["Barry", "validate"]),
                       ["validate", "--name", "Barry"])
    }

    func testLeavesStoreSubcommandsUntouched() {
        // Regression: `store` is a real top-level subcommand, so `store validate`
        // must not be rewritten into the config validator with `--name store`.
        let validate = ["store", "validate", "--config", "./lutin.yml", "--json"]
        XCTAssertEqual(ArgumentPreprocessor.rewrite(validate), validate)
        XCTAssertEqual(ArgumentPreprocessor.rewrite(["store", "status"]), ["store", "status"])
    }

    func testLeavesOtherTopLevelSubcommandsUntouched() {
        let appStore = ["app-store", "upload"]
        XCTAssertEqual(ArgumentPreprocessor.rewrite(appStore), appStore)
        let notary = ["notary", "setup"]
        XCTAssertEqual(ArgumentPreprocessor.rewrite(notary), notary)
        let applyIntents = ["apply-intents"]
        XCTAssertEqual(ArgumentPreprocessor.rewrite(applyIntents), applyIntents)
    }
}

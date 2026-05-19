import XCTest
import TestSupport
import LutinCore
@testable import LutinSigning

final class SignDmgTests: XCTestCase {
    func testSignDmgInvokesCodesignOnTheDmg() throws {
        let fake = FakeCommandRunner()
        try CodeSigner.signDMG(URL(fileURLWithPath: "/tmp/Barry.dmg"),
                               identity: "ID", runner: fake)
        let call = fake.invocations.last { $0.executable.hasSuffix("codesign") }!
        XCTAssertTrue(call.arguments.contains("/tmp/Barry.dmg"))
        XCTAssertTrue(call.arguments.contains("ID"))
    }

    func testVerifyIdentityExistsThrowsWhenAbsent() {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/security",
                  result: ShellResult(exitCode: 0, stdout: "  0 valid identities found",
                                       stderr: ""))
        XCTAssertThrowsError(try CodeSigner.verifyIdentityExists(
            "Developer ID Application: Nobody", runner: fake)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "identity_not_found")
        }
    }

    func testVerifyIdentityExistsPassesWhenPresent() throws {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/security",
                  result: ShellResult(exitCode: 0,
                    stdout: "  1) ABCD \"Developer ID Application: Acme (TEAM)\"\n     1 valid identities found",
                    stderr: ""))
        try CodeSigner.verifyIdentityExists("Developer ID Application: Acme (TEAM)",
                                            runner: fake)
    }
}

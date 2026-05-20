import XCTest
import LutinCore
@testable import LutinDocument

final class PipelineRunnerTests: XCTestCase {
    func testStateStartsIdle() {
        let runner = PipelineRunner()
        XCTAssertEqual(runner.state, .idle)
        XCTAssertTrue(runner.log.isEmpty)
    }

    func testLogRingBufferTrimsToCap() {
        let runner = PipelineRunner(logCapacity: 3)
        runner.append(.init(kind: .stdout, text: "a"))
        runner.append(.init(kind: .stdout, text: "b"))
        runner.append(.init(kind: .stdout, text: "c"))
        runner.append(.init(kind: .stdout, text: "d"))
        XCTAssertEqual(runner.log.map(\.text), ["b", "c", "d"])
    }

    func testFailureStateCarriesLutinError() {
        let runner = PipelineRunner()
        runner.fail(LutinError(code: "render_failed", message: "boom"))
        if case .failed(let error) = runner.state {
            XCTAssertEqual(error.code, "render_failed")
        } else { XCTFail("expected .failed") }
    }
}

import XCTest
@testable import LutinAppPackagerCore

final class FrameworkEmbedderTests: XCTestCase {
    func testExtractsRpathFrameworkNames() {
        let otool = """
        /path/to/lutin-app:
        \t@rpath/KeylightSDK.framework/Versions/A/KeylightSDK (compatibility version 0.0.0, current version 0.0.0)
        \t/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit (compatibility version 45.0.0, current version 2685.30.107)
        \t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1351.0.0)
        """
        XCTAssertEqual(
            FrameworkEmbedder.rpathFrameworkNames(fromOtoolOutput: otool),
            ["KeylightSDK"])
    }

    func testIgnoresSystemAndDylibDependencies() {
        let otool = """
        /path/to/cli:
        \t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1351.0.0)
        \t/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation (compatibility version 300.0.0, current version 4201.0.0)
        """
        XCTAssertTrue(
            FrameworkEmbedder.rpathFrameworkNames(fromOtoolOutput: otool).isEmpty)
    }

    func testDeduplicatesRepeatedFrameworks() {
        let otool = """
        \t@rpath/Foo.framework/Versions/A/Foo (compatibility version 1.0.0, current version 1.0.0)
        \t@rpath/Foo.framework/Foo (compatibility version 1.0.0, current version 1.0.0)
        \t@rpath/Bar.framework/Versions/A/Bar (compatibility version 1.0.0, current version 1.0.0)
        """
        XCTAssertEqual(
            FrameworkEmbedder.rpathFrameworkNames(fromOtoolOutput: otool),
            ["Foo", "Bar"])
    }
}

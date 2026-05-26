import XCTest
@testable import LutinLicense

final class LicenseGateTests: XCTestCase {
    // MARK: - canCreateProject

    func testFreeUserCanCreateUpToCapMinusOne() {
        XCTAssertTrue(LicenseGate.canCreateProject(projectCount: 0, isEntitled: false))
        XCTAssertTrue(LicenseGate.canCreateProject(projectCount: 9, isEntitled: false))
    }

    func testFreeUserBlockedAtCap() {
        XCTAssertFalse(LicenseGate.canCreateProject(projectCount: 10, isEntitled: false))
        XCTAssertFalse(LicenseGate.canCreateProject(projectCount: 99, isEntitled: false))
    }

    func testProUserNeverBlocked() {
        XCTAssertTrue(LicenseGate.canCreateProject(projectCount: 10, isEntitled: true))
        XCTAssertTrue(LicenseGate.canCreateProject(projectCount: 9_999, isEntitled: true))
    }

    // MARK: - shouldShowSupportNag

    func testNagShownOnFirstLaunch() {
        XCTAssertTrue(LicenseGate.shouldShowSupportNag(lastShown: nil, isEntitled: false))
    }

    func testNagSuppressedWithinInterval() {
        let now = Date()
        let recent = now.addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
        XCTAssertFalse(LicenseGate.shouldShowSupportNag(
            lastShown: recent, isEntitled: false, now: now))
    }

    func testNagShownAfterInterval() {
        let now = Date()
        let old = now.addingTimeInterval(-(LicenseGate.supportNagInterval + 60))
        XCTAssertTrue(LicenseGate.shouldShowSupportNag(
            lastShown: old, isEntitled: false, now: now))
    }

    func testProUserNeverSeesNag() {
        XCTAssertFalse(LicenseGate.shouldShowSupportNag(lastShown: nil, isEntitled: true))
        let old = Date().addingTimeInterval(-365 * 24 * 60 * 60)
        XCTAssertFalse(LicenseGate.shouldShowSupportNag(lastShown: old, isEntitled: true))
    }
}

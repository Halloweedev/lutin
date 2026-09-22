import AppKit
import SwiftUI
import XCTest
import LutinStoreConnect
import LutinStoreMetadata
@testable import LutinUI

/// §8's rule for this surface: a render test per Store-surface change, and
/// then actually look at the PNG. `LUTIN_PREVIEW_DUMP=1` writes them to /tmp.
@MainActor
final class StoreSectionsRenderTests: XCTestCase {

    /// The column's real width, from the audit (the panel is ~430 pt).
    static let panelWidth: CGFloat = 430

    private func snapshot<V: View>(_ view: V, height: CGFloat = 720,
                                   name: String) -> NSBitmapImageRep {
        let host = NSHostingView(rootView: view.frame(width: Self.panelWidth, height: height))
        host.frame = CGRect(x: 0, y: 0, width: Self.panelWidth, height: height)
        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: rep)
        if ProcessInfo.processInfo.environment["LUTIN_PREVIEW_DUMP"] == "1" {
            try? rep.representation(using: .png, properties: [:])?
                .write(to: URL(fileURLWithPath: "/tmp/lutin-store-\(name).png"))
        }
        return rep
    }

    private func distinctColors(_ rep: NSBitmapImageRep) -> Set<UInt32> {
        var seen = Set<UInt32>()
        for x in stride(from: 0, to: rep.pixelsWide, by: 7) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: 7) {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                seen.insert((UInt32(color.redComponent * 255) << 16)
                    | (UInt32(color.greenComponent * 255) << 8)
                    | UInt32(color.blueComponent * 255))
            }
        }
        return seen
    }

    private func report(_ issues: [StoreMetadataIssue], offline: Bool = false,
                        fileCount: Int = 4) -> StoreLogic.StoreValidateReport {
        StoreLogic.StoreValidateReport(
            fileCount: fileCount, issues: issues, offline: offline,
            errorCount: issues.filter(\.isError).count,
            warningCount: issues.filter { !$0.isError }.count,
            valid: !issues.contains(where: \.isError))
    }

    private func section(_ state: StoreSectionState<StoreValidationModel>) -> some View {
        TabBody {
            StoreValidationSection(state: state, onRecheck: {})
        }
    }

    /// An error and a warning, in two scopes and two locales: the section must
    /// paint both, plus the two scope headers and the status line.
    func testLoadedValidationWithAnErrorAndAWarningPaints() {
        let model = StoreValidationModel.make(report: report([
            StoreMetadataIssue(scope: "app-info", locale: "en-US", field: "name",
                               severity: "error",
                               message: "name is 41 characters; the limit is 30",
                               length: 41, limit: 30),
            StoreMetadataIssue(scope: "version", locale: "fr-FR", field: "description",
                               severity: "warning",
                               message: "description is shorter than the 10 characters "
                                      + "App Store Connect recommends"),
        ]))
        let rep = snapshot(section(.loaded(model)), name: "validation")
        XCTAssertGreaterThan(distinctColors(rep).count, 4,
                             "the section must paint findings, not a flat rectangle")
    }

    /// asc absent: the offline subset is the degraded explanation (§7), and it
    /// must paint rather than leave the section empty.
    func testOfflineCleanValidationPaintsTheDegradedExplanation() {
        let model = StoreValidationModel.make(report: report([], offline: true))
        let rep = snapshot(section(.loaded(model)), name: "validation-offline")
        XCTAssertGreaterThan(distinctColors(rep).count, 4,
                             "the offline subset must paint its explanation")
    }

    /// A validation failure the engine could not turn into findings still
    /// degrades to an explanation with the shared fix, never an empty state.
    func testFailedValidationPaintsTheExplanation() {
        let failure = StoreFailure(code: "store_asc_failed",
                                   message: "asc exited 2: json: unknown field \"bogusField\"")
        let rep = snapshot(section(.failed(failure)), name: "validation-failed")
        XCTAssertGreaterThan(distinctColors(rep).count, 4,
                             "a failed section must still paint an explanation")
    }
}

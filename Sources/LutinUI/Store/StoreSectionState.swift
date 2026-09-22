import Foundation
import LutinCore
import SwiftUI

/// A failure a Store section can explain rather than swallow. `fix` comes from
/// the shared suggestion table, so the GUI has one place for fix hints.
public struct StoreFailure: Equatable {
    public let code: String
    public let message: String
    public let fix: String?

    public init(code: String, message: String, fix: String? = nil) {
        self.code = code; self.message = message
        self.fix = fix ?? FixSuggestions.suggestion(for: code)
    }

    public init(_ error: LutinError) {
        self.init(code: error.code, message: error.message, fix: nil)
    }
}

/// What a section is showing right now. Sections degrade to an explanation
/// (spec §7), never to an empty or broken state.
public enum StoreSectionState<Model: Equatable>: Equatable {
    case loading
    case loaded(Model)
    case failed(StoreFailure)
}

/// A failed Store section, rendered in exactly one place: the message, then the
/// fix hint from the shared suggestion table. Every section's `.failed` body is
/// this view — a section that draws a fix itself is how the duplicate hint the
/// Task 2 review caught came back.
public struct StoreSectionFailure: View {
    let failure: StoreFailure
    public init(_ failure: StoreFailure) { self.failure = failure }

    public var body: some View {
        StatusRow(.blocked, failure.message)
        if let fix = failure.fix {
            Text(fix)
                .font(Typography.inspectorLabel)
                .foregroundStyle(Tokens.color(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

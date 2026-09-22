import Foundation
import LutinCore

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

    /// The failure's fix hint — what a degraded section shows as its footer.
    /// `nil` while loading or loaded; a loaded section's footer is its model's
    /// to supply, because only the model knows what it can say.
    public var failureFix: String? {
        if case .failed(let failure) = self { return failure.fix }
        return nil
    }
}

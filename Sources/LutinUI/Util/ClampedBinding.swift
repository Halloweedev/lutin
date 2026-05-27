import SwiftUI

extension Binding where Value == Int {
    /// Returns a binding that clamps writes into `range`. Reads pass through.
    /// Use to keep `LutinNumericField` type-in within the same bounds the
    /// paired `LutinStepper` honours.
    func clamped(to range: ClosedRange<Int>) -> Binding<Int> {
        let lo = range.lowerBound
        let hi = range.upperBound
        return Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = Swift.max(lo, Swift.min(hi, newValue))
            }
        )
    }
}

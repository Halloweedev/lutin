import SwiftUI

/// Paired `LutinIconButton`s for incrementing/decrementing an Int binding.
/// Honors a closed range and a step. No spinner, no field — pair with a
/// `LutinTextField` or `LutinNumericField` if free entry is needed.
public struct LutinStepper: View {
    let value: Binding<Int>
    let range: ClosedRange<Int>
    let step: Int

    public init(value: Binding<Int>, in range: ClosedRange<Int>, step: Int = 1) {
        self.value = value
        self.range = range
        self.step = step
    }

    public var body: some View {
        HStack(spacing: 0) {
            LutinIconButton(systemName: "minus",
                            accessibilityLabel: "Decrement",
                            action: decrement)
            LutinIconButton(systemName: "plus",
                            accessibilityLabel: "Increment",
                            action: increment)
        }
    }

    func incrementForTest() { increment() }
    func decrementForTest() { decrement() }

    private func increment() {
        value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
    }

    private func decrement() {
        value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
    }
}

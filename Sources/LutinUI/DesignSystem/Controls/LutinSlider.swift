import SwiftUI
import AppKit

/// Flat-track square-thumb slider. 4pt track height, 12×12 thumb. No rounded
/// caps. Hand-rolled (not a wrapper around SwiftUI's Slider) so we control
/// every pixel of the geometry.
public struct LutinSlider: View {
    let value: Binding<Double>
    let range: ClosedRange<Double>

    public init(value: Binding<Double>, in range: ClosedRange<Double>) {
        self.value = value
        self.range = range
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let progress = (value.wrappedValue - range.lowerBound)
                         / (range.upperBound - range.lowerBound)
            ZStack(alignment: .leading) {
                SquareShape()
                    .fill(Tokens.color(.surfaceElevated))
                    .frame(height: 4)
                    .frame(maxHeight: .infinity, alignment: .center)
                SquareShape()
                    .fill(Tokens.color(.brandAccent))
                    .frame(width: max(0, w * progress), height: 4)
                    .frame(maxHeight: .infinity, alignment: .center)
                SquareShape()
                    .fill(Tokens.color(.textPrimary))
                    .frame(width: 12, height: 12)
                    .offset(x: max(0, w * progress) - 6)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let raw = (g.location.x / w)
                                * (range.upperBound - range.lowerBound)
                                + range.lowerBound
                        value.wrappedValue = clamp(raw)
                    }
            )
        }
        .frame(height: 20)
    }

    func setForTest(_ raw: Double) {
        value.wrappedValue = clamp(raw)
    }

    private func clamp(_ raw: Double) -> Double {
        min(range.upperBound, max(range.lowerBound, raw))
    }
}

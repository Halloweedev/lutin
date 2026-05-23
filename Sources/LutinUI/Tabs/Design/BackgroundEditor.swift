import SwiftUI
import AppKit
import UniformTypeIdentifiers
import LutinConfig
import LutinDocument

public struct BackgroundEditor: View {
    @Bindable var document: LutinProjectDocument
    public init(document: LutinProjectDocument) { self.document = document }

    private enum Variant: String, CaseIterable, Identifiable {
        case solid, gradient, image
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
            // Variant switcher — flat segmented control rendered as a row
            // of buttons so it matches the rest of the chrome.
            variantSegments

            switch currentVariant {
            case .solid:    solidFields
            case .gradient: gradientFields
            case .image:    imageFields
            }

            commonFields
        }
    }

    // MARK: - Variant segmented control

    private var variantSegments: some View {
        HStack(spacing: 0) {
            ForEach(Variant.allCases) { v in
                LutinButton(role: currentVariant == v ? .primary : .secondary,
                            action: { selectVariant(v) }) {
                    Text(v.title)
                        .font(Typography.chromeSmall)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundStyle(currentVariant == v
                                         ? Color.white
                                         : Tokens.color(.textPrimary))
                        .background(currentVariant == v
                                    ? Tokens.color(.brandAccent)
                                    : Tokens.color(.canvasBackground))
                }
                if v != Variant.allCases.last {
                    Rectangle()
                        .fill(Tokens.color(.divider))
                        .frame(width: Tokens.Size.hairline)
                }
            }
        }
        .overlay(SquareShape().stroke(Tokens.color(.divider),
                                      lineWidth: Tokens.Size.hairline))
    }

    // MARK: - Variant-specific bodies

    private var solidFields: some View {
        SettingsField("Color") {
            colorWell(value: bg.colorA, onCommit: { hex in
                var b = bg; b.colorA = hex; b.colorB = nil
                b.template = nil; b.path = nil
                try? document.apply(.setBackground(b))
            })
        }
    }

    private var gradientFields: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
            SettingsField("Color A") {
                colorWell(value: bg.colorA, onCommit: { hex in
                    var b = bg; b.colorA = hex
                    try? document.apply(.setBackground(b))
                })
            }
            SettingsField("Color B") {
                colorWell(value: bg.colorB, onCommit: { hex in
                    var b = bg; b.colorB = hex
                    try? document.apply(.setBackground(b))
                })
            }
            SettingsField("Angle") {
                HStack(spacing: Tokens.spacing(.sm)) {
                    Text("\(bg.angle ?? 0)°").font(Typography.chromeSmall)
                    LutinStepper(value: Binding(
                        get: { bg.angle ?? 0 },
                        set: { var b = bg; b.angle = $0; try? document.apply(.setBackground(b)) }),
                        in: 0...359, step: 15)
                }
            }
        }
    }

    private var imageFields: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
            SettingsField("Image") {
                PathPickerRow(value: bg.path ?? "",
                              placeholder: "No image chosen",
                              onPick: pickImage)
            }
            SettingsField("Show grid overlay") {
                LutinToggle("", isOn: Binding(
                    get: { bg.grid ?? false },
                    set: { var b = bg; b.grid = $0; try? document.apply(.setBackground(b)) }))
            }
        }
    }

    private var commonFields: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
            SettingsField("Scale") {
                HStack(spacing: Tokens.spacing(.sm)) {
                    Text("\(bg.scale ?? 2)×").font(Typography.chromeSmall)
                    LutinStepper(value: Binding(
                        get: { bg.scale ?? 2 },
                        set: { var b = bg; b.scale = $0; try? document.apply(.setBackground(b)) }),
                        in: 1...2, step: 1)
                }
            }
            SettingsField("Corner radius") {
                HStack(spacing: Tokens.spacing(.sm)) {
                    Text("\(bg.cornerRadius ?? 0) pt").font(Typography.chromeSmall)
                    LutinStepper(value: Binding(
                        get: { bg.cornerRadius ?? 0 },
                        set: { var b = bg; b.cornerRadius = $0; try? document.apply(.setBackground(b)) }),
                        in: 0...64, step: 1)
                }
            }
            if currentVariant != .image {
                SettingsField("Noise",
                              helper: "Subtle texture overlay. 0 = none, 1 = strong.") {
                    LutinSlider(value: Binding(
                        get: { bg.noise ?? 0 },
                        set: { var b = bg; b.noise = $0; try? document.apply(.setBackground(b)) }),
                                in: 0...1)
                }
            }
        }
    }

    // MARK: - Helpers

    private var bg: LutinConfig.BackgroundInfo {
        document.config.background ?? LutinConfig.BackgroundInfo(
            type: nil, template: nil, path: nil, scale: nil,
            colorA: nil, colorB: nil, grid: nil, noise: nil,
            cornerRadius: nil, angle: nil)
    }

    private var currentVariant: Variant {
        switch bg.type {
        case "solid": return .solid
        case "gradient": return .gradient
        case "image": return .image
        default: return .solid  // legacy "generated" + nil → solid in the UI
        }
    }

    private func selectVariant(_ v: Variant) {
        var b = bg
        b.type = v.rawValue
        switch v {
        case .solid:    b.template = nil; b.colorB = nil; b.path = nil; b.angle = nil
        case .gradient: b.template = nil; b.path = nil
        case .image:    b.template = nil; b.colorA = nil; b.colorB = nil
                        b.angle = nil; b.noise = nil
        }
        try? document.apply(.setBackground(b))
    }

    private func colorWell(value: String?,
                           onCommit: @escaping (String) -> Void) -> some View {
        ColorPicker("", selection: Binding(
            get: { Color(hex: value ?? "#888888") ?? .gray },
            set: { newColor in onCommit(newColor.hexString) }))
            .labelsHidden()
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var b = bg
        b.path = url.path
        b.template = nil; b.colorA = nil; b.colorB = nil
        try? document.apply(.setBackground(b))
    }
}

private extension Color {
    init?(hex: String) {
        var s = hex; if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let n = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((n >> 16) & 0xff)/255,
                  green: Double((n >> 8) & 0xff)/255,
                  blue: Double(n & 0xff)/255)
    }
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return String(format: "#%02X%02X%02X",
                      Int((ns.redComponent * 255).rounded()),
                      Int((ns.greenComponent * 255).rounded()),
                      Int((ns.blueComponent * 255).rounded()))
    }
}

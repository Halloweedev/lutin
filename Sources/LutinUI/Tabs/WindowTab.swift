import SwiftUI
import LutinConfig
import LutinDocument

public struct WindowTab: View {
    @Bindable var document: LutinProjectDocument

    public init(document: LutinProjectDocument) { self.document = document }

    public var body: some View {
        TabBody {
            SettingsSection("Dimensions") {
                SettingsRow(icon: "arrow.left.and.right", "Width") {
                    dimensionValueRow(binding: widthBinding, range: 320...2048, step: 10, unit: "pt")
                }
                SettingsRow(icon: "arrow.up.and.down", "Height") {
                    dimensionValueRow(binding: heightBinding, range: 240...1536, step: 10, unit: "pt")
                }
            }

            SettingsSection("Icons & Labels") {
                SettingsRow(icon: "square.dashed", "Icon size") {
                    dimensionValueRow(binding: iconSizeBinding, range: 32...256, step: 8, unit: "pt")
                }
                SettingsRow(icon: "textformat.size", "Text size") {
                    dimensionValueRow(binding: textSizeBinding, range: 8...32, step: 1, unit: "pt")
                }
            }

            SettingsSection("Finder chrome") {
                SettingsRow(icon: "rectangle.topthird.inset.filled",
                            "Finder toolbar in mounted DMG",
                            helper: "The back / forward / view bar at the top of a Finder window. Most install DMGs hide it — keep off for a clean install layout.") {
                    LutinToggle("", isOn: showToolbarBinding)
                }
            }
        }
    }

    /// Stepper-left, typeable-value-right trailing content for a `SettingsRow`.
    /// The stepper sits on the left; the numeric field sits to its right with
    /// the unit suffix. The field is clamped to the same range the stepper uses.
    private func dimensionValueRow(binding: Binding<Int>,
                                   range: ClosedRange<Int>,
                                   step: Int,
                                   unit: String) -> some View {
        HStack(spacing: Tokens.spacing(.sm)) {
            LutinStepper(value: binding, in: range, step: step)
            HStack(spacing: 2) {
                LutinNumericField("", value: binding.clamped(to: range),
                                  format: .number)
                    .frame(width: 56)
                Text(unit)
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
            }
        }
    }

    private var window: LutinConfig.WindowInfo { document.config.window ?? defaultWindow }
    private var defaultWindow: LutinConfig.WindowInfo {
        LutinConfig.WindowInfo(width: nil, height: nil, iconSize: nil,
                               textSize: nil, showToolbar: nil, showSidebar: nil)
    }

    private var widthBinding: Binding<Int> {
        Binding(get: { window.width ?? 680 },
                set: { try? document.apply(.setWindow(width: $0, height: nil, iconSize: nil,
                                                      textSize: nil, showToolbar: nil, showSidebar: nil)) })
    }
    private var heightBinding: Binding<Int> {
        Binding(get: { window.height ?? 420 },
                set: { try? document.apply(.setWindow(width: nil, height: $0, iconSize: nil,
                                                      textSize: nil, showToolbar: nil, showSidebar: nil)) })
    }
    private var iconSizeBinding: Binding<Int> {
        Binding(get: { window.iconSize ?? 96 },
                set: { try? document.apply(.setWindow(width: nil, height: nil, iconSize: $0,
                                                      textSize: nil, showToolbar: nil, showSidebar: nil)) })
    }
    private var textSizeBinding: Binding<Int> {
        Binding(get: { window.textSize ?? 12 },
                set: { try? document.apply(.setWindow(width: nil, height: nil, iconSize: nil,
                                                      textSize: $0, showToolbar: nil, showSidebar: nil)) })
    }
    private var showToolbarBinding: Binding<Bool> {
        // Default `false` matches the build pipeline (`DMGLayout` uses
        // `?? false`) and every templated project. Was `?? true` — the
        // toggle visually lied about the built DMG until you flipped it.
        Binding(get: { window.showToolbar ?? false },
                set: { try? document.apply(.setWindow(width: nil, height: nil, iconSize: nil,
                                                      textSize: nil, showToolbar: $0, showSidebar: nil)) })
    }
    private var showSidebarBinding: Binding<Bool> {
        Binding(get: { window.showSidebar ?? false },
                set: { try? document.apply(.setWindow(width: nil, height: nil, iconSize: nil,
                                                      textSize: nil, showToolbar: nil, showSidebar: $0)) })
    }
}

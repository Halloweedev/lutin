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
                    dimensionValueRow(value: "\(window.width ?? 680) pt",
                                      binding: widthBinding, range: 320...2048, step: 10)
                }
                SettingsRow(icon: "arrow.up.and.down", "Height") {
                    dimensionValueRow(value: "\(window.height ?? 420) pt",
                                      binding: heightBinding, range: 240...1536, step: 10)
                }
            }

            SettingsSection("Icons & Labels") {
                SettingsRow(icon: "square.dashed", "Icon size") {
                    dimensionValueRow(value: "\(window.iconSize ?? 96) pt",
                                      binding: iconSizeBinding, range: 32...256, step: 8)
                }
                SettingsRow(icon: "textformat.size", "Text size") {
                    dimensionValueRow(value: "\(window.textSize ?? 12) pt",
                                      binding: textSizeBinding, range: 8...32, step: 1)
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

    /// Value-and-stepper trailing content for a `SettingsRow`. The value
    /// text is pinned to a single line via `fixedSize(horizontal:)` —
    /// without it, the narrow side-panel column will wrap a string like
    /// `"152 pt"` at the space and stack "152" above "pt".
    private func dimensionValueRow(value: String,
                                   binding: Binding<Int>,
                                   range: ClosedRange<Int>,
                                   step: Int) -> some View {
        HStack(spacing: Tokens.spacing(.sm)) {
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(Tokens.color(.textSecondary))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            LutinStepper(value: binding, in: range, step: step)
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

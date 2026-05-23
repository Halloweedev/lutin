import SwiftUI
import LutinConfig
import LutinDocument

public struct WindowTab: View {
    @Bindable var document: LutinProjectDocument

    public init(document: LutinProjectDocument) { self.document = document }

    public var body: some View {
        TabBody {
            SettingsSection("Dimensions",
                            footer: "Window opens at this size when the DMG mounts.") {
                SettingsRow(icon: "arrow.left.and.right", "Width") {
                    Stepper(value: widthBinding, in: 320...2048, step: 10) {
                        Text("\(window.width ?? 680) pt").font(.system(size: 12))
                            .foregroundStyle(Tokens.color(.textSecondary))
                    }
                }
                SettingsRow(icon: "arrow.up.and.down", "Height") {
                    Stepper(value: heightBinding, in: 240...1536, step: 10) {
                        Text("\(window.height ?? 420) pt").font(.system(size: 12))
                            .foregroundStyle(Tokens.color(.textSecondary))
                    }
                }
            }

            SettingsSection("Icons & Labels") {
                SettingsRow(icon: "app.dashed", "Icon size") {
                    Stepper(value: iconSizeBinding, in: 32...256, step: 8) {
                        Text("\(window.iconSize ?? 96) pt").font(.system(size: 12))
                            .foregroundStyle(Tokens.color(.textSecondary))
                    }
                }
                SettingsRow(icon: "textformat.size", "Text size") {
                    Stepper(value: textSizeBinding, in: 8...32, step: 1) {
                        Text("\(window.textSize ?? 12) pt").font(.system(size: 12))
                            .foregroundStyle(Tokens.color(.textSecondary))
                    }
                }
            }

            SettingsSection("Finder chrome") {
                SettingsRow(icon: "macwindow.on.rectangle", "Show toolbar") {
                    Toggle("", isOn: showToolbarBinding).labelsHidden()
                }
                SettingsRow(icon: "sidebar.left", "Show sidebar") {
                    Toggle("", isOn: showSidebarBinding).labelsHidden()
                }
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
        Binding(get: { window.showToolbar ?? true },
                set: { try? document.apply(.setWindow(width: nil, height: nil, iconSize: nil,
                                                      textSize: nil, showToolbar: $0, showSidebar: nil)) })
    }
    private var showSidebarBinding: Binding<Bool> {
        Binding(get: { window.showSidebar ?? false },
                set: { try? document.apply(.setWindow(width: nil, height: nil, iconSize: nil,
                                                      textSize: nil, showToolbar: nil, showSidebar: $0)) })
    }
}

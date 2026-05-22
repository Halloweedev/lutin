import SwiftUI
import LutinConfig
import LutinDocument

public struct WindowTab: View {
    @Bindable var document: LutinProjectDocument

    public init(document: LutinProjectDocument) { self.document = document }

    public var body: some View {
        Form {
            Section {
                Stepper("Width: \(window.width ?? 680) pt",
                        value: widthBinding, in: 320...2048, step: 10)
                Stepper("Height: \(window.height ?? 420) pt",
                        value: heightBinding, in: 240...1536, step: 10)
                Text("\(window.width ?? 680) × \(window.height ?? 420) pt — DMG window opens at this size")
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
            } header: { Text("Dimensions").font(Typography.chromeSmall) }

            Section {
                Stepper("Icon size: \(window.iconSize ?? 96) pt",
                        value: iconSizeBinding, in: 32...256, step: 8)
                Stepper("Text size: \(window.textSize ?? 12) pt",
                        value: textSizeBinding, in: 8...32, step: 1)
                Toggle("Show toolbar", isOn: showToolbarBinding)
                Toggle("Show sidebar", isOn: showSidebarBinding)
            } header: { Text("Chrome").font(Typography.chromeSmall) }
        }
        .formStyle(.grouped)
        .background(Tokens.color(.panelBackground))
    }

    private var window: LutinConfig.WindowInfo { document.config.window ?? defaultWindow }
    private var defaultWindow: LutinConfig.WindowInfo {
        LutinConfig.WindowInfo(width: nil, height: nil, iconSize: nil, textSize: nil,
                               showToolbar: nil, showSidebar: nil)
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

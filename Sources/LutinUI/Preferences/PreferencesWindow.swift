import SwiftUI
import LutinDocument

public struct PreferencesWindow: View {
    @Bindable var store: PreferencesStore
    @State private var selectedTab: Tab = .general

    public enum Tab: Hashable { case general, build, signing, theme }

    public init(store: PreferencesStore) { self.store = store }

    public var body: some View {
        TabView(selection: $selectedTab) {
            generalTab.tabItem { Label("General", systemImage: "gearshape") }.tag(Tab.general)
            buildTab.tabItem { Label("Build", systemImage: "hammer") }.tag(Tab.build)
            signingTab.tabItem { Label("Signing", systemImage: "checkmark.seal") }.tag(Tab.signing)
            themeTab.tabItem { Label("Theme", systemImage: "paintbrush") }.tag(Tab.theme)
        }
        .frame(minWidth: 520, minHeight: 320)
        .padding(Tokens.spacing(.xl))
    }

    private var generalTab: some View {
        Form {
            LutinToggle("Autosave", isOn: Binding(
                get: { store.preferences.autosave },
                set: { v in try? store.update { $0.autosave = v } }))
            LabeledContent("Snap grid") {
                HStack(spacing: Tokens.spacing(.sm)) {
                    Text("\(store.preferences.snapGridSize) pt").font(Typography.chromeSmall)
                    LutinStepper(
                        value: Binding(get: { store.preferences.snapGridSize },
                                       set: { v in try? store.update { $0.snapGridSize = v } }),
                        in: 1...32)
                }
            }
            LutinToggle("Show alignment guides", isOn: Binding(
                get: { store.preferences.showAlignmentGuides },
                set: { v in try? store.update { $0.showAlignmentGuides = v } }))
        }
    }

    private var buildTab: some View {
        Form {
            LutinTextField("Default output directory", text: Binding(
                get: { store.preferences.defaultOutputDirectory ?? "" },
                set: { v in try? store.update { $0.defaultOutputDirectory = v.isEmpty ? nil : v } }))
        }
    }

    private var signingTab: some View {
        Form {
            Text("Signing identity and notary profile are configured per-project in lutin.yml. Use the Doctor sheet to verify they're set up correctly.")
                .font(Typography.chromeSmall)
                .foregroundStyle(.secondary)
        }
    }

    private var themeTab: some View {
        Form {
            Picker("Appearance", selection: Binding(
                get: { store.preferences.theme },
                set: { v in try? store.update { $0.theme = v } })) {
                Text("System").tag(LutinPreferences.Theme.system)
                Text("Light").tag(LutinPreferences.Theme.light)
                Text("Dark").tag(LutinPreferences.Theme.dark)
            }
        }
    }
}

public struct PreferencesContainer: View {
    @State private var store = PreferencesStore()
    public init() {}
    public var body: some View {
        PreferencesWindow(store: store)
            .task { try? store.reload() }
    }
}

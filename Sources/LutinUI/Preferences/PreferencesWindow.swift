import SwiftUI
import LutinDocument

public struct PreferencesWindow: View {
    @Bindable var store: PreferencesStore
    @State private var selectedTab: Tab = .general

    public enum Tab: Hashable { case general, build, signing, theme }

    public init(store: PreferencesStore) { self.store = store }

    public var body: some View {
        VStack(spacing: Tokens.spacing(.md)) {
            brandHeader
            TabView(selection: $selectedTab) {
                generalTab.tabItem { Label("General", systemImage: "gearshape") }.tag(Tab.general)
                buildTab.tabItem { Label("Build", systemImage: "hammer") }.tag(Tab.build)
                signingTab.tabItem { Label("Signing", systemImage: "checkmark.seal") }.tag(Tab.signing)
                themeTab.tabItem { Label("Theme", systemImage: "paintbrush") }.tag(Tab.theme)
            }
        }
        .frame(minWidth: 520, minHeight: 360)
        .padding(Tokens.spacing(.xl))
    }

    private var brandHeader: some View {
        HStack(spacing: Tokens.spacing(.sm)) {
            Image("LutinLogo", bundle: LutinAssets.bundle)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(Tokens.color(.brandAccent))
            Text("Lutin")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Tokens.color(.textPrimary))
            Spacer()
        }
    }

    private var generalTab: some View {
        // The "Autosave" toggle was removed in 2026-05-25 — autosave is
        // now unconditional. The side-panel tabs read like settings
        // surfaces; making "did this stick?" depend on a hidden pref
        // was a footgun, and the prefs JSON's `autosave` field is now
        // ignored on decode and dropped on the next save.
        Form {
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
            HStack {
                Text("Appearance").font(Typography.controlLabel)
                Spacer()
                LutinPicker(
                    selection: Binding(
                        get: { store.preferences.theme },
                        set: { v in try? store.update { $0.theme = v } }),
                    options: [
                        .init(id: LutinPreferences.Theme.system, label: "System"),
                        .init(id: LutinPreferences.Theme.light, label: "Light"),
                        .init(id: LutinPreferences.Theme.dark, label: "Dark"),
                    ]
                )
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

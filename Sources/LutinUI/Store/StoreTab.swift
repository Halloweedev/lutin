import LutinDocument
import SwiftUI

/// Spec 1a §7's Store tab — the second channel surface, next to the DMG's
/// Design / Window / Project / Release.
///
/// Composed from the app's own chrome (`TabBody`, `SettingsSection`,
/// `SettingsRow`, `StatusRow`) and its own controls (`LutinPicker`,
/// `LutinToggle`, `LutinButton`). The visual audit's conclusion was that this
/// surface should inherit the existing language rather than invent one, and
/// reusing the containers is also what keeps a long row from overflowing the
/// panel.
///
/// There is no editing surface, by design: locale files are edited in the
/// developer's editor, by the CLI, or by an agent.
public struct StoreTab: View {
    let document: LutinProjectDocument
    @Bindable var state: StoreTabState

    public init(document: LutinProjectDocument, state: StoreTabState) {
        self.document = document
        self.state = state
    }

    public var body: some View {
        TabBody {
            connectionSection
            appSection
            versionsSection
            listingSection
            validationSection
        }
        .task { await state.refresh(document: document) }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        SettingsSection("Connection",
                        footer: state.connection?.fix,
                        headerTrailing: {
                            LutinButton("Re-check") {
                                Task { await state.refresh(document: document) }
                            }
                        }) {
            if let connection = state.connection {
                StatusRow(kind(for: connection.state), connection.headline)
                ForEach(connection.rows, id: \.label) { row in
                    SettingsRow(row.label, info: row.info) {
                        HStack(spacing: 6) {
                            Text(row.value)
                                .font(Typography.inspectorValue)
                                .foregroundStyle(Tokens.color(.textSecondary))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if let healthy = row.isHealthy {
                                Image(systemName: healthy ? "checkmark.circle.fill"
                                                          : "exclamationmark.triangle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Tokens.color(healthy ? .logSuccess : .logError))
                            }
                        }
                    }
                }
            } else {
                HStack {
                    Text("Checking asc…")
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textTertiary))
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// The section's whole job: say which failure mode applies. The fix rides
    /// in the section's footer, where a long hint does not crowd the rows.
    private func kind(for state: StoreConnectionSnapshot.State) -> StatusKind {
        switch state {
        case .ready:                                    return .ok
        case .offline, .noWebSession:                   return .warn
        case .ascMissing, .ascTooOld,
             .unauthenticated, .unexpected:             return .blocked
        }
    }

    // MARK: - App

    private var appSection: some View {
        StoreAppSection(state: state.app)
    }

    // MARK: - Versions

    private var versionsSection: some View {
        StoreVersionsSection(state: state.versions)
    }

    // MARK: - Listing

    private var listingSection: some View {
        SettingsSection("Listing", footer: state.listingNote ?? Self.previewProvenance) {
            SettingsRow("Locale") {
                LutinPicker(selection: $state.locale, options: localeOptions)
                    .frame(width: 170)
            }
            SettingsRow("Device") {
                LutinPicker(selection: $state.device, options: deviceOptions)
                    .frame(width: 170)
            }
            LutinToggle("Dark appearance", isOn: isDark)
        }
    }

    private static let previewProvenance =
        "Reads the canonical tree, so the preview cannot disagree with what a push would send."

    private var localeOptions: [LutinPicker<String>.Option] {
        (state.availableLocales.isEmpty ? [state.locale] : state.availableLocales)
            .map { LutinPicker<String>.Option(id: $0, label: $0) }
    }

    private var deviceOptions: [LutinPicker<StorePreviewDevice>.Option] {
        StorePreviewDevice.allCases.map {
            LutinPicker<StorePreviewDevice>.Option(id: $0, label: $0.displayName)
        }
    }

    private var isDark: Binding<Bool> {
        Binding(get: { state.appearance == .dark },
                set: { state.appearance = $0 ? .dark : .light })
    }

    // MARK: - Validation

    private var validationSection: some View {
        StoreValidationSection(state: state.validation) {
            Task { await state.refresh(document: document) }
        }
    }
}

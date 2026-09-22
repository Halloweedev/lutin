import LutinDocument
import SwiftUI

/// Spec 1a §7's Store tab — the second channel surface, next to the DMG's
/// Design / Window / Project / Release.
///
/// The visual audit put the preview's variant knobs here in the column, on the
/// grounds that locale, device and appearance are properties *of* the previewed
/// page in the same way Width and Icon size are properties of the DMG preview;
/// the canvas is left to the page itself.
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
            listingSection
        }
        .task { await state.refresh(document: document) }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        SettingsSection("Connection") {
            if let connection = state.connection {
                statusHeadline(connection)
                ForEach(connection.rows, id: \.label) { row in
                    HStack(spacing: Tokens.spacing(.sm)) {
                        Text(row.label)
                            .font(Typography.inspectorLabel)
                            .foregroundStyle(Tokens.color(.textSecondary))
                            .frame(width: 156, alignment: .leading)
                        Text(row.value)
                            .font(Typography.inspectorValue)
                            .foregroundStyle(Tokens.color(.textPrimary))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let healthy = row.isHealthy {
                            Image(systemName: healthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Tokens.color(healthy ? .logSuccess : .logError))
                        }
                        Spacer(minLength: 0)
                    }
                }
            } else {
                Text("Checking asc…")
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Tokens.color(.textTertiary))
            }
        }
    }

    /// The section's whole job: say which failure mode applies, and what fixes it.
    private func statusHeadline(_ connection: StoreConnectionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle()
                    .fill(Tokens.color(dotToken(connection.state)))
                    .frame(width: 7, height: 7)
                Text(connection.headline)
                    .font(Typography.chrome)
                    .foregroundStyle(Tokens.color(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let fix = connection.fix {
                Text(fix)
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Tokens.color(.textTertiary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            LutinButton("Re-check") {
                Task { await state.refresh(document: document) }
            }
        }
        .padding(.bottom, 2)
    }

    private func dotToken(_ state: StoreConnectionSnapshot.State) -> Tokens.Key {
        switch state {
        case .ready:                                    return .logSuccess
        case .offline, .noWebSession:                   return .logProgress
        case .ascMissing, .ascTooOld,
             .unauthenticated, .unexpected:             return .logError
        }
    }

    // MARK: - Listing

    private var listingSection: some View {
        SettingsSection("Listing") {
            variantRow("Locale") {
                LutinPicker(selection: $state.locale,
                            options: (state.availableLocales.isEmpty ? [state.locale] : state.availableLocales)
                                .map { LutinPicker<String>.Option(id: $0, label: $0) })
                    .frame(width: 200)
            }
            variantRow("Device") {
                LutinPicker(selection: $state.device,
                            options: StorePreviewDevice.allCases.map {
                                LutinPicker<StorePreviewDevice>.Option(id: $0, label: $0.displayName)
                            })
                    .frame(width: 200)
            }
            LutinToggle("Dark appearance", isOn: Binding(
                get: { state.appearance == .dark },
                set: { state.appearance = $0 ? .dark : .light }))
            if let note = state.listingNote {
                Text(note)
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Tokens.color(.textTertiary))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            Text("The preview reads the canonical tree and re-reads on refresh, so it cannot disagree with what a push would send.")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Tokens.color(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    private func variantRow<Control: View>(_ label: String,
                                           @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: Tokens.spacing(.sm)) {
            Text(label)
                .font(Typography.inspectorLabel)
                .foregroundStyle(Tokens.color(.textSecondary))
                .frame(width: 156, alignment: .leading)
            control()
            Spacer(minLength: 0)
        }
    }
}

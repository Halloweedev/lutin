import SwiftUI
import LutinDocument

/// Thin status strip at the bottom of the workspace. Always visible,
/// across both the welcome page and an open project. Shows three
/// environment indicators (codesign, Developer ID identity, notarytool
/// profile) and a `Doctor` button. The identity and profile indicators
/// are click-to-edit menus that set the workspace-wide defaults
/// `PreferencesStore.defaultSigningIdentity` and `defaultNotaryProfile`
/// — values used by `CreateProjectSheet` to seed new projects.
struct WorkspaceBottomBar: View {
    @Environment(CredentialsStore.self) private var credentialsStore
    @Environment(PreferencesStore.self) private var preferencesStore
    let onOpenDoctor: () -> Void

    var body: some View {
        HStack(spacing: Tokens.spacing(.md)) {
            codesignIndicator
            identityMenu
            profileMenu
            Spacer()
            LutinButton(role: .secondary, action: onOpenDoctor) {
                Text("Doctor")
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.brandAccent))
                    .padding(.horizontal, Tokens.spacing(.sm))
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, Tokens.spacing(.md))
        .frame(height: 28)
        .background(Tokens.color(.panelBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(height: Tokens.Size.hairline)
        }
    }

    // MARK: - Codesign (read-only — no meaningful default to set)

    private var codesignIndicator: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(credentialsStore.hasCodesign ? StatusKind.ok.color : StatusKind.blocked.color)
                .frame(width: 7, height: 7)
            Text("codesign")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
        }
    }

    // MARK: - Developer ID identity (click-to-set default)

    private var identityMenu: some View {
        let identities = credentialsStore.identities.filter { $0.name.contains("Developer ID Application:") }
        let current = preferencesStore.preferences.defaultSigningIdentity
        let state: DotState = identities.isEmpty
            ? .blocked
            : (current == nil ? .unknown : .ok)
        return Menu {
            if identities.isEmpty {
                SwiftUI.Text("No Developer ID identities in Keychain") // allow-menu-button: Menu pop-up item
            } else {
                ForEach(identities) { ident in
                    SwiftUI.Button {  // allow-menu-button: Menu pop-up item
                        try? preferencesStore.update { $0.defaultSigningIdentity = ident.name }
                    } label: {
                        if ident.name == current {
                            Label(shortIdentity(ident.name), systemImage: "checkmark")
                        } else {
                            Text(shortIdentity(ident.name))
                        }
                    }
                }
                if current != nil {
                    SwiftUI.Divider()
                    SwiftUI.Button("Clear default") {  // allow-menu-button: Menu pop-up item
                        try? preferencesStore.update { $0.defaultSigningIdentity = nil }
                    }
                }
            }
        } label: {
            indicatorRow(label: identityLabel(current: current), state: state)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func identityLabel(current: String?) -> String {
        if let current { return shortIdentity(current) }
        return "Developer ID"
    }

    /// Strips the `"Developer ID Application: "` prefix from a full
    /// identity string so the bottom bar stays scannable. The full
    /// name remains in the menu items.
    private func shortIdentity(_ full: String) -> String {
        let prefix = "Developer ID Application: "
        return full.hasPrefix(prefix) ? String(full.dropFirst(prefix.count)) : full
    }

    // MARK: - Notarytool profile (click-to-set default)

    private var profileMenu: some View {
        let profiles = preferencesStore.preferences.knownNotaryProfiles
        let current = preferencesStore.preferences.defaultNotaryProfile
        let state: DotState = current == nil ? .unknown : .ok
        return Menu {
            if profiles.isEmpty {
                SwiftUI.Text("No saved profiles — create one in Release tab") // allow-menu-button: Menu pop-up item
            } else {
                ForEach(profiles, id: \.self) { name in
                    SwiftUI.Button {  // allow-menu-button: Menu pop-up item
                        try? preferencesStore.update { $0.defaultNotaryProfile = name }
                    } label: {
                        if name == current {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
                if current != nil {
                    SwiftUI.Divider()
                    SwiftUI.Button("Clear default") {  // allow-menu-button: Menu pop-up item
                        try? preferencesStore.update { $0.defaultNotaryProfile = nil }
                    }
                }
            }
        } label: {
            indicatorRow(label: current ?? "notarytool profile", state: state)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: - Shared chip

    private enum DotState {
        case ok, warn, blocked, unknown
        var color: Color {
            switch self {
            case .ok:      return StatusKind.ok.color
            case .warn:    return StatusKind.warn.color
            case .blocked: return StatusKind.blocked.color
            case .unknown: return Tokens.color(.textTertiary)
            }
        }
    }

    private func indicatorRow(label: String, state: DotState) -> some View {
        HStack(spacing: 5) {
            Circle().fill(state.color).frame(width: 7, height: 7)
            Text(label)
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
                .lineLimit(1)
                .truncationMode(.middle)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Tokens.color(.textTertiary))
        }
        .contentShape(Rectangle())
    }
}

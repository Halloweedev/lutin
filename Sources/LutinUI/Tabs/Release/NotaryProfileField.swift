import SwiftUI
import LutinDocument

/// Text field for a notarytool keychain-profile name, plus the dropdown
/// of previously-saved names and an explicit "Test" button for
/// definitive Apple-side verification.
///
/// Why no live status indicator: we can't enumerate or query notarytool's
/// keychain items from a third-party app (ACL-restricted to Apple's
/// signing team — see `NotaryProbe.swift`). The dropdown is a positive
/// list ("things we've watched succeed") rather than a "things that
/// exist" picker; the Test button shells out to `xcrun notarytool
/// history` for an authoritative yes/no on any name.
struct NotaryProfileField: View {
    @Binding var name: String
    /// Fires when the user picks "New profile…" from the dropdown.
    /// Owner shows the `NotaryProfileSheet` and feeds the new name
    /// back into our `name` binding so the dropdown's success flash
    /// and selection sync up automatically.
    let onCreateNew: () -> Void

    @Environment(PreferencesStore.self) private var preferencesStore

    @State private var testState: TestState = .idle
    /// Transient visibility for the "saved" badge. Flipped on after a
    /// successful Test or a save-then-name-set roundtrip from the
    /// sheet, then cleared by `savedFlashTask` after a short hold so
    /// the field doesn't carry a permanent confirmation.
    @State private var savedFlashActive = false
    @State private var savedFlashTask: Task<Void, Never>?

    private enum TestState: Equatable {
        case idle
        case running
        case ok
        case profileNotFound
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.xs)) {
            HStack(spacing: Tokens.spacing(.sm)) {
                LutinTextField("ci-notary", text: $name)
                profileMenu
                trackedBadge
                LutinButton("Test") {
                    Task { await runTest() }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                          || testState == .running)
            }
            .onChange(of: name) { oldValue, newValue in
                // Reset transient test state when the name changes —
                // a green ✓ from a prior name shouldn't linger on a
                // freshly-typed (untested) one.
                if testState != .idle { testState = .idle }
                // Flash the "saved" badge when the new value lands on
                // a known-saved profile (covers the sheet auto-fill
                // path, dropdown picks, and the user typing the last
                // letter of a remembered name). Skip if the name
                // didn't actually change — guard against onChange
                // firing for whitespace-only edits.
                let trimmedNew = newValue.trimmingCharacters(in: .whitespaces)
                let trimmedOld = oldValue.trimmingCharacters(in: .whitespaces)
                if trimmedNew != trimmedOld,
                   !trimmedNew.isEmpty,
                   preferencesStore.preferences.knownNotaryProfiles.contains(trimmedNew) {
                    flashSavedBadge()
                }
            }
            testResultStrip
        }
    }

    /// Always-on dropdown next to the text field. Lists previously-saved
    /// profile names at the top (when any), then a divider, then a
    /// "New profile…" item that opens the creation sheet via
    /// `onCreateNew`. Bare `chevron.down` glyph so it reads as a
    /// secondary affordance against the LutinTextField next to it.
    @ViewBuilder
    private var profileMenu: some View {
        let saved = preferencesStore.preferences.knownNotaryProfiles
        Menu {
            if !saved.isEmpty {
                ForEach(saved, id: \.self) { profile in
                    // allow-menu-button: Menu pop-up item
                    SwiftUI.Button(profile) { name = profile }
                }
                Divider()
            }
            // allow-menu-button: Menu pop-up item
            SwiftUI.Button("New profile…") { onCreateNew() }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Tokens.color(.textSecondary))
                .frame(width: 20, height: Tokens.Size.controlHeight)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Notary profiles")
        .accessibilityLabel("Notary profiles")
    }

    /// Brief confirmation badge after a save event (Test succeeded, or
    /// sheet just created the profile). Auto-hides via
    /// `savedFlashTask`; gated by membership in `knownNotaryProfiles`
    /// as a sanity guard so a stale flash from a now-forgotten profile
    /// can't lie.
    @ViewBuilder
    private var trackedBadge: some View {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if savedFlashActive,
           !trimmed.isEmpty,
           preferencesStore.preferences.knownNotaryProfiles.contains(trimmed) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Tokens.color(.logSuccess))
                Text("saved")
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textSecondary))
            }
            .transition(.opacity)
        }
    }

    /// Shows the "saved" badge and schedules it to fade out. Replaces
    /// any in-flight hide so back-to-back saves don't expire early.
    private func flashSavedBadge() {
        savedFlashTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) {
            savedFlashActive = true
        }
        savedFlashTask = Task { @MainActor in
            // 2.5s reads as "I saw it" without overstaying — short
            // enough that the field doesn't look permanently labelled.
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                savedFlashActive = false
            }
        }
    }

    /// Result of the Test button, shown below the field. Hidden when
    /// idle. Definitive — the answer came from notarytool itself.
    /// Colors and SF Symbols are sourced from the shared `StatusKind`
    /// token so this strip stays in sync with `StatusRow` in the
    /// Release tab and the Doctor sheet's check icons.
    @ViewBuilder
    private var testResultStrip: some View {
        switch testState {
        case .idle:
            EmptyView()
        case .running:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Asking notarytool…")
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
            }
        case .ok:
            statusLine(.ok, "Verified by notarytool — credentials accepted.")
        case .profileNotFound:
            statusLine(.blocked, "notarytool couldn't find this profile.")
        case .failed(let reason):
            statusLine(.warn, "notarytool error: \(reason)")
        }
    }

    private func statusLine(_ kind: StatusKind, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(kind.color)
            Text(text)
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Shells out to `xcrun notarytool history --keychain-profile <name>`
    /// and updates the result strip. Notarytool is the only authorized
    /// reader of its own keychain entries; this is the only way to
    /// definitively verify a profile from outside notarytool itself.
    private func runTest() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        testState = .running
        let result = await NotaryProbe.test(profileName: trimmed)
        switch result {
        case .ok:
            testState = .ok
            try? preferencesStore.rememberNotaryProfile(trimmed)
            // Flash the badge — the user just confirmed credentials.
            flashSavedBadge()
        case .profileNotFound:
            testState = .profileNotFound
            // Profile is gone — drop it from our remembered list so
            // the dropdown stops offering a name that won't resolve.
            try? preferencesStore.forgetNotaryProfile(trimmed)
        case .failed(let reason):
            testState = .failed(reason)
        }
    }
}

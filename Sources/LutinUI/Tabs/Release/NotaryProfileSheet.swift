import SwiftUI
import AppKit
import LutinCore
import LutinDocument

/// Modal for creating a new notarytool keychain profile from inside Lutin.
///
/// Shells out to `xcrun notarytool store-credentials <name>` with the
/// user-supplied Apple ID, Team ID, and app-specific password. The
/// password is captured in a `SecureField` (no screen recording, no
/// pasteboard mirror) and passed to the subprocess as a single argv
/// element — never written to disk by Lutin, never logged.
///
/// On success, the parent view re-probes via `CredentialsStore.refresh`
/// so the new profile appears in the picker immediately. On failure,
/// the sheet stays open with the error surfaced and lets the user fix
/// the input without retyping the password.
@MainActor
struct NotaryProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PreferencesStore.self) private var preferencesStore
    /// Fires on a confirmed successful save (notarytool printed
    /// "Credentials saved to Keychain"). The argument is the trimmed
    /// profile name — callers use it to auto-select the new profile in
    /// the Notarization field so the user doesn't have to retype it.
    let onCreated: (String) -> Void

    @State private var profileName: String = ""
    @State private var appleID: String = ""
    @State private var teamID: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false
    @State private var error: String?
    /// Captured notarytool stdout+stderr from the most recent attempt.
    /// Shown in a disclosure under the error banner so we can see what
    /// actually happened — `notarytool store-credentials` sometimes
    /// exits 0 *and* prints "Validation failed" to stdout without
    /// storing anything. Lutin used to trust the exit code alone and
    /// silently report success.
    @State private var diagnostics: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.lg)) {
            header
            form
            if let error {
                Text(error)
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.logError))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let diagnostics, !diagnostics.isEmpty {
                DisclosureGroup("notarytool output") {
                    ScrollView {
                        Text(diagnostics)
                            .font(Typography.logLine)
                            .foregroundStyle(Tokens.color(.textSecondary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Tokens.spacing(.sm))
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 160)
                    .background(SquareShape().fill(Tokens.color(.canvasBackground)))
                    .overlay(SquareShape().stroke(Tokens.color(.divider),
                                                  lineWidth: Tokens.Size.hairline))
                }
                .font(Typography.chromeSmall)
            }
            footer
        }
        .padding(Tokens.spacing(.xl))
        .frame(width: 520)
        .background(Tokens.color(.sheetBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.xs)) {
            Text("Create notary profile")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Tokens.color(.textPrimary))
            Text("Stores an Apple ID + app-specific password under a profile name in your Keychain. `xcrun notarytool` then submits using this profile.")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
            SettingsField("Profile name",
                          helper: "Short identifier — e.g. \"ci-notary\" or your team handle.") {
                LutinTextField("ci-notary", text: $profileName)
            }
            SettingsField("Apple ID",
                          helper: "Your developer-account email.") {
                LutinTextField("you@example.com", text: $appleID)
            }
            SettingsField("Team ID",
                          helper: "10-character team identifier from developer.apple.com → Membership.") {
                LutinTextField("ABC1234567", text: $teamID)
            }
            SettingsField("App-specific password",
                          helper: "Generate at appleid.apple.com → Sign-In and Security → App-Specific Passwords. Format: xxxx-xxxx-xxxx-xxxx.") {
                // SecureField, not LutinTextField — never echoes the
                // password on screen, never lets it hit the pasteboard
                // history via plain-text reads.
                SecureField("xxxx-xxxx-xxxx-xxxx", text: $password)
                    .textFieldStyle(.plain)
                    .font(Typography.controlLabel)
                    .padding(.horizontal, Tokens.spacing(.sm))
                    .padding(.vertical, Tokens.spacing(.xs))
                    .background(SquareShape().fill(Tokens.color(.surfaceElevated)))
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            LutinButton("Cancel") { dismiss() }
                .disabled(isSubmitting)
            LutinButton("Create", role: .primary) {
                Task { await submit() }
            }
            .disabled(isSubmitting || !isComplete)
        }
    }

    private var isComplete: Bool {
        !profileName.trimmingCharacters(in: .whitespaces).isEmpty
            && !appleID.trimmingCharacters(in: .whitespaces).isEmpty
            && !teamID.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
    }

    private func submit() async {
        guard isComplete else { return }
        error = nil
        diagnostics = nil
        isSubmitting = true
        defer { isSubmitting = false }
        let trimmedName = profileName.trimmingCharacters(in: .whitespaces)
        do {
            let result = try await runStoreCredentials()
            // Save diagnostics regardless — they're useful on both
            // success and failure paths for confirming what notarytool
            // actually did.
            diagnostics = result.combinedOutput.isEmpty
                ? nil
                : result.combinedOutput
            // notarytool exits 0 on both real success and on
            // credential-validation failure (it reports "Validation
            // failed" to stdout while still exiting cleanly). Parse
            // the captured output for the success token so we don't
            // falsely claim creation when validation rejected the
            // creds. The text "Credentials saved to Keychain" is what
            // notarytool prints on a real save.
            let combined = result.combinedOutput.lowercased()
            let saved = combined.contains("credentials saved to keychain")
            if !saved {
                error = "notarytool exited cleanly but didn't report \"Credentials saved to Keychain\". Usually this means the app-specific password, Apple ID, or Team ID is wrong — or the Apple ID isn't enrolled in the paid Developer Program."
                return
            }
            // Record this profile in preferences so the rest of the
            // UI can show the "saved" indicator without trying to query
            // the Keychain directly (which is ACL-blocked — see
            // NotaryProbe.swift for the long story).
            try? preferencesStore.rememberNotaryProfile(trimmedName)
            password = ""
            onCreated(trimmedName)
            dismiss()
        } catch let err as LutinError {
            self.error = err.message
            self.diagnostics = err.details?["output"] as? String
        } catch {
            self.error = error.localizedDescription
        }
    }

    private struct StoreCredentialsResult {
        let exitStatus: Int32
        let combinedOutput: String
    }

    /// Runs `xcrun notarytool store-credentials <name> --apple-id … --team-id … --password …`
    /// off the main queue. Captures stdout + stderr together because
    /// notarytool inconsistently uses both — validation diagnostics
    /// land on stdout, command-shape errors on stderr. The password is
    /// part of argv (visible to the kernel's process listing for the
    /// duration of the call) but not persisted by Lutin. notarytool
    /// encrypts the credential into the Keychain on success.
    private func runStoreCredentials() async throws -> StoreCredentialsResult {
        let args = [
            "notarytool", "store-credentials",
            profileName.trimmingCharacters(in: .whitespaces),
            "--apple-id", appleID.trimmingCharacters(in: .whitespaces),
            "--team-id", teamID.trimmingCharacters(in: .whitespaces),
            "--password", password,
        ]
        let capturedArgs = args
        return try await Task.detached(priority: .userInitiated) { () -> StoreCredentialsResult in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            p.arguments = capturedArgs
            let outPipe = Pipe()
            let errPipe = Pipe()
            p.standardOutput = outPipe
            p.standardError = errPipe
            try p.run()
            p.waitUntilExit()
            let stdout = String(
                data: outPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8) ?? ""
            let stderr = String(
                data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8) ?? ""
            let combined = [stdout, stderr]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if p.terminationStatus != 0 {
                throw LutinError(
                    code: "notary_profile_store_failed",
                    message: "xcrun notarytool exited \(p.terminationStatus).",
                    details: ["output": combined])
            }
            return StoreCredentialsResult(exitStatus: p.terminationStatus,
                                          combinedOutput: combined)
        }.value
    }
}

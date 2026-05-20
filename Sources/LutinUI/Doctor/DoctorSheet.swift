import SwiftUI
import LutinCore
import LutinSigning
import LutinNotarization
import LutinDocument

public struct DoctorSheet: View {
    let document: LutinProjectDocument
    @Environment(\.dismiss) private var dismiss
    @State private var results: [Check] = []
    @State private var running: Bool = false

    public init(document: LutinProjectDocument) {
        self.document = document
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.lg)) {
            HStack {
                Text("Doctor").font(.title2.weight(.semibold))
                Spacer()
                Button("Re-run") { Task { await runChecks() } }.disabled(running)
                Button("Done") { dismiss() }
            }
            if results.isEmpty && !running {
                EmptyState(title: "Run checks to begin",
                           message: "Doctor inspects code-signing identity, notary profile, and bundle structure.",
                           icon: "DoctorAllClear")
            }
            if running {
                ProgressView("Running checks…")
            }
            ForEach(results) { check in CheckRow(check: check) }
        }
        .padding(Tokens.spacing(.xl))
        .frame(minWidth: 520, minHeight: 360)
        .task { await runChecks() }
    }

    struct Check: Identifiable {
        enum Status { case ok, warn, fail }
        let id = UUID()
        let title: String
        let detail: String
        let status: Status
    }

    private func runChecks() async {
        running = true
        var collected: [Check] = []

        if let signing = document.config.signing, signing.enabled, let identity = signing.identity {
            do {
                try CodeSigner.verifyIdentityExists(identity, runner: ShellCommandRunner())
                collected.append(.init(title: "Signing identity present",
                                       detail: identity, status: .ok))
            } catch let err as LutinError {
                collected.append(.init(title: "Signing identity missing",
                                       detail: err.message, status: .fail))
            } catch {
                collected.append(.init(title: "Signing identity check failed",
                                       detail: error.localizedDescription, status: .fail))
            }
        } else {
            collected.append(.init(title: "Signing disabled",
                                   detail: "`signing.enabled` is false; release builds will be unsigned.",
                                   status: .warn))
        }

        if let notary = document.config.notarization, notary.enabled, let profile = notary.profile, !profile.isEmpty {
            collected.append(.init(title: "Notary profile configured",
                                   detail: "Keychain profile: \(profile)", status: .ok))
        } else {
            collected.append(.init(title: "Notary profile missing",
                                   detail: "Add a notary profile via `xcrun notarytool store-credentials`.",
                                   status: .warn))
        }

        let appURL = URL(fileURLWithPath: document.config.app.path,
                         relativeTo: document.projectDirectory)
        if FileManager.default.fileExists(atPath: appURL.path) {
            collected.append(.init(title: "App bundle exists",
                                   detail: appURL.path, status: .ok))
        } else {
            collected.append(.init(title: "App bundle missing",
                                   detail: "Expected at \(appURL.path)", status: .fail))
        }

        results = collected
        running = false
    }
}

private struct CheckRow: View {
    let check: DoctorSheet.Check
    var body: some View {
        HStack(alignment: .top, spacing: Tokens.spacing(.md)) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(check.title).font(.headline)
                Text(check.detail)
                    .font(Typography.chromeSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Tokens.spacing(.sm))
    }

    @ViewBuilder private var icon: some View {
        switch check.status {
        case .ok:   Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.color(.logSuccess))
        case .warn: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Tokens.color(.logProgress))
        case .fail: Image(systemName: "xmark.octagon.fill").foregroundStyle(Tokens.color(.logError))
        }
    }
}

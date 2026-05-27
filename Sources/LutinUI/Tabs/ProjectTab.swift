import SwiftUI
import AppKit
import LutinDocument

public struct ProjectTab: View {
    @Bindable var document: LutinProjectDocument
    public init(document: LutinProjectDocument) { self.document = document }

    public var body: some View {
        TabBody {
            SettingsSection("Identity", headerMeta: {
                Text(document.config.app.path.isEmpty ? "unlinked" : "linked")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(document.config.app.path.isEmpty
                                     ? Tokens.color(.textTertiary)
                                     : Tokens.color(.logSuccess))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(document.config.app.path.isEmpty
                                ? Color.clear
                                : Tokens.color(.brandAccentMuted)
                                    .opacity(0.5))
            }) {
                SettingsField("Project name") {
                    SettingsTextField("MyApp", text: Binding(
                        get: { document.config.project.name },
                        set: { try? document.apply(.setProjectMetadata(
                            name: $0,
                            bundleId: document.config.project.bundleId)) }))
                }
                SettingsField("App bundle") {
                    PathPickerRow(value: document.config.app.path,
                                  placeholder: "No .app chosen",
                                  onPick: pickApp)
                }
                // Bundle identifier sourced live from the .app's
                // Info.plist — read-only. The YAML's `project.bundleId`
                // remains as a record of "what bundle id this project
                // was built around" but it doesn't drive anything; the
                // real identifier lives inside the .app. See helper.
                SettingsField("Bundle identifier",
                              helper: "Edit in Xcode → target → Signing & Capabilities, or in the .app's Info.plist.") {
                    BundleIdentifierReadout(
                        appPath: document.config.app.path,
                        projectDirectory: document.projectDirectory,
                        fallback: document.config.project.bundleId)
                }
            }

            SettingsSection("Output", headerMeta: {
                Text(document.config.output.directory.isEmpty
                     ? "—"
                     : document.config.output.directory.collapsedHome)
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
                    .lineLimit(1).truncationMode(.middle)
            }) {
                SettingsField("Directory") {
                    PathPickerRow(value: document.config.output.directory,
                                  placeholder: "Pick a folder",
                                  onPick: pickOutputDir)
                }
                SettingsField("DMG name") {
                    SettingsTextField("MyApp-${version}.dmg", text: Binding(
                        get: { document.config.output.dmgName },
                        set: { try? document.apply(.setOutput(
                            directory: document.config.output.directory,
                            dmgName: $0,
                            volumeName: document.config.output.volumeName)) }))
                }
                SettingsField("Volume name",
                              helper: "Shown in Finder when the DMG mounts.") {
                    SettingsTextField("MyApp", text: Binding(
                        get: { document.config.output.volumeName },
                        set: { try? document.apply(.setOutput(
                            directory: document.config.output.directory,
                            dmgName: document.config.output.dmgName,
                            volumeName: $0)) }))
                }
            }
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? document.apply(.setApp(path: url.path))
    }

    private func pickOutputDir() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? document.apply(.setOutput(directory: url.path,
                                       dmgName: document.config.output.dmgName,
                                       volumeName: document.config.output.volumeName))
    }
}

/// Read-only field that displays the linked `.app`'s `CFBundleIdentifier`.
///
/// The bundle identifier in the YAML (`config.project.bundleId`) is a
/// record-only carry-over from project creation; the real identifier is
/// inside the .app and is set by the developer in Xcode (or in the
/// `Info.plist` directly). Showing it live keeps the UI honest: what you
/// see is what the build pipeline (codesign / notarytool) will see when
/// they inspect the bundle.
///
/// Falls back to the YAML value when the .app can't be read — usually
/// because it's a relative path on a machine where the file no longer
/// exists, or hasn't been picked yet.
private struct BundleIdentifierReadout: View {
    let appPath: String
    let projectDirectory: URL
    let fallback: String

    var body: some View {
        HStack(spacing: Tokens.spacing(.sm)) {
            Text(displayedIdentifier.isEmpty ? "—" : displayedIdentifier)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(displayedIdentifier.isEmpty
                                 ? Tokens.color(.textTertiary)
                                 : Tokens.color(.textPrimary))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.color(.canvasBackground))
                .overlay(SquareShape().stroke(Tokens.color(.divider),
                                              lineWidth: Tokens.Size.hairline))
                .textSelection(.enabled)
            if !displayedIdentifier.isEmpty {
                Text("from Info.plist")
                    .font(.system(size: 10))
                    .foregroundStyle(Tokens.color(.textTertiary))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.6))
                    .overlay(SquareShape().stroke(Tokens.color(.divider),
                                                  lineWidth: Tokens.Size.hairline))
            }
        }
    }

    /// Resolves the `.app` URL and asks `AppBundleInfo` to read its
    /// Info.plist. On any failure (missing file, malformed plist, no
    /// `CFBundleIdentifier` key), returns the YAML fallback — never
    /// throws into the UI. The lookup is cheap (plist read on a small
    /// file) but happens on every body re-eval; if it ever becomes hot,
    /// cache via `@State` keyed on `appPath`.
    private var displayedIdentifier: String {
        let trimmed = appPath.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return fallback }
        let url = URL(fileURLWithPath: trimmed, relativeTo: projectDirectory)
            .standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return fallback
        }
        return (try? AppBundleInfo.read(url).bundleIdentifier) ?? fallback
    }
}

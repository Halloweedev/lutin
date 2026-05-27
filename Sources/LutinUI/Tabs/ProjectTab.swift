import SwiftUI
import AppKit
import LutinConfig
import LutinDocument

public struct ProjectTab: View {
    @Bindable var document: LutinProjectDocument
    public init(document: LutinProjectDocument) { self.document = document }

    public var body: some View {
        TabBody {
            SettingsSection("Identity", headerMeta: { identityPill }) {
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
                VStack(alignment: .leading, spacing: 6) {
                    dmgNameLabel
                    SettingsTextField("MyApp-${version}.dmg", text: Binding(
                        get: { document.config.output.dmgName },
                        set: { try? document.apply(.setOutput(
                            directory: document.config.output.directory,
                            dmgName: $0,
                            volumeName: document.config.output.volumeName)) }))
                    dmgResolvesToStrip
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private var dmgNameLabel: some View {
        // "DMG name · supports ${version} ${build}" — token suffix renders
        // in a small mono code style so the user sees exactly what to type.
        HStack(spacing: 6) {
            Text("DMG name")
                .font(Typography.chromeSmall.weight(.medium))
                .foregroundStyle(Tokens.color(.textSecondary))
            Text("· supports")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textTertiary))
            tokenChip("${version}")
            tokenChip("${build}")
        }
    }

    private func tokenChip(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 10, design: .monospaced))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Tokens.color(.canvasBackground))
            .overlay(SquareShape().stroke(Tokens.color(.divider),
                                          lineWidth: Tokens.Size.hairline))
    }

    private var dmgResolvesToStrip: some View {
        // Live substitution using the same TokenResolver the release
        // pipeline uses (`LutinRelease/ReleasePipeline.swift:45`). When
        // no .app is linked we surface the template + a hint instead of a
        // misleading preview.
        let template = document.config.output.dmgName
        let info = liveAppInfo()
        let resolved: String
        let trailing: String
        if let info {
            resolved = TokenResolver.resolve(template,
                TokenResolver.Context(version: info.shortVersion ?? "",
                      name: document.config.project.name,
                      build: info.build ?? ""))
            trailing = ""
        } else {
            resolved = template
            trailing = "Resolves when an app is linked."
        }
        return HStack(alignment: .top, spacing: Tokens.spacing(.sm)) {
            Rectangle()
                .fill(Tokens.color(.brandAccent))
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("RESOLVES TO")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(Tokens.color(.textTertiary))
                Text(resolved)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Tokens.color(.textPrimary))
                    .textSelection(.enabled)
                if !trailing.isEmpty {
                    Text(trailing)
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textTertiary))
                }
            }
            .padding(.vertical, 4)
            Spacer()
        }
        .padding(.horizontal, 8)
        .background(Tokens.color(.canvasBackground))
    }

    private var identityPill: some View {
        // Three states (more honest than the binary "linked / unlinked"
        // we shipped before): app reachable on disk → green linked;
        // path is set but the bundle isn't there anymore → amber missing;
        // never linked → grey unlinked.
        let path = document.config.app.path
            .trimmingCharacters(in: .whitespaces)
        let label: String
        let fg: Color
        let bg: Color
        if path.isEmpty {
            label = "unlinked"
            fg = Tokens.color(.textTertiary)
            bg = .clear
        } else if liveAppInfo() != nil {
            label = "linked"
            fg = Tokens.color(.logSuccess)
            bg = Tokens.color(.brandAccentMuted).opacity(0.5)
        } else {
            label = "missing"
            fg = Tokens.color(.logProgress)
            bg = Tokens.color(.brandAccentMuted).opacity(0.5)
        }
        return Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
    }

    /// Reads the linked `.app`'s `Info.plist` for the live DMG-name preview.
    /// Returns `nil` only when no app is linked or the file is unreadable —
    /// in those cases the preview shows the template plus a "Resolves when
    /// an app is linked." helper line instead of a substitution.
    ///
    /// Empty-string fallbacks for `shortVersion` / `build` (in the caller)
    /// match `LutinRelease.InfoPlistReader.read(...)`'s contract — that
    /// reader is the one `ReleasePipeline.swift:34` uses to build the
    /// token context for actual builds. Keeping the same fallback shape
    /// here means the preview filename matches what the build will produce
    /// byte-for-byte when version fields are missing from the plist.
    private func liveAppInfo() -> AppBundleInfo.Metadata? {
        let trimmed = document.config.app.path
            .trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let url = URL(fileURLWithPath: trimmed,
                      relativeTo: document.projectDirectory)
            .standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try? AppBundleInfo.read(url)
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
                    .background(Tokens.color(.canvasBackground))
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

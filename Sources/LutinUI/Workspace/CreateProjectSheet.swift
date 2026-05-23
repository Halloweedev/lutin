import SwiftUI
import AppKit
import LutinDocument

/// Modal sheet for creating a brand-new project. Picking a `.app` is the
/// first/primary action — the bundle's `Info.plist` populates the other
/// fields. Writes `lutin.yml` under `~/Lutin/<slug>/` via
/// `ProjectBootstrap.create(...)` and hands the resulting URL back to the
/// workspace via `onCreate`.
public struct CreateProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (URL, String) -> Void
    let preselectedAppURL: URL?

    @State private var appPath: String = ""
    @State private var appVersion: String?
    @State private var appBuild: String?
    @State private var projectName: String = ""
    @State private var bundleId: String = ""
    @State private var windowWidth: Int = 680
    @State private var windowHeight: Int = 420
    @State private var error: String?

    public init(preselectedAppURL: URL? = nil,
                onCreate: @escaping (URL, String) -> Void) {
        self.preselectedAppURL = preselectedAppURL
        self.onCreate = onCreate
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().frame(height: Tokens.Size.hairline).background(Tokens.color(.divider))
            form
            Divider().frame(height: Tokens.Size.hairline).background(Tokens.color(.divider))
            buttons
        }
        .frame(width: 540)
        .background(Tokens.color(.sheetBackground))
        .onAppear {
            if let url = preselectedAppURL, appPath.isEmpty {
                ingest(appURL: url)
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "plus.square")
                .font(.system(size: 16))
                .foregroundStyle(Tokens.color(.brandAccent))
            Text("Create new project").font(Typography.chrome)
                .foregroundStyle(Tokens.color(.textPrimary))
            Spacer()
        }
        .padding(Tokens.spacing(.md))
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
            // 1. The .app bundle — the source of truth for everything else.
            appPickerRow
            if !appPath.isEmpty {
                // 2. Auto-filled metadata. Editable for the rare case the
                //    user wants to deviate from what's in Info.plist.
                labeled("Project name") {
                    TextField("", text: $projectName)
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(SquareShape().stroke(Tokens.color(.divider),
                                                         lineWidth: Tokens.Size.hairline))
                }
                labeled("Bundle identifier") {
                    TextField("com.example.appname", text: $bundleId)
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(SquareShape().stroke(Tokens.color(.divider),
                                                         lineWidth: Tokens.Size.hairline))
                }
                versionRow
                windowSizeRow
                locationRow
            }
            if let error {
                Text(error)
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.logError))
            }
        }
        .padding(Tokens.spacing(.md))
    }

    private var appPickerRow: some View {
        LutinButton(role: .secondary, action: pickApp) {
            HStack(spacing: Tokens.spacing(.md)) {
                Image(systemName: appPath.isEmpty ? "app.dashed" : "app.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Tokens.color(.brandAccent))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appPath.isEmpty ? "Choose a .app to package" : "Selected .app")
                        .font(Typography.chrome)
                        .foregroundStyle(Tokens.color(.textPrimary))
                    Text(appPath.isEmpty
                         ? "We'll read its bundle id, name, and version from Info.plist"
                         : appPath)
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textSecondary))
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Text(appPath.isEmpty ? "Choose…" : "Change…")
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.brandAccent))
            }
            .padding(Tokens.spacing(.md))
            .background(Tokens.color(.panelBackground))
            .overlay(SquareShape().stroke(Tokens.color(.divider),
                                          lineWidth: Tokens.Size.hairline))
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var versionRow: some View {
        if appVersion != nil || appBuild != nil {
            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .foregroundStyle(Tokens.color(.textTertiary))
                Text("Detected version:")
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textSecondary))
                Text((appVersion ?? "—") + (appBuild.map { " (\($0))" } ?? ""))
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textPrimary))
            }
        }
    }

    private var windowSizeRow: some View {
        HStack(spacing: Tokens.spacing(.md)) {
            labeled("Window width") {
                Stepper(value: $windowWidth, in: 320...2048, step: 10) {
                    Text("\(windowWidth) pt").font(Typography.chromeSmall)
                }
            }
            labeled("Window height") {
                Stepper(value: $windowHeight, in: 240...1536, step: 10) {
                    Text("\(windowHeight) pt").font(Typography.chromeSmall)
                }
            }
        }
    }

    private var locationRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder")
                .foregroundStyle(Tokens.color(.textTertiary))
            Text("Project lives at:")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
            Text(projectLocationPreview)
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textPrimary))
        }
    }

    private var buttons: some View {
        HStack {
            Spacer()
            LutinButton("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            LutinButton("Create", role: .primary, action: create)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
        }
        .padding(Tokens.spacing(.md))
    }

    private func labeled<Content: View>(_ label: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
            content()
        }
    }

    private var isValid: Bool {
        !projectName.trimmingCharacters(in: .whitespaces).isEmpty
            && !bundleId.trimmingCharacters(in: .whitespaces).isEmpty
            && !appPath.isEmpty
    }

    private var projectLocationPreview: String {
        let slug = ProjectBootstrap.slugify(projectName)
        return slug.isEmpty ? "~/Lutin/<name>/" : "~/Lutin/\(slug)/"
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        ingest(appURL: url)
    }

    private func ingest(appURL: URL) {
        appPath = appURL.path
        // Read the Info.plist. On success, overwrite name + bundleId from
        // the real values. On failure, fall back to filename slug + suggested
        // bundle id and surface a soft warning.
        do {
            let meta = try AppBundleInfo.read(appURL)
            projectName = meta.displayName
            bundleId = meta.bundleIdentifier
            appVersion = meta.shortVersion
            appBuild = meta.build
            error = nil
        } catch {
            let fallback = appURL.deletingPathExtension().lastPathComponent
            projectName = fallback
            bundleId = ProjectBootstrap.suggestedBundleId(for: fallback)
            appVersion = nil
            appBuild = nil
            self.error = "Couldn't read Info.plist (\(String(describing: error))). Using filename fallback."
        }
    }

    private func create() {
        do {
            let trimmedName = projectName.trimmingCharacters(in: .whitespaces)
            let inputs = ProjectBootstrap.Inputs(
                projectName: trimmedName,
                bundleId: bundleId.trimmingCharacters(in: .whitespaces),
                appPath: appPath,
                windowWidth: windowWidth,
                windowHeight: windowHeight)
            let url = try ProjectBootstrap.create(inputs: inputs)
            onCreate(url, trimmedName)
            dismiss()
        } catch {
            self.error = String(describing: error)
        }
    }
}

import SwiftUI
import AppKit
import LutinDocument

/// Modal sheet for creating a brand-new project. Writes `lutin.yml` under
/// `~/Lutin/<slug>/` via `ProjectBootstrap.create(...)` and hands the
/// resulting URL back to the workspace via `onCreate`.
public struct CreateProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (URL, String) -> Void

    @State private var projectName: String = ""
    @State private var bundleId: String = ""
    @State private var appPath: String = ""
    @State private var windowWidth: Int = 680
    @State private var windowHeight: Int = 420
    @State private var error: String?

    public init(onCreate: @escaping (URL, String) -> Void) {
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
        .frame(width: 520)
        .background(Tokens.color(.sheetBackground))
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
            labeled("Project name") {
                TextField("", text: Binding(
                    get: { projectName },
                    set: { v in
                        projectName = v
                        // Auto-suggest bundle id only while user hasn't
                        // diverged from the default reverse-DNS shape.
                        if bundleId.isEmpty || bundleId.hasPrefix("com.example.") {
                            bundleId = ProjectBootstrap.suggestedBundleId(for: v)
                        }
                    }))
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
            labeled("App bundle (.app)") {
                HStack {
                    Text(appPath.isEmpty ? "Not chosen" : appPath)
                        .font(Typography.chromeSmall)
                        .foregroundStyle(appPath.isEmpty
                                         ? Tokens.color(.textTertiary)
                                         : Tokens.color(.textPrimary))
                        .lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(SquareShape().stroke(Tokens.color(.divider),
                                                         lineWidth: Tokens.Size.hairline))
                    Button("Choose…", action: pickApp)
                }
            }
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
            if let error {
                Text(error)
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.logError))
            }
        }
        .padding(Tokens.spacing(.md))
    }

    private var buttons: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Create", action: create)
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
        guard panel.runModal() == .OK, let url = panel.url else { return }
        appPath = url.path
        // Auto-fill name + bundle id from the picked .app if empty.
        if projectName.isEmpty {
            projectName = url.deletingPathExtension().lastPathComponent
            bundleId = ProjectBootstrap.suggestedBundleId(for: projectName)
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

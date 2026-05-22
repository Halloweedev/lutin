import SwiftUI
import AppKit
import LutinDocument

public struct ProjectTab: View {
    @Bindable var document: LutinProjectDocument
    public init(document: LutinProjectDocument) { self.document = document }

    public var body: some View {
        Form {
            Section {
                TextField("Project name", text: Binding(
                    get: { document.config.project.name },
                    set: { try? document.apply(.setProjectMetadata(name: $0,
                                                                    bundleId: document.config.project.bundleId)) }))
                TextField("Bundle identifier", text: Binding(
                    get: { document.config.project.bundleId },
                    set: { try? document.apply(.setProjectMetadata(name: document.config.project.name,
                                                                    bundleId: $0)) }))
                HStack {
                    Text("App path")
                    Spacer()
                    Text(document.config.app.path).lineLimit(1).truncationMode(.middle)
                        .foregroundStyle(Tokens.color(.textSecondary))
                    Button("Choose…", action: pickApp)
                }
            } header: { Text("Identity").font(Typography.chromeSmall) }

            Section {
                HStack {
                    Text("Directory")
                    Spacer()
                    Text(document.config.output.directory).lineLimit(1).truncationMode(.middle)
                        .foregroundStyle(Tokens.color(.textSecondary))
                    Button("Choose…", action: pickOutputDir)
                }
                TextField("DMG name", text: Binding(
                    get: { document.config.output.dmgName },
                    set: { try? document.apply(.setOutput(directory: document.config.output.directory,
                                                          dmgName: $0,
                                                          volumeName: document.config.output.volumeName)) }))
                Text("Tokens: ${version}, ${build}")
                    .font(Typography.chromeSmall).foregroundStyle(Tokens.color(.textTertiary))
                TextField("Volume name", text: Binding(
                    get: { document.config.output.volumeName },
                    set: { try? document.apply(.setOutput(directory: document.config.output.directory,
                                                          dmgName: document.config.output.dmgName,
                                                          volumeName: $0)) }))
            } header: { Text("Output").font(Typography.chromeSmall) }
        }
        .formStyle(.grouped)
        .background(Tokens.color(.panelBackground))
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
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

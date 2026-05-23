import SwiftUI
import AppKit
import LutinDocument

public struct ProjectTab: View {
    @Bindable var document: LutinProjectDocument
    public init(document: LutinProjectDocument) { self.document = document }

    public var body: some View {
        TabBody {
            SettingsSection("Identity") {
                SettingsField("Project name") {
                    SettingsTextField("MyApp", text: Binding(
                        get: { document.config.project.name },
                        set: { try? document.apply(.setProjectMetadata(
                            name: $0,
                            bundleId: document.config.project.bundleId)) }))
                }
                SettingsField("Bundle identifier",
                              helper: "Reverse-DNS, e.g. com.example.myapp") {
                    SettingsTextField("com.example.myapp", text: Binding(
                        get: { document.config.project.bundleId },
                        set: { try? document.apply(.setProjectMetadata(
                            name: document.config.project.name,
                            bundleId: $0)) }))
                }
                SettingsField("App bundle") {
                    PathPickerRow(value: document.config.app.path,
                                  placeholder: "No .app chosen",
                                  onPick: pickApp)
                }
            }

            SettingsSection("Output",
                            footer: "DMG name supports ${version} and ${build} tokens, filled at build time.") {
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

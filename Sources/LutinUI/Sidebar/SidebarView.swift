import SwiftUI
import LutinCore
import LutinRegistry
import LutinDocument

public struct SidebarView: View {
    @Bindable public var registryStore: RegistryStore
    @Binding public var selectedEntryName: String?

    public init(registryStore: RegistryStore, selectedEntryName: Binding<String?>) {
        self.registryStore = registryStore
        self._selectedEntryName = selectedEntryName
    }

    public var body: some View {
        List(selection: $selectedEntryName) {
            Section {
                ForEach(registryStore.entries, id: \.entry.name) { status in
                    SidebarRow(status: status)
                        .tag(status.entry.name as String?)
                }
            } header: {
                Text("Projects")
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .lutinGlassBackground()
        .frame(minWidth: 180, idealWidth: 220)
        .task { try? registryStore.reload() }
    }
}

private struct SidebarRow: View {
    let status: RegistryEntryStatus

    var body: some View {
        HStack(spacing: Tokens.spacing(.md)) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Tokens.color(.brandAccentSubtle))
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(status.entry.name)
                    .font(Typography.chromeSmall)
                Text(status.entry.appPath)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if status.status == .missing {
                Circle().fill(Tokens.color(.logError)).frame(width: 6, height: 6)
                    .help("App bundle is missing on disk")
            }
        }
        .padding(.vertical, Tokens.spacing(.xs))
    }
}

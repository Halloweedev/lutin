import SwiftUI
import LutinRegistry
import LutinDocument

public enum ProjectSwitcherFilter {
    public static func filter(_ entries: [RegistryEntry], query: String) -> [RegistryEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter {
            $0.name.lowercased().contains(q)
                || $0.configPath.lowercased().contains(q)
        }
    }
}

public struct ProjectSwitcherModal: View {
    @Environment(RegistryStore.self) private var registryStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEntryName: String?
    @State private var query = ""
    @State private var highlightedIndex = 0

    public init(selectedEntryName: Binding<String?>) {
        self._selectedEntryName = selectedEntryName
    }

    public var body: some View {
        VStack(spacing: 0) {
            TextField("Search projects…", text: $query)
                .textFieldStyle(.plain)
                .font(Typography.chrome)
                .padding(Tokens.spacing(.md))
                .background(Tokens.color(.sheetBackground))
            Divider().frame(height: Tokens.Size.hairline).background(Tokens.color(.divider))
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.name) { idx, entry in
                            entryRow(entry, isHighlighted: idx == highlightedIndex)
                                .id(entry.name)
                                .onTapGesture { open(entry.name) }
                        }
                    }
                }
                .onChange(of: highlightedIndex) { _, new in
                    if let target = filtered[safe: new] {
                        proxy.scrollTo(target.name, anchor: .center)
                    }
                }
            }
            Divider().frame(height: Tokens.Size.hairline).background(Tokens.color(.divider))
            Button(action: addProject) {
                HStack {
                    Image(systemName: "plus.square")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Tokens.color(.brandAccent))
                        .frame(width: 24, height: 24)
                    Text("Add project…").font(Typography.chrome)
                        .foregroundStyle(Tokens.color(.textPrimary))
                    Spacer()
                }
                .padding(Tokens.spacing(.md))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 480, height: 360)
        .background(Tokens.color(.sheetBackground))
        .onKeyPress(.return) { open(filtered[safe: highlightedIndex]?.name); return .handled }
        .onKeyPress(.escape) { dismiss(); return .handled }
        .onKeyPress(.upArrow) {
            highlightedIndex = max(0, highlightedIndex - 1); return .handled
        }
        .onKeyPress(.downArrow) {
            highlightedIndex = min(filtered.count - 1, highlightedIndex + 1); return .handled
        }
    }

    private var filtered: [RegistryEntry] {
        ProjectSwitcherFilter.filter(registryStore.entries.map(\.entry), query: query)
    }

    private func entryRow(_ entry: RegistryEntry, isHighlighted: Bool) -> some View {
        HStack(spacing: Tokens.spacing(.sm)) {
            ZStack {
                SquareShape()
                    .stroke(Tokens.color(.divider),
                            lineWidth: Tokens.Size.hairline)
                    .frame(width: 24, height: 24)
                Text(String(entry.name.prefix(1)).uppercased())
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textSecondary))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(Typography.chrome)
                    .foregroundStyle(Tokens.color(.textPrimary))
                Text(entry.configPath).font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textSecondary))
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.lastOpenedDate, format: .relative(presentation: .named))
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
                if let version = entry.lastDetectedVersion {
                    Text(version)
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textTertiary))
                }
            }
        }
        .padding(.horizontal, Tokens.spacing(.md))
        .padding(.vertical, Tokens.spacing(.sm))
        .background(isHighlighted ? Tokens.color(.brandAccentMuted) : Color.clear)
    }

    private func open(_ name: String?) {
        guard let name else { return }
        selectedEntryName = name
        dismiss()
    }

    private func addProject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.yaml]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            try? registryStore.add(configURL: url)
            selectedEntryName = url.deletingLastPathComponent().lastPathComponent
            dismiss()
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

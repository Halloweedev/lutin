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
    let onAddNewProject: () -> Void
    @State private var query = ""
    @State private var highlightedIndex = 0

    public init(selectedEntryName: Binding<String?>,
                onAddNewProject: @escaping () -> Void) {
        self._selectedEntryName = selectedEntryName
        self.onAddNewProject = onAddNewProject
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
            Button(action: addNewProject) {
                HStack(spacing: Tokens.spacing(.sm)) {
                    Image(systemName: "plus.square")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Tokens.color(.brandAccent))
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New project from .app…").font(Typography.chrome)
                            .foregroundStyle(Tokens.color(.textPrimary))
                        Text("Pick a .app bundle to bootstrap a fresh project")
                            .font(Typography.chromeSmall)
                            .foregroundStyle(Tokens.color(.textSecondary))
                    }
                    Spacer()
                    Text("⌘N").font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textTertiary))
                }
                .padding(Tokens.spacing(.md))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Divider().frame(height: Tokens.Size.hairline).background(Tokens.color(.divider))
            Button(action: linkExistingProject) {
                HStack(spacing: Tokens.spacing(.sm)) {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Tokens.color(.textSecondary))
                        .frame(width: 24, height: 24)
                    Text("Link existing lutin.yml…").font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textSecondary))
                    Spacer()
                }
                .padding(.horizontal, Tokens.spacing(.md))
                .padding(.vertical, Tokens.spacing(.sm))
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

    /// Primary "Add" path: dismiss the switcher and ask the workspace to
    /// open the Create-new-project sheet (which starts by picking a .app).
    /// Aligns the verb "Add a project" with creating one from scratch
    /// instead of indexing an existing yml.
    private func addNewProject() {
        dismiss()
        onAddNewProject()
    }

    /// Secondary path for the rare case the user has a lutin.yml lying
    /// around (e.g. cloned from another machine or hand-written) and
    /// wants to register it without recreating it.
    private func linkExistingProject() {
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

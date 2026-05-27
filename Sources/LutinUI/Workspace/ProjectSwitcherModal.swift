import SwiftUI
import AppKit
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
    /// Entry currently under the cursor — used to show its trash button.
    @State private var hoveredEntryName: String?
    /// Non-nil while the delete confirmation sheet is presented. Wrapped
    /// in a tiny Identifiable type because `RegistryEntry` itself is not
    /// Identifiable in LutinRegistry and we don't want a retroactive
    /// conformance to bleed across modules.
    @State private var deleteCandidate: DeleteRequest?

    private struct DeleteRequest: Identifiable {
        let entry: RegistryEntry
        var id: String { entry.name }
    }

    public init(selectedEntryName: Binding<String?>,
                onAddNewProject: @escaping () -> Void) {
        self._selectedEntryName = selectedEntryName
        self.onAddNewProject = onAddNewProject
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                // 12pt glyph + ~6pt gap = ~18pt clearance for the text field's content.
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Tokens.color(.textTertiary))
                    .allowsHitTesting(false)
                    .padding(.leading, Tokens.spacing(.md) + 4)
                LutinTextField("Search projects by name or path…",
                               text: $query,
                               font: .system(size: 14))
                    .padding(.leading, Tokens.spacing(.md) + 22)
            }
            .padding(Tokens.spacing(.md))
            .background(Tokens.color(.sheetBackground))
            Divider().frame(height: Tokens.Size.hairline)
                .background(Tokens.color(.divider))
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
            LutinButton(role: .secondary, action: addNewProject) {
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
            Divider().frame(height: Tokens.Size.hairline).background(Tokens.color(.divider))
            LutinButton(role: .secondary, action: linkExistingProject) {
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
        .sheet(item: $deleteCandidate) { request in
            DeleteProjectSheet(entry: request.entry, onConfirm: { alsoTrash in
                performDelete(entry: request.entry, alsoTrashFolder: alsoTrash)
            })
        }
    }

    private var filtered: [RegistryEntry] {
        ProjectSwitcherFilter.filter(registryStore.entries.map(\.entry), query: query)
    }

    private func entryRow(_ entry: RegistryEntry, isHighlighted: Bool) -> some View {
        let isHovered = hoveredEntryName == entry.name
        return HStack(spacing: Tokens.spacing(.sm)) {
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
            // Trash button revealed on hover so the row stays calm by
            // default but the delete affordance is one mouse-move away.
            // Reserve the slot at all times so hovering doesn't reflow
            // the row (which would itself cancel the hover).
            ZStack {
                if isHovered {
                    LutinIconButton(systemName: "trash",
                                    accessibilityLabel: "Delete \(entry.name) from project list",
                                    action: { deleteCandidate = DeleteRequest(entry: entry) })
                        .help("Delete \(entry.name)…")
                }
            }
            .frame(width: 24, height: 24)
        }
        .padding(.horizontal, Tokens.spacing(.md))
        .padding(.vertical, Tokens.spacing(.sm))
        .background(isHighlighted ? Tokens.color(.brandAccentMuted) : Color.clear)
        .lutinHitTarget()
        .onHover { hovering in
            if hovering { hoveredEntryName = entry.name }
            else if hoveredEntryName == entry.name { hoveredEntryName = nil }
        }
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

    /// Confirmed deletion. If the entry being deleted is currently open
    /// (matches `selectedEntryName`), the binding is cleared first so the
    /// workspace unloads it before the registry row vanishes. Trashing
    /// the folder is best-effort — failures surface via the registry
    /// reload error path but don't block the registry removal.
    private func performDelete(entry: RegistryEntry, alsoTrashFolder: Bool) {
        if alsoTrashFolder {
            let folder = URL(fileURLWithPath: entry.configPath)
                .deletingLastPathComponent()
            var resulting: NSURL?
            try? FileManager.default.trashItem(at: folder,
                                               resultingItemURL: &resulting)
        }
        try? registryStore.remove(name: entry.name)
        if selectedEntryName == entry.name {
            selectedEntryName = nil
        }
        deleteCandidate = nil
    }
}

/// Inline confirmation sheet for deleting a project. Shown on top of the
/// switcher modal — SwiftUI on macOS supports nested sheets. The "also
/// move folder to Trash" toggle defaults to off so the safe path
/// (unregister only) is one Return-key away.
private struct DeleteProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: RegistryEntry
    let onConfirm: (_ alsoTrashFolder: Bool) -> Void
    @State private var alsoTrashFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
            HStack(spacing: Tokens.spacing(.sm)) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(Tokens.color(.logError))
                Text("Delete \(entry.name)?").font(Typography.chrome)
                    .foregroundStyle(Tokens.color(.textPrimary))
            }
            Text("Removes this project from your list. The `lutin.yml` and "
               + "the rest of its folder stay on disk unless you opt in below.")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            // Folder path the toggle would trash, so the user can see
            // what's at risk before flipping the checkbox.
            let folderPath = URL(fileURLWithPath: entry.configPath)
                .deletingLastPathComponent().path
            LutinToggle("Also move project folder to Trash",
                        isOn: $alsoTrashFolder)
            Text(folderPath)
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textTertiary))
                .lineLimit(1).truncationMode(.middle)
            HStack(spacing: Tokens.spacing(.sm)) {
                Spacer()
                LutinButton("Cancel", role: .secondary) { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                // The design system has no `.destructive` role; the trash
                // icon + "Delete" label + the leading red trash glyph in
                // the header carry the destructive signal. Using
                // `.primary` keeps Return-as-default behavior intact.
                LutinButton("Delete", role: .primary) {
                    onConfirm(alsoTrashFolder)
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(Tokens.spacing(.lg))
        .frame(width: 420)
        .background(Tokens.color(.sheetBackground))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

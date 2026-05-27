import SwiftUI
import AppKit
import LutinRegistry
import LutinDocument

public enum ProjectSwitcherFilter {
    /// Predicate used by both the `[RegistryEntry]` and
    /// `[RegistryEntryStatus]` overloads — keeps the lowered-case
    /// `contains` semantics in one place.
    private static func matches(name: String, configPath: String, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return true }
        return name.lowercased().contains(q)
            || configPath.lowercased().contains(q)
    }

    public static func filter(_ entries: [RegistryEntry], query: String) -> [RegistryEntry] {
        entries.filter { matches(name: $0.name,
                                 configPath: $0.configPath,
                                 query: query) }
    }

    public static func filter(_ statuses: [RegistryEntryStatus], query: String) -> [RegistryEntryStatus] {
        statuses.filter { matches(name: $0.entry.name,
                                  configPath: $0.entry.configPath,
                                  query: query) }
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
            if !filteredStatuses.isEmpty {
                scopeStrip
            }
            ScrollViewReader { proxy in
                if filteredStatuses.isEmpty {
                    emptyStateView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredStatuses.enumerated()),
                                    id: \.element.entry.name) { idx, status in
                                entryRow(status,
                                         isHighlighted: idx == highlightedIndex)
                                    .id(status.entry.name)
                                    .onTapGesture { open(status.entry.name) }
                            }
                        }
                    }
                    .onChange(of: highlightedIndex) { _, new in
                        if let target = filteredStatuses[safe: new] {
                            proxy.scrollTo(target.entry.name, anchor: .center)
                        }
                    }
                }
            }
            Divider().frame(height: Tokens.Size.hairline)
                .background(Tokens.color(.divider))
            VStack(spacing: Tokens.spacing(.sm)) {
                LutinButton(role: .secondary, action: addNewProject) {
                    HStack(spacing: Tokens.spacing(.sm)) {
                        ZStack {
                            Rectangle()
                                .fill(Tokens.color(.brandAccentMuted))
                                .frame(width: 24, height: 24)
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Tokens.color(.brandAccent))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("New project from .app")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Tokens.color(.textPrimary))
                            Text("Drop or pick a .app — we scaffold the rest.")
                                .font(.system(size: 11))
                                .foregroundStyle(Tokens.color(.textTertiary))
                        }
                        Spacer()
                        Text("⌘N")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Tokens.color(.brandAccent))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Tokens.color(.brandAccentMuted))
                    }
                    .padding(Tokens.spacing(.sm))
                    .overlay(SquareShape()
                        .stroke(Tokens.color(.brandAccent),
                                lineWidth: Tokens.Size.hairline))
                }
                Text("already have a lutin.yml? Link it →")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.color(.textTertiary))
                    .textLink(action: linkExistingProject)
            }
            .padding(Tokens.spacing(.md))
            .background(Tokens.color(.sheetBackground))
        }
        .frame(width: 520, height: 420)
        .background(Tokens.color(.sheetBackground))
        .onKeyPress(.return) { open(filteredStatuses[safe: highlightedIndex]?.entry.name); return .handled }
        .onKeyPress(.escape) { dismiss(); return .handled }
        .onKeyPress(.upArrow) {
            highlightedIndex = max(0, highlightedIndex - 1); return .handled
        }
        .onKeyPress(.downArrow) {
            highlightedIndex = max(0, min(filteredStatuses.count - 1, highlightedIndex + 1)); return .handled
        }
        .onChange(of: filteredStatuses.count) { _, _ in
            highlightedIndex = 0
        }
        .sheet(item: $deleteCandidate) { request in
            DeleteProjectSheet(entry: request.entry, onConfirm: { alsoTrash in
                performDelete(entry: request.entry, alsoTrashFolder: alsoTrash)
            })
        }
    }

    private var scopeStrip: some View {
        HStack {
            Text("RECENT · \(filteredStatuses.count)")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Tokens.color(.textTertiary))
            Spacer()
            Text("↑↓ navigate · ↩ open · ⌫ delete")
                .font(.system(size: 10.5))
                .foregroundStyle(Tokens.color(.textTertiary))
        }
        .padding(.horizontal, Tokens.spacing(.md))
        .padding(.top, Tokens.spacing(.sm))
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        VStack(spacing: Tokens.spacing(.sm)) {
            Image(systemName: q.isEmpty ? "tray" : "questionmark.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Tokens.color(.brandAccent))
            Text(q.isEmpty ? "No projects yet" : "No projects match \"\(q)\"")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Tokens.color(.textPrimary))
            if q.isEmpty {
                Text("Drop or pick a .app to start one.")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.color(.textTertiary))
            }
        }
        .padding(.vertical, Tokens.spacing(.xl))
    }

    private var filteredStatuses: [RegistryEntryStatus] {
        ProjectSwitcherFilter.filter(registryStore.entries, query: query)
    }

    private func entryRow(_ status: RegistryEntryStatus,
                          isHighlighted: Bool) -> some View {
        let entry = status.entry
        let isHovered = hoveredEntryName == entry.name
        return HStack(spacing: Tokens.spacing(.sm)) {
            ProjectIconTile(name: entry.name,
                            appPath: entry.appPath,
                            sizePoints: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.color(.textPrimary))
                Text(entry.configPath.collapsedHome)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Tokens.color(.textTertiary))
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            metaColumn(entry: entry, isMissing: status.status == .missing)
            // Trash button revealed on hover so the row stays calm by
            // default but the delete affordance is one mouse-move away.
            // Reserve the slot at all times so hovering doesn't reflow
            // the row (which would itself cancel the hover).
            ZStack {
                if isHovered {
                    LutinIconButton(systemName: "trash",
                                    accessibilityLabel:
                                        "Delete \(entry.name) from project list",
                                    action: { deleteCandidate =
                                        DeleteRequest(entry: entry) })
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

    private func metaColumn(entry: RegistryEntry, isMissing: Bool) -> some View {
        let relativeDate = entry.lastOpenedDate
            .formatted(.relative(presentation: .numeric))
        let kind = RegistryEntryStatusKind.resolve(
            entry: entry, isMissingOnDisk: isMissing)
        return HStack(spacing: 6) {
            Circle()
                .fill(kind.dotColor)
                .frame(width: 6, height: 6)
            // Compact one-liner: "● 2d · v1.4.2"
            // We intentionally omit the build-outcome verb ("built",
            // "failed") here — the dot color carries the signal, and
            // the switcher row needs to scan tightly. The Welcome card
            // includes the verb because it has more horizontal room.
            Text(metaText(relativeDate: relativeDate,
                          version: entry.lastDetectedVersion))
                .font(.system(size: 10.5))
                .foregroundStyle(Tokens.color(.textTertiary))
                .lineLimit(1)
        }
    }

    private func metaText(relativeDate: String, version: String?) -> String {
        if let v = version, !v.isEmpty { return "\(relativeDate) · \(v)" }
        return relativeDate
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

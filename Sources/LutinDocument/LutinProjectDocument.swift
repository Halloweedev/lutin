import Foundation
import Observation
import LutinCore
import LutinConfig

@Observable
public final class LutinProjectDocument: Identifiable {
    public let id = UUID()
    public private(set) var config: LutinConfig
    public let configURL: URL
    public let projectDirectory: URL
    public private(set) var isDirty: Bool = false
    public private(set) var pendingConflict: ConflictResolver?

    @ObservationIgnored
    public let undoManager = UndoManager()

    @ObservationIgnored
    private var autosaveTimer: Timer?

    /// Watches `configURL` for external rewrites — supports the
    /// agent-edit-on-disk → canvas-reflects-it loop without an
    /// app reopen. Self-writes are filtered out by the watcher's own
    /// cool-down (see `ConfigFileWatcher.noteSelfWrite`). External
    /// changes post `.lutinDocumentReloadedFromDisk` so the UI can
    /// surface a "reloaded" badge.
    @ObservationIgnored
    private var fileWatcher: ConfigFileWatcher?

    // Autosave is always on. Edits from the side-panel tabs (and any
    // other intent path) schedule a debounced save automatically — the
    // user shouldn't have to remember ⌘S for what reads as a settings
    // surface. Existing `preferences.json` files can still carry the
    // now-defunct `autosave` key; JSONDecoder ignores unknown fields
    // and the value is dropped on next re-save.

    public init(configURL: URL) throws {
        self.configURL = configURL.standardizedFileURL
        self.projectDirectory = configURL.deletingLastPathComponent().standardizedFileURL
        do {
            self.config = try LutinConfig.load(from: configURL)
        } catch let error as LutinError {
            throw error
        } catch {
            throw LutinError(code: "config_load_failed",
                             message: "Could not load \(configURL.path): \(error.localizedDescription)")
        }
        // One-shot load-time normalization: clean up known-invalid
        // states in the YAML so the rest of the app can assume a
        // self-consistent config. Currently only `background.type ==
        // "image"` with no `path` — that combination can't render and
        // would otherwise need defensive fallbacks at every reader.
        // We only normalize on initial load; the hot-reload path
        // (`ConfigFileWatcher`) leaves the disk state alone so an
        // agent mid-edit (write type first, write path next) isn't
        // clobbered.
        normalizeOnLoad()
        // Wire up hot-reload. The closure hops to the main actor
        // (via DispatchQueue.main inside ConfigFileWatcher) so it's
        // safe to mutate `config` here.
        let url = self.configURL
        fileWatcher = ConfigFileWatcher(url: url) { [weak self] in
            guard let self else { return }
            // Swallow load failures — they typically mean the file was
            // caught mid-write. The next event delivers the settled
            // state, and a partial-YAML error wouldn't be actionable
            // for the user anyway.
            do {
                try self.reloadFromDisk()
                NotificationCenter.default.post(
                    name: .lutinDocumentReloadedFromDisk, object: self)
            } catch {
                // Intentionally silent — see comment above.
            }
        }
        fileWatcher?.start()
    }

    deinit {
        fileWatcher?.stop()
    }

    public func apply(_ intent: DocumentIntent) throws {
        let previous = config
        switch intent {
        case .moveItem(let id, let x, let y):
            mutateItem(id: id) { $0.x = x; $0.y = y }
        case .renameItemLabel(let id, let label):
            mutateItem(id: id) { $0.label = label }
        case .addItem(let item):
            config.items = (config.items ?? []) + [item]
        case .deleteItem(let id):
            config.items?.removeAll { $0.id == id }
        case .setProjectName(let name):
            config.project.name = name
        case .setOutputDirectory(let dir):
            config.output.directory = dir
        case .setBackgroundTemplate(let template):
            if config.background == nil {
                config.background = LutinConfig.BackgroundInfo(
                    type: nil, template: template, path: nil, scale: nil,
                    colorA: nil, colorB: nil, grid: nil, noise: nil, cornerRadius: nil)
            } else {
                config.background?.template = template
            }
        case .setIconSize(let size):
            let clamped = max(16, min(512, size))
            if config.window == nil {
                config.window = LutinConfig.WindowInfo(
                    width: nil, height: nil, iconSize: clamped, textSize: nil,
                    showToolbar: nil, showSidebar: nil)
            } else {
                config.window?.iconSize = clamped
            }
        case .moveMany(let deltas):
            guard !deltas.isEmpty else { return }
            // Pre-validate all deltas before mutating
            for delta in deltas {
                switch delta.target {
                case .item(let id):
                    guard config.items?.contains(where: { $0.id == id }) ?? false else {
                        throw LutinError(code: "editor_item_not_found",
                                         message: "Item '\(id)' not found")
                    }
                case .imageDecoration(let i):
                    guard let decos = config.decorations, i >= 0, i < decos.count,
                          decos[i].type == "image" else {
                        throw LutinError(code: "editor_image_not_found",
                                         message: "Image decoration at index \(i) not found")
                    }
                }
            }
            // Apply all deltas
            var newConfig = config
            for delta in deltas {
                switch delta.target {
                case .item(let id):
                    guard let idx = newConfig.items?.firstIndex(where: { $0.id == id }) else { continue }
                    newConfig.items?[idx].x += delta.dx
                    newConfig.items?[idx].y += delta.dy
                case .imageDecoration(let i):
                    if var decos = newConfig.decorations {
                        decos[i].x = (decos[i].x ?? 0) + delta.dx
                        decos[i].y = (decos[i].y ?? 0) + delta.dy
                        newConfig.decorations = decos
                    }
                }
            }
            config = newConfig

        case .deleteSelection(let targets):
            guard !targets.isEmpty else { return }
            var newConfig = config
            // Delete image decorations by descending index so earlier
            // indices stay valid.
            let decoIndices: [Int] = targets.compactMap { t -> Int? in
                if case .imageDecoration(let i) = t { return i }
                return nil
            }.sorted(by: >)
            for i in decoIndices {
                guard let decos = newConfig.decorations, i >= 0, i < decos.count else { continue }
                newConfig.decorations?.remove(at: i)
            }
            let itemIDs = Set(targets.compactMap { t -> String? in
                if case .item(let id) = t { return id } else { return nil }
            })
            if !itemIDs.isEmpty {
                newConfig.items?.removeAll { itemIDs.contains($0.id) }
            }
            commit(newConfig: newConfig, undoLabel: "Delete")
            return

        case .setItemHidden(let id, let hidden):
            var newConfig = config
            guard let idx = newConfig.items?.firstIndex(where: { $0.id == id }) else {
                throw LutinError(code: "editor_item_not_found", message: "Item '\(id)' not found")
            }
            newConfig.items?[idx].hidden = hidden
            commit(newConfig: newConfig, undoLabel: hidden ? "Hide" : "Show")
            return

        case .setImageHidden(let index, let hidden):
            var newConfig = config
            guard let decos = newConfig.decorations, index >= 0, index < decos.count,
                  decos[index].type == "image" else {
                throw LutinError(code: "editor_image_not_found",
                                 message: "Image decoration at index \(index) not found")
            }
            newConfig.decorations?[index].hidden = hidden
            commit(newConfig: newConfig, undoLabel: hidden ? "Hide" : "Show")
            return

        case .setItemID(let old, let new):
            let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw LutinError(code: "editor_invalid_id", message: "Item id cannot be empty")
            }
            var newConfig = config
            guard let idx = newConfig.items?.firstIndex(where: { $0.id == old }) else {
                throw LutinError(code: "editor_item_not_found", message: "Item '\(old)' not found")
            }
            if newConfig.items?.contains(where: { $0.id == trimmed && $0.id != old }) == true {
                throw LutinError(code: "editor_id_collision",
                                 message: "Item id '\(trimmed)' already exists")
            }
            newConfig.items?[idx].id = trimmed
            commit(newConfig: newConfig, undoLabel: "Rename")
            return

        case .addImageDecoration(let path, let x, let y, let width, let height):
            var newConfig = config
            let deco = LutinConfig.Decoration(type: "image", path: path, x: x, y: y,
                                              width: width, height: height)
            if newConfig.decorations == nil { newConfig.decorations = [] }
            newConfig.decorations?.append(deco)
            commit(newConfig: newConfig, undoLabel: "Add image")
            return

        case .deleteImageDecoration(let index):
            var newConfig = config
            guard let decos = newConfig.decorations, index >= 0, index < decos.count,
                  decos[index].type == "image" else {
                throw LutinError(code: "editor_image_not_found",
                                 message: "Image decoration at index \(index) not found")
            }
            newConfig.decorations?.remove(at: index)
            commit(newConfig: newConfig, undoLabel: "Delete image")
            return

        case .moveImageDecoration(let index, let x, let y, let width, let height):
            var newConfig = config
            guard let decos = newConfig.decorations, index >= 0, index < decos.count,
                  decos[index].type == "image" else {
                throw LutinError(code: "editor_image_not_found",
                                 message: "Image decoration at index \(index) not found")
            }
            newConfig.decorations?[index].x = x
            newConfig.decorations?[index].y = y
            newConfig.decorations?[index].width = width
            // `nil` means "leave unchanged" (matching setWindow), so a
            // reposition that omits height doesn't wipe an explicit stretch
            // and editing width keeps an aspect-locked image aspect-locked.
            if let height { newConfig.decorations?[index].height = height }
            commit(newConfig: newConfig, undoLabel: "Move image")
            return

        case .reorderItem(let id, let toIndex):
            var newConfig = config
            guard var items = newConfig.items,
                  let fromIdx = items.firstIndex(where: { $0.id == id }) else {
                throw LutinError(code: "editor_item_not_found", message: "Item '\(id)' not found")
            }
            let clamped = max(0, min(toIndex, items.count - 1))
            let item = items.remove(at: fromIdx)
            items.insert(item, at: clamped)
            newConfig.items = items
            commit(newConfig: newConfig, undoLabel: "Reorder")
            return

        case .reorderImageDecoration(let fromIndex, let toIndex):
            var newConfig = config
            guard var decos = newConfig.decorations,
                  fromIndex >= 0, fromIndex < decos.count,
                  decos[fromIndex].type == "image" else {
                throw LutinError(code: "editor_image_not_found",
                                 message: "Image decoration at index \(fromIndex) not found")
            }
            let clamped = max(0, min(toIndex, decos.count - 1))
            let d = decos.remove(at: fromIndex)
            decos.insert(d, at: clamped)
            newConfig.decorations = decos
            commit(newConfig: newConfig, undoLabel: "Reorder")
            return

        case .setWindow(let w, let h, let icon, let text, let toolbar, let sidebar):
            var newConfig = config
            if newConfig.window == nil {
                newConfig.window = LutinConfig.WindowInfo(
                    width: nil, height: nil, iconSize: nil, textSize: nil,
                    showToolbar: nil, showSidebar: nil)
            }
            if let w { newConfig.window?.width = w }
            if let h { newConfig.window?.height = h }
            if let icon { newConfig.window?.iconSize = icon }
            if let text { newConfig.window?.textSize = text }
            if let toolbar { newConfig.window?.showToolbar = toolbar }
            if let sidebar { newConfig.window?.showSidebar = sidebar }
            commit(newConfig: newConfig, undoLabel: "Window")
            return

        case .setProjectMetadata(let name, let bundleId):
            var newConfig = config
            newConfig.project.name = name
            newConfig.project.bundleId = bundleId
            commit(newConfig: newConfig, undoLabel: "Project")
            return

        case .setApp(let path):
            var newConfig = config
            newConfig.app.path = path
            commit(newConfig: newConfig, undoLabel: "App path")
            return

        case .setOutput(let dir, let dmgName, let volumeName):
            var newConfig = config
            newConfig.output.directory = dir
            newConfig.output.dmgName = dmgName
            newConfig.output.volumeName = volumeName
            commit(newConfig: newConfig, undoLabel: "Output")
            return

        case .setBackground(let bg):
            var newConfig = config
            newConfig.background = bg
            commit(newConfig: newConfig, undoLabel: "Background")
            return

        case .setSigning(let s):
            var newConfig = config
            newConfig.signing = s
            commit(newConfig: newConfig, undoLabel: "Signing")
            return

        case .setNotarization(let n):
            var newConfig = config
            newConfig.notarization = n
            commit(newConfig: newConfig, undoLabel: "Notarization")
            return

        case .setSparkle(let sp):
            var newConfig = config
            newConfig.sparkle = sp
            commit(newConfig: newConfig, undoLabel: "Sparkle")
            return

        }
        isDirty = true
        registerUndo(previous: previous)
        scheduleAutosave()
    }

    public func scheduleAutosave(after delay: TimeInterval = 0.5) {
        autosaveTimer?.invalidate()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            try? self.save()
        }
    }

    /// One-shot fix for known-invalid YAML states encountered at load
    /// time. Mutates `config` in place, marks the document dirty, and
    /// schedules an autosave so the corrected state lands on disk.
    /// Called once from `init` — NOT from the hot-reload path, where
    /// an agent mid-edit might be writing a multi-field change one
    /// field at a time and we don't want to overwrite their work.
    ///
    /// Currently fixes:
    ///   • `background.type == "image"` with no `path` → rewrite to
    ///     `type: "solid"` with a white `colorA` default, dropping
    ///     the gradient/template/noise fields that don't apply.
    private func normalizeOnLoad() {
        if let bg = config.background,
           bg.type == "image",
           (bg.path ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
            config.background = LutinConfig.BackgroundInfo(
                type: "solid",
                template: nil,
                path: nil,
                scale: bg.scale,
                colorA: bg.colorA ?? "#FFFFFF",
                colorB: nil,
                grid: nil,
                noise: nil,
                cornerRadius: bg.cornerRadius,
                angle: nil)
            isDirty = true
            scheduleAutosave()
        }
    }

    public func save() throws {
        if pendingConflict != nil {
            throw LutinError(code: SP4ErrorCodes.documentConflictUnresolved,
                             message: "Resolve the external file conflict before saving.")
        }
        // Mark before the atomic rotate so the watcher's dispatch
        // source ignores the event our own write generates. Must run
        // BEFORE `replaceItemAt`, not after, because the kernel
        // delivers the FS event from the rename almost immediately.
        fileWatcher?.noteSelfWrite()
        let tmp = configURL.appendingPathExtension("tmp")
        do {
            try config.save(to: tmp)
            _ = try FileManager.default.replaceItemAt(configURL, withItemAt: tmp)
            isDirty = false
            pendingConflict = nil
        } catch let error as LutinError {
            try? FileManager.default.removeItem(at: tmp)
            throw error
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            throw LutinError(code: "document_save_failed",
                             message: "Could not save \(configURL.path): \(error.localizedDescription)")
        }
    }

    public func reloadFromDisk() throws {
        if isDirty {
            autosaveTimer?.invalidate()
            autosaveTimer = nil
            pendingConflict = ConflictResolver(document: self)
            return
        }
        try forceReloadFromDisk()
    }

    public func forceReloadFromDisk() throws {
        config = try LutinConfig.load(from: configURL)
        isDirty = false
        pendingConflict = nil
        undoManager.removeAllActions()
    }

    func clearPendingConflict() {
        pendingConflict = nil
    }

    public func replaceConfig(_ newConfig: LutinConfig, dirty: Bool) {
        config = newConfig
        isDirty = dirty
    }

    public func undo() { undoManager.undo() }
    public func redo() { undoManager.redo() }

    // MARK: - private

    private func commit(newConfig: LutinConfig, undoLabel: String) {
        let previous = config
        config = newConfig
        isDirty = true
        undoManager.setActionName(undoLabel)
        registerUndo(previous: previous)
        scheduleAutosave()
    }

    private func mutateItem(id: String, _ mutate: (inout LutinConfig.Item) -> Void) {
        guard var items = config.items, let idx = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[idx])
        config.items = items
    }


    private func registerUndo(previous: LutinConfig) {
        undoManager.registerUndo(withTarget: self) { doc in
            let snapshot = doc.config
            doc.config = previous
            doc.isDirty = true
            doc.undoManager.registerUndo(withTarget: doc) { redoDoc in
                redoDoc.config = snapshot
                redoDoc.isDirty = true
                redoDoc.registerUndo(previous: previous)
            }
        }
    }
}

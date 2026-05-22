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

    @ObservationIgnored
    public let undoManager = UndoManager()

    @ObservationIgnored
    private var autosaveTimer: Timer?

    public var autosaveEnabled: Bool = false

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
            config.decorations?.removeAll { $0.type == "arrow" && ($0.from == id || $0.to == id) }
        case .addArrow(let from, let to, let label):
            let dec = LutinConfig.Decoration(type: "arrow", from: from, to: to, label: label)
            config.decorations = (config.decorations ?? []) + [dec]
        case .deleteArrow(let from, let to):
            config.decorations?.removeAll {
                $0.type == "arrow" && $0.from == from && $0.to == to
            }
        case .renameArrowLabel(let from, let to, let label):
            mutateArrow(from: from, to: to) { $0.label = label }
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
            // Delete image decorations by descending index so earlier indices stay valid.
            let imageIndices = targets.compactMap { t -> Int? in
                if case .imageDecoration(let i) = t { return i } else { return nil }
            }.sorted(by: >)
            for i in imageIndices {
                guard let decos = newConfig.decorations, i >= 0, i < decos.count else { continue }
                newConfig.decorations?.remove(at: i)
            }
            // Delete arrows directly named.
            for case let .arrow(from, to) in targets {
                newConfig.decorations?.removeAll {
                    $0.type == "arrow" && $0.from == from && $0.to == to
                }
            }
            // Delete items, and cascade any arrows that reference them.
            let itemIDs = Set(targets.compactMap { t -> String? in
                if case .item(let id) = t { return id } else { return nil }
            })
            if !itemIDs.isEmpty {
                newConfig.items?.removeAll { itemIDs.contains($0.id) }
                newConfig.decorations?.removeAll {
                    $0.type == "arrow"
                        && (itemIDs.contains($0.from ?? "") || itemIDs.contains($0.to ?? ""))
                }
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
            // Cascade into arrows that referenced the old id.
            if var decos = newConfig.decorations {
                for i in decos.indices where decos[i].type == "arrow" {
                    if decos[i].from == old { decos[i].from = trimmed }
                    if decos[i].to == old { decos[i].to = trimmed }
                }
                newConfig.decorations = decos
            }
            commit(newConfig: newConfig, undoLabel: "Rename")
            return

        case .addImageDecoration(let path, let x, let y, let width):
            var newConfig = config
            let deco = LutinConfig.Decoration(type: "image", path: path, x: x, y: y, width: width)
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

        case .moveImageDecoration(let index, let x, let y, let width):
            var newConfig = config
            guard let decos = newConfig.decorations, index >= 0, index < decos.count,
                  decos[index].type == "image" else {
                throw LutinError(code: "editor_image_not_found",
                                 message: "Image decoration at index \(index) not found")
            }
            newConfig.decorations?[index].x = x
            newConfig.decorations?[index].y = y
            newConfig.decorations?[index].width = width
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

        case .swapArrow(let from, let to):
            var newConfig = config
            guard var decos = newConfig.decorations,
                  let idx = decos.firstIndex(where: {
                      $0.type == "arrow" && $0.from == from && $0.to == to }) else {
                throw LutinError(code: "editor_arrow_not_found",
                                 message: "Arrow \(from)→\(to) not found")
            }
            decos[idx].from = to
            decos[idx].to = from
            newConfig.decorations = decos
            commit(newConfig: newConfig, undoLabel: "Swap arrow")
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

        case .setArrowHidden(let from, let to, let hidden):
            var newConfig = config
            guard var decos = newConfig.decorations,
                  let idx = decos.firstIndex(where: {
                      $0.type == "arrow" && $0.from == from && $0.to == to }) else {
                throw LutinError(code: "editor_arrow_not_found",
                                 message: "Arrow \(from)→\(to) not found")
            }
            decos[idx].hidden = hidden ? true : nil
            newConfig.decorations = decos
            commit(newConfig: newConfig, undoLabel: hidden ? "Hide" : "Show")
            return
        }
        isDirty = true
        registerUndo(previous: previous)
        if autosaveEnabled { scheduleAutosave() }
    }

    public func scheduleAutosave(after delay: TimeInterval = 0.5) {
        autosaveTimer?.invalidate()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            try? self.save()
        }
    }

    public func save() throws {
        let tmp = configURL.appendingPathExtension("tmp")
        do {
            try config.save(to: tmp)
            _ = try FileManager.default.replaceItemAt(configURL, withItemAt: tmp)
            isDirty = false
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
        config = try LutinConfig.load(from: configURL)
        isDirty = false
        undoManager.removeAllActions()
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
        if autosaveEnabled { scheduleAutosave() }
    }

    private func mutateItem(id: String, _ mutate: (inout LutinConfig.Item) -> Void) {
        guard var items = config.items, let idx = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[idx])
        config.items = items
    }

    private func mutateArrow(from: String, to: String, _ mutate: (inout LutinConfig.Decoration) -> Void) {
        guard var decorations = config.decorations,
              let idx = decorations.firstIndex(where: { $0.type == "arrow" && $0.from == from && $0.to == to })
        else { return }
        mutate(&decorations[idx])
        config.decorations = decorations
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

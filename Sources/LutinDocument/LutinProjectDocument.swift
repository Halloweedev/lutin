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
        }
        isDirty = true
        registerUndo(previous: previous)
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

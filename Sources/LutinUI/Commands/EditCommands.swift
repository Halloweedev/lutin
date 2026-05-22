import SwiftUI

public struct LutinCommands: Commands {
    public init() {}
    public var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Save") { NotificationCenter.default.post(name: .lutinSave, object: nil) }
                .keyboardShortcut("s", modifiers: .command)
        }
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { NotificationCenter.default.post(name: .lutinUndo, object: nil) }
                .keyboardShortcut("z", modifiers: .command)
            Button("Redo") { NotificationCenter.default.post(name: .lutinRedo, object: nil) }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        CommandMenu("Item") {
            Button("Select All") { NotificationCenter.default.post(name: .lutinSelectAll, object: nil) }
                .keyboardShortcut("a", modifiers: .command)
            Button("Deselect All") { NotificationCenter.default.post(name: .lutinClearSelection, object: nil) }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Divider()
            Button("Duplicate") { NotificationCenter.default.post(name: .lutinDuplicate, object: nil) }
                .keyboardShortcut("d", modifiers: .command)
            Button("Delete") { NotificationCenter.default.post(name: .lutinDelete, object: nil) }
                .keyboardShortcut(.delete, modifiers: [])
        }
    }
}

public extension Notification.Name {
    static let lutinSave           = Notification.Name("LutinSave")
    static let lutinUndo           = Notification.Name("LutinUndo")
    static let lutinRedo           = Notification.Name("LutinRedo")
    static let lutinDuplicate      = Notification.Name("LutinDuplicate")
    static let lutinDelete         = Notification.Name("LutinDelete")
    static let lutinSelectAll      = Notification.Name("lutinSelectAll")
    static let lutinClearSelection = Notification.Name("lutinClearSelection")
}

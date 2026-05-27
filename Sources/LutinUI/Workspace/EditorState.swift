import Foundation
import Observation
import SwiftUI

@Observable
public final class EditorState {
    public let configPath: String
    public var selectedTab: EditorTab = .design
    public var zoomPercent: Int = 100
    public var scrollOffset: CGPoint = .zero
    public init(configPath: String) { self.configPath = configPath }
}

@Observable
public final class EditorStateStore {
    private var instances: [String: EditorState] = [:]
    public init() {}
    public func state(forConfigPath path: String) -> EditorState {
        if let existing = instances[path] { return existing }
        let s = EditorState(configPath: path)
        instances[path] = s
        return s
    }
}

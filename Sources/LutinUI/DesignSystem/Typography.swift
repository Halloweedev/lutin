import SwiftUI

public enum Typography {
    public static let chrome = Font.system(.body)
    public static let chromeSmall = Font.system(.callout)
    public static let inspectorLabel = Font.system(.caption).weight(.medium)
    public static let inspectorValue = Font.system(.body, design: .rounded).monospacedDigit()
    public static let canvasLabel = Font.system(.caption2)
    public static let logLine = Font.system(.callout, design: .monospaced)
    public static let drawerStage = Font.system(.callout).weight(.medium)
}

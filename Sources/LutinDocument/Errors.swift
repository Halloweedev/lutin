import Foundation
import LutinCore

/// SP4-specific error codes layered on top of LutinError. These are stable
/// strings; the message carries the explanation.
public enum SP4ErrorCodes {
    public static let appPackagerLayoutInvalid  = "app_packager_layout_invalid"
    public static let appPackagerMissingBinary  = "app_packager_missing_binary"
    public static let documentConflictUnresolved = "document_conflict_unresolved"
    public static let documentSaveFailed         = "document_save_failed"
    public static let guiRendererFailed          = "gui_renderer_failed"
    public static let preferencesCorrupt         = "preferences_corrupt"
    public static let configLoadFailed           = "config_load_failed"
}

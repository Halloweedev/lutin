import Foundation

/// Builders for the individual `.DS_Store` record values Lutin needs.
enum DSStoreRecords {
    /// The background option carried in an `icvp` record.
    enum Background {
        case none
        case color(red: Double, green: Double, blue: Double)
        /// A background image. `alias` is the legacy Carbon alias embedded
        /// in `icvp.backgroundImageAlias`; `bookmark` is the modern CFURL
        /// bookmark written as the top-level `pBBk` record on the `.` entry.
        /// macOS 14+/26 Finder reads `pBBk` preferentially — the alias is
        /// legacy fallback and routinely ignored on its own.
        case image(alias: Data, bookmark: Data)
    }

    /// The 16-byte `Iloc` (icon location) blob: x, y, then 8 fixed bytes.
    static func ilocBlob(x: Int, y: Int) -> Data {
        var buf = ByteBuffer()
        buf.appendUInt32(UInt32(x))
        buf.appendUInt32(UInt32(y))
        buf.appendBytes(Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00]))
        return buf.data
    }

    /// The `bwsp` (browser window settings) blob — a binary plist.
    static func bwspBlob(windowWidth: Int, windowHeight: Int,
                         showSidebar: Bool, showToolbar: Bool) -> Data {
        // Window placed at (100,100) on screen; size from the layout.
        let bounds = "{{100, 100}, {\(windowWidth), \(windowHeight)}}"
        let dict: [String: Any] = [
            "WindowBounds": bounds,
            "ShowSidebar": showSidebar,
            "ShowToolbar": showToolbar,
            "ShowStatusBar": false,
            // Install DMG windows don't want the pathbar — it just shows
            // "Lutin > " at the bottom and eats content area. (On macOS 26
            // Tahoe the volume-name strip at the bottom is shown anyway and
            // is *not* controlled by this flag; LutinRenderer accounts for
            // that strip via `finderBottomChromeHeightPoints`.)
            "ShowPathbar": false,
            "ShowTabView": false,
            "SidebarWidth": 0,
            // dmgbuild's reference set also writes these two. Their absence
            // seems to leave Finder free to default-enable a preview/sidebar
            // pane on some macOS versions, so include them explicitly.
            "ContainerShowSidebar": false,
            "PreviewPaneVisibility": false,
        ]
        return serializeBinaryPlist(dict, record: "bwsp")
    }

    /// The `icvp` (icon view properties) blob — a binary plist. Apple-blessed
    /// key set mirrors what `dmgbuild` writes: notably `backgroundColor*` and
    /// `scrollPosition*` are always present, even when `backgroundType=2`
    /// (image). macOS 14+/26 Finder appears to silently discard an icvp that
    /// omits these keys, which kills both `iconSize` and the background image
    /// resolution even though everything else in the `.DS_Store` is read.
    static func icvpBlob(iconSize: Int, textSize: Int, background: Background) -> Data {
        var dict: [String: Any] = [
            "viewOptionsVersion": 1,
            "iconSize": Double(iconSize),
            "textSize": Double(textSize),
            "gridSpacing": 100.0,
            "gridOffsetX": 0.0,
            "gridOffsetY": 0.0,
            "labelOnBottom": true,
            "showIconPreview": false,            // dmgbuild's default
            "showItemInfo": false,
            "arrangeBy": "none",
            "backgroundColorRed": 1.0,
            "backgroundColorGreen": 1.0,
            "backgroundColorBlue": 1.0,
            "scrollPositionX": 0.0,
            "scrollPositionY": 0.0,
        ]
        switch background {
        case .none:
            dict["backgroundType"] = 0
        case .color(let r, let g, let b):
            dict["backgroundType"] = 1
            dict["backgroundColorRed"] = r
            dict["backgroundColorGreen"] = g
            dict["backgroundColorBlue"] = b
        case .image(let alias, _):
            dict["backgroundType"] = 2
            dict["backgroundImageAlias"] = alias
        }
        return serializeBinaryPlist(dict, record: "icvp")
    }

    /// Serializes a `.DS_Store` record dictionary to a binary plist. The
    /// dictionaries are assembled here from fixed, well-typed Foundation
    /// values, so serialization cannot fail at runtime — a failure means a
    /// future edit introduced a non-plist value, which traps loudly rather
    /// than silently emitting an empty, structurally-broken record.
    private static func serializeBinaryPlist(_ dict: [String: Any],
                                             record: String) -> Data {
        do {
            return try PropertyListSerialization.data(
                fromPropertyList: dict, format: .binary, options: 0)
        } catch {
            preconditionFailure(
                "\(record) plist is built from fixed well-typed values; "
                + "serialization must not fail: \(error)")
        }
    }
}

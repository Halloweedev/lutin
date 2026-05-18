import Foundation

/// Builders for the individual `.DS_Store` record values Lutin needs.
enum DSStoreRecords {
    /// The background option carried in an `icvp` record.
    enum Background {
        case none
        case color(red: Double, green: Double, blue: Double)
        case image(alias: Data)
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
            "ShowPathbar": true,
            "ShowTabView": false,
            "SidebarWidth": 0,
        ]
        return (try? PropertyListSerialization.data(
            fromPropertyList: dict, format: .binary, options: 0)) ?? Data()
    }

    /// The `icvp` (icon view properties) blob — a binary plist.
    static func icvpBlob(iconSize: Int, textSize: Int, background: Background) -> Data {
        var dict: [String: Any] = [
            "viewOptionsVersion": 1,
            "iconSize": Double(iconSize),
            "textSize": Double(textSize),
            "gridSpacing": 100.0,
            "gridOffsetX": 0.0,
            "gridOffsetY": 0.0,
            "labelOnBottom": true,
            "showIconPreview": true,
            "showItemInfo": false,
            "arrangeBy": "none",
        ]
        switch background {
        case .none:
            dict["backgroundType"] = 0
        case .color(let r, let g, let b):
            dict["backgroundType"] = 1
            dict["backgroundColorRed"] = r
            dict["backgroundColorGreen"] = g
            dict["backgroundColorBlue"] = b
        case .image(let alias):
            dict["backgroundType"] = 2
            dict["backgroundImageAlias"] = alias
        }
        return (try? PropertyListSerialization.data(
            fromPropertyList: dict, format: .binary, options: 0)) ?? Data()
    }
}

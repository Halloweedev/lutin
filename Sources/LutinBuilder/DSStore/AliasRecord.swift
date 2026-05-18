import Foundation

/// Encodes a version-2 Carbon alias record pointing at a file inside a mounted
/// volume. Used as the `backgroundImageAlias` value in an `icvp` record.
/// Modern macOS resolves it via the POSIX-path tags; the fixed header is
/// filled with valid-but-minimal values.
enum AliasRecord {
    /// - Parameters:
    ///   - volumeName: the DMG volume name (e.g. "Barry").
    ///   - fileName: the target file's name (e.g. "background.png").
    ///   - posixPath: absolute path of the target inside the mounted volume.
    static func encode(volumeName: String, fileName: String, posixPath: String) -> Data {
        var buf = ByteBuffer()

        // --- Fixed header ---
        buf.appendUInt32(0)                       // application info
        buf.appendUInt16(0)                       // record size — backfilled below
        buf.appendUInt16(2)                       // version
        buf.appendUInt16(0)                       // alias kind: file
        appendPascalString(&buf, volumeName, fieldLength: 27)
        buf.appendUInt32(0)                       // volume created
        buf.appendUInt8(0x48)                     // volume signature 'H' (HFS+)
        buf.appendUInt8(0x2B)                     // volume signature '+' (HFS+)
        buf.appendUInt16(5)                       // volume type
        buf.appendUInt32(0)                       // parent directory ID
        appendPascalString(&buf, fileName, fieldLength: 63)
        buf.appendUInt32(0)                       // file number
        buf.appendUInt32(0)                       // file created
        buf.appendUInt32(0)                       // file type
        buf.appendUInt32(0)                       // file creator
        buf.appendUInt16(0xFFFF)                  // nlvl from
        buf.appendUInt16(0xFFFF)                  // nlvl to
        buf.appendUInt32(0)                       // volume attributes
        buf.appendUInt16(0)                       // volume filesystem ID
        buf.appendBytes(Data(repeating: 0, count: 10))  // reserved

        // --- Tag records ---
        appendUnicodeTag(&buf, type: 0x000E, string: fileName)
        appendUnicodeTag(&buf, type: 0x000F, string: volumeName)
        appendUTF8Tag(&buf, type: 0x0012, string: posixPath)
        appendUTF8Tag(&buf, type: 0x0013, string: "/Volumes/" + volumeName)
        buf.appendUInt16(0xFFFF)                  // terminator tag type
        buf.appendUInt16(0)                       // terminator length

        // --- Backfill record size at offset 4 (2 bytes, big-endian) ---
        var data = buf.data
        let total = UInt16(data.count)
        data[4] = UInt8(truncatingIfNeeded: total >> 8)
        data[5] = UInt8(truncatingIfNeeded: total)
        return data
    }

    private static func appendPascalString(_ buf: inout ByteBuffer,
                                           _ string: String, fieldLength: Int) {
        let bytes = Array(string.utf8.prefix(fieldLength))
        buf.appendUInt8(UInt8(bytes.count))
        buf.appendBytes(Data(bytes))
        let padding = fieldLength - bytes.count
        if padding > 0 { buf.appendBytes(Data(repeating: 0, count: padding)) }
    }

    private static func appendUnicodeTag(_ buf: inout ByteBuffer,
                                         type: UInt16, string: String) {
        let unitCount = string.utf16.count
        // data = 2-byte unit count + UTF-16 BE bytes
        let dataLength = 2 + unitCount * 2
        buf.appendUInt16(type)
        buf.appendUInt16(UInt16(dataLength))
        buf.appendUInt16(UInt16(unitCount))
        buf.appendUTF16BE(string)
        if dataLength % 2 != 0 { buf.appendUInt8(0) }
    }

    private static func appendUTF8Tag(_ buf: inout ByteBuffer,
                                      type: UInt16, string: String) {
        let bytes = Array(string.utf8)
        buf.appendUInt16(type)
        buf.appendUInt16(UInt16(bytes.count))
        buf.appendBytes(Data(bytes))
        if bytes.count % 2 != 0 { buf.appendUInt8(0) }
    }
}

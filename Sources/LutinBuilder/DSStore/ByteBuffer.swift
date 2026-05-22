import Foundation

/// A growable big-endian byte assembler for binary file formats.
struct ByteBuffer {
    private(set) var data = Data()

    var count: Int { data.count }

    mutating func appendUInt8(_ value: UInt8) {
        data.append(value)
    }

    mutating func appendUInt16(_ value: UInt16) {
        data.append(UInt8(truncatingIfNeeded: value >> 8))
        data.append(UInt8(truncatingIfNeeded: value))
    }

    mutating func appendUInt32(_ value: UInt32) {
        data.append(UInt8(truncatingIfNeeded: value >> 24))
        data.append(UInt8(truncatingIfNeeded: value >> 16))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
        data.append(UInt8(truncatingIfNeeded: value))
    }

    mutating func appendUInt64(_ value: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            data.append(UInt8(truncatingIfNeeded: value >> shift))
        }
    }

    mutating func appendBytes(_ bytes: Data) {
        data.append(bytes)
    }

    /// Appends a 4-character ASCII code (e.g. "Iloc", "bwsp"). Must be 4 chars.
    mutating func appendFourCC(_ code: String) {
        precondition(code.utf8.count == 4, "FourCC must be exactly 4 bytes: \(code)")
        data.append(contentsOf: Array(code.utf8))
    }

    /// Appends a string as UTF-16 big-endian (no length prefix, no BOM).
    mutating func appendUTF16BE(_ string: String) {
        for unit in string.utf16 {
            appendUInt16(unit)
        }
    }
}

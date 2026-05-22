import Foundation
import Darwin
import LutinCore

/// Encodes an Apple CFURL bookmark (a "book"-magic record) for a file inside a
/// mounted volume. Written as the top-level `pBBk` record on the `.` entry of
/// a `.DS_Store`; macOS 14+/26 Finder reads `pBBk` preferentially when
/// resolving a DMG window's background image, so this record (not the legacy
/// `icvp.backgroundImageAlias`) is what we need to get right.
///
/// Foundation's `URL.bookmarkData(options:...)` does NOT produce the variant
/// Finder accepts for DMG-volume files — its bookmark stores the path rooted
/// at `/Volumes/<name>/...` rather than relative to the volume, with no
/// "is on a removable disk image" markers. We replicate the layout
/// `mac_alias.Bookmark.for_file` produces (which `dmgbuild` writes and Finder
/// honors). The bookmark binary format is documented inline; the constants
/// match Apple's CFURL/CFBookmark internal headers.
enum BookmarkRecord {

    // MARK: - Format constants

    // Value type prefixes (high byte of the 4-byte type word; the low byte
    // is a subtype).
    private static let BMK_STRING:  UInt32 = 0x0100
    private static let BMK_DATA:    UInt32 = 0x0200
    private static let BMK_NUMBER:  UInt32 = 0x0300
    private static let BMK_DATE:    UInt32 = 0x0400
    private static let BMK_BOOLEAN: UInt32 = 0x0500
    private static let BMK_ARRAY:   UInt32 = 0x0600
    private static let BMK_UUID:    UInt32 = 0x0800
    private static let BMK_URL:     UInt32 = 0x0900

    private static let BMK_ST_ONE:           UInt32 = 0x0001
    private static let BMK_ST_ZERO:          UInt32 = 0x0000
    private static let BMK_BOOLEAN_ST_TRUE:  UInt32 = 0x0001
    private static let BMK_BOOLEAN_ST_FALSE: UInt32 = 0x0000
    private static let BMK_URL_ST_ABSOLUTE:  UInt32 = 0x0001

    private static let CFNumberSInt32Type:   UInt32 = 3
    private static let CFNumberSInt64Type:   UInt32 = 4
    private static let CFNumberFloat64Type:  UInt32 = 6

    // CFURL resource property flags (only the values we actually emit).
    static let kCFURLResourceIsRegularFile: UInt64 = 0x0000_0001
    static let kCFURLResourceIsDirectory:   UInt64 = 0x0000_0002

    // Bookmark key codes (the TOC dict keys).
    static let kBookmarkPath:                UInt32 = 0x1004  // [String]
    static let kBookmarkCNIDPath:            UInt32 = 0x1005  // [Int]
    static let kBookmarkFileProperties:      UInt32 = 0x1010  // Data (24B)
    static let kBookmarkFileCreationDate:    UInt32 = 0x1040  // Date
    static let kBookmarkVolumePath:          UInt32 = 0x2002  // String
    static let kBookmarkVolumeURL:           UInt32 = 0x2005  // URL
    static let kBookmarkVolumeName:          UInt32 = 0x2010  // String
    static let kBookmarkVolumeUUID:          UInt32 = 0x2011  // String form
    static let kBookmarkVolumeSize:          UInt32 = 0x2012  // Int
    static let kBookmarkVolumeCreationDate:  UInt32 = 0x2013  // Date
    static let kBookmarkVolumeProperties:    UInt32 = 0x2020  // Data (24B)
    static let kBookmarkVolumeIsRoot:        UInt32 = 0x2030  // Bool
    static let kBookmarkContainingFolder:    UInt32 = 0xC001  // Int
    static let kBookmarkUserName:            UInt32 = 0xC011  // String ("unknown")
    static let kBookmarkUID:                 UInt32 = 0xC012  // Int (99)
    static let kBookmarkWasFileReference:    UInt32 = 0xD001  // Bool
    static let kBookmarkCreationOptions:     UInt32 = 0xD010  // Int (512)

    /// macOS / Apple "OSX epoch" is 2001-01-01 00:00:00 UTC.
    private static var osxEpoch: Date {
        var c = DateComponents()
        c.year = 2001; c.month = 1; c.day = 1
        c.hour = 0; c.minute = 0; c.second = 0
        c.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    // MARK: - Value enum

    /// A bookmark value. Mirrors the variants `mac_alias._encode_item` supports;
    /// we only model what `for_file` actually emits, plus the `url` case for
    /// `kBookmarkVolumeURL`.
    enum Value {
        case string(String)
        case data(Data)
        case sint32(Int32)
        case sint64(Int64)
        case bool(Bool)
        case date(Date)
        case uuid(UUID)
        case urlAbsolute(String)             // "file:///Volumes/X"
        case array([Value])
        // intMixed: encodes as sint32 when in range, else sint64. Convenient
        // for CNIDs / sizes that may or may not fit in 32 bits.
        case intMixed(Int64)
    }

    /// One bookmark TOC: a TOC id (1 for the primary), plus a key→value map.
    /// The python reference uses an OrderedDict; key order doesn't matter on
    /// the wire (entries are sorted by key in the TOC), but we preserve
    /// insertion order for legibility in the source.
    struct TOC {
        let id: UInt32
        let entries: [(key: UInt32, value: Value)]
    }

    // MARK: - Public entry points

    /// Builds the bookmark bytes for a file at `fileURL` on a volume mounted
    /// at `mountPoint`. The volume must be live; we read its UUID, name,
    /// size, and creation date from the live HFS+ catalog (Foundation +
    /// statfs / getattrlist). Throws `LutinError` with code
    /// `bookmark_failed` if any required attribute can't be read.
    static func encode(fileURL: URL, mountPoint: URL) throws -> Data {
        let inputs = try resolveInputs(fileURL: fileURL, mountPoint: mountPoint)
        return encodeFromInputs(inputs)
    }

    // MARK: - Encoder

    /// Resolved inputs for one bookmark. Kept as a struct so the resolver
    /// and the encoder are testable in isolation.
    struct Inputs {
        var pathComponents: [String]    // volume-relative, e.g. [".background","bg.png"]
        var cnidPath: [Int64]           // CNIDs along the same path
        var fileIsDirectory: Bool
        var fileCreationDate: Date
        var volumePath: String          // "/Volumes/Name"
        var volumeName: String
        var volumeUUID: String          // upper-cased UUID string
        var volumeSize: Int64
        var volumeCreationDate: Date
    }

    private static func encodeFromInputs(_ i: Inputs) -> Data {
        // File property flags (CFURL resource property bitmap, 24 bytes:
        // flags | flagsAskedFor | NULL). dmgbuild always writes the same
        // pair (file-vs-dir + 0x0F mask) — Finder uses this only to verify
        // the resolved file's resource kind.
        let fileFlags: UInt64 = i.fileIsDirectory
            ? kCFURLResourceIsDirectory
            : kCFURLResourceIsRegularFile
        let fileProps = packU64(fileFlags) + packU64(0x0F) + packU64(0)

        // Volume property flags (24 bytes, same shape). The pair below is
        // exactly what `mac_alias.Bookmark.for_file` writes for any HFS+
        // volume that supports persistent file IDs (i.e. all DMGs).
        let kVolSupportsPersistentIDs: UInt64 = 0x0000_0001_0000_0000
        let volProps = packU64(0x81 | kVolSupportsPersistentIDs)
                     + packU64(0x13EF | kVolSupportsPersistentIDs)
                     + packU64(0)

        // Containing folder index = position of the parent dir in pathComponents
        // (0-based; second-to-last). For ".background/bg.png" it's 0.
        let containingFolder = max(0, i.pathComponents.count - 2)

        let toc = TOC(id: 1, entries: [
            (kBookmarkPath,                .array(i.pathComponents.map(Value.string))),
            (kBookmarkCNIDPath,            .array(i.cnidPath.map(Value.intMixed))),
            (kBookmarkFileProperties,      .data(fileProps)),
            (kBookmarkFileCreationDate,    .date(i.fileCreationDate)),
            (kBookmarkVolumePath,          .string(i.volumePath)),
            (kBookmarkVolumeURL,           .urlAbsolute("file://" + i.volumePath)),
            (kBookmarkVolumeName,          .string(i.volumeName)),
            (kBookmarkVolumeUUID,          .string(i.volumeUUID)),
            (kBookmarkVolumeSize,          .intMixed(i.volumeSize)),
            (kBookmarkVolumeCreationDate,  .date(i.volumeCreationDate)),
            (kBookmarkVolumeProperties,    .data(volProps)),
            (kBookmarkVolumeIsRoot,        .bool(i.volumePath == "/")),
            (kBookmarkContainingFolder,    .sint32(Int32(containingFolder))),
            (kBookmarkUserName,            .string("unknown")),
            (kBookmarkUID,                 .sint32(99)),
            (kBookmarkWasFileReference,    .bool(true)),
            (kBookmarkCreationOptions,     .sint32(512)),
        ])

        return serializeFile(tocs: [toc])
    }

    /// Serializes the full bookmark file from one or more TOCs.
    /// File layout: 48-byte outer header + bookmark-data section
    /// (4-byte first-TOC offset, encoded items, TOCs).
    private static func serializeFile(tocs: [TOC]) -> Data {
        // The bookmark data starts at file offset 48. All "offsets" inside
        // the bookmark data are measured from the start of the data section,
        // not from the start of the file. The first 4 bytes of the data
        // section hold the offset to the first TOC.
        var body = Data()
        var offset = 4   // starts at 4: the first-TOC offset slot

        // Encoded TOC blobs (raw entry bytes, prior to wrapping in a TOC
        // header) so we know each TOC's size before placing it.
        struct EncodedTOC { let id: UInt32; let entries: [(UInt32, UInt32)] }
        var encodedTOCs: [EncodedTOC] = []

        for toc in tocs {
            var entries: [(UInt32, UInt32)] = []
            for (key, value) in toc.entries {
                let valueOffset = offset
                let (newOffset, encoded) = encodeItem(value, atOffset: offset)
                body.append(encoded)
                offset = newOffset
                entries.append((key, UInt32(valueOffset)))
            }
            // Entries must be sorted by key — CoreServicesInternal binary-
            // searches for the key it wants.
            entries.sort { $0.0 < $1.0 }
            encodedTOCs.append(EncodedTOC(id: toc.id, entries: entries))
        }

        let firstTOCOffset = UInt32(offset)

        // Append TOC headers + entries.
        for (idx, t) in encodedTOCs.enumerated() {
            let entryBytes = t.entries.reduce(into: Data()) { acc, e in
                acc.append(packU32(e.0))
                acc.append(packU32(e.1))
                acc.append(packU32(0))                       // reserved
            }
            let isLast = (idx == encodedTOCs.count - 1)
            let nextOffset: UInt32 = isLast ? 0 : UInt32(offset + 20 + entryBytes.count)
            var hdr = Data()
            hdr.append(packU32(UInt32(entryBytes.count) &- 8))   // length minus 8
            hdr.append(packU32(0xFFFF_FFFE))                     // TOC magic
            hdr.append(packU32(t.id))                            // TOC id
            hdr.append(packU32(nextOffset))                      // next TOC file offset
            hdr.append(packU32(UInt32(entryBytes.count) / 12))   // entry count
            body.append(hdr)
            body.append(entryBytes)
            offset += 20 + entryBytes.count
        }

        // Outer file header (48 bytes):
        //   "book"            (4)
        //   total file size   (4, LE)
        //   magic2 0x10040000 (4, LE)
        //   data offset = 48  (4, LE)
        //   32 bytes padding zeros
        // Then the bookmark data section begins with a 4-byte
        // first-TOC offset, followed by `body`.
        let totalSize = UInt32(48 + 4 + body.count)
        var file = Data()
        file.append(contentsOf: Array("book".utf8))
        file.append(packU32(totalSize))
        file.append(packU32(0x1004_0000))
        file.append(packU32(48))
        file.append(Data(repeating: 0, count: 32))
        file.append(packU32(firstTOCOffset))
        file.append(body)
        return file
    }

    /// Encodes one `Value` at the given offset within the bookmark data
    /// section. Returns the new offset (after the encoded value, padded to
    /// 4 bytes) and the encoded bytes.
    private static func encodeItem(_ value: Value, atOffset offset: Int)
        -> (Int, Data)
    {
        var out = Data()
        switch value {
        case .string(let s):
            let bytes = Array(s.utf8)
            out.append(packU32(UInt32(bytes.count)))
            out.append(packU32(BMK_STRING | BMK_ST_ONE))
            out.append(contentsOf: bytes)

        case .data(let d):
            out.append(packU32(UInt32(d.count)))
            out.append(packU32(BMK_DATA | BMK_ST_ONE))
            out.append(d)

        case .sint32(let v):
            out.append(packU32(4))
            out.append(packU32(BMK_NUMBER | CFNumberSInt32Type))
            out.append(packI32(v))

        case .sint64(let v):
            out.append(packU32(8))
            out.append(packU32(BMK_NUMBER | CFNumberSInt64Type))
            out.append(packI64(v))

        case .intMixed(let v):
            if v >= Int64(Int32.min) && v <= Int64(Int32.max) {
                return encodeItem(.sint32(Int32(v)), atOffset: offset)
            }
            return encodeItem(.sint64(v), atOffset: offset)

        case .bool(let b):
            out.append(packU32(0))
            out.append(packU32(BMK_BOOLEAN | (b ? BMK_BOOLEAN_ST_TRUE : BMK_BOOLEAN_ST_FALSE)))

        case .date(let d):
            out.append(packU32(8))
            out.append(packU32(BMK_DATE | BMK_ST_ZERO))
            // The payload is a big-endian (!) 64-bit float of seconds since
            // the OSX epoch (2001-01-01 UTC). Yes, big-endian — bookmark is
            // little-endian everywhere except this one field.
            let secs = d.timeIntervalSince(osxEpoch)
            var be = secs.bitPattern.bigEndian
            withUnsafeBytes(of: &be) { out.append(contentsOf: $0) }

        case .uuid(let u):
            out.append(packU32(16))
            out.append(packU32(BMK_UUID | BMK_ST_ONE))
            withUnsafeBytes(of: u.uuid) { out.append(contentsOf: $0) }

        case .urlAbsolute(let s):
            let bytes = Array(s.utf8)
            out.append(packU32(UInt32(bytes.count)))
            out.append(packU32(BMK_URL | BMK_URL_ST_ABSOLUTE))
            out.append(contentsOf: bytes)

        case .array(let items):
            // Arrays carry inline offsets pointing at item values that live
            // AFTER the array record. Per mac_alias._encode_item, item data
            // starts at `offset + 8 + 4*count` and grows from there.
            let count = items.count
            var ioffset = offset + 8 + count * 4
            var pointers = Data()
            var bodies = Data()
            for elt in items {
                pointers.append(packU32(UInt32(ioffset)))
                let (newOffset, enc) = encodeItem(elt, atOffset: ioffset)
                ioffset = newOffset
                bodies.append(enc)
            }
            out.append(packU32(UInt32(count * 4)))
            out.append(packU32(BMK_ARRAY | BMK_ST_ONE))
            out.append(pointers)
            out.append(bodies)
        }

        // Pad every item to a 4-byte boundary.
        var newOffset = offset + out.count
        let extra = newOffset & 3
        if extra != 0 {
            let pad = 4 - extra
            out.append(Data(repeating: 0, count: pad))
            newOffset += pad
        }
        return (newOffset, out)
    }

    // MARK: - Little-endian packing helpers

    private static func packU32(_ v: UInt32) -> Data {
        var v = v.littleEndian
        return withUnsafeBytes(of: &v) { Data($0) }
    }
    private static func packI32(_ v: Int32) -> Data {
        var v = v.littleEndian
        return withUnsafeBytes(of: &v) { Data($0) }
    }
    private static func packU64(_ v: UInt64) -> Data {
        var v = v.littleEndian
        return withUnsafeBytes(of: &v) { Data($0) }
    }
    private static func packI64(_ v: Int64) -> Data {
        var v = v.littleEndian
        return withUnsafeBytes(of: &v) { Data($0) }
    }

    // MARK: - Live filesystem resolver

    /// Reads the live HFS+ catalog for the values a bookmark needs. The
    /// volume must be currently mounted (it always is at the point we call
    /// this — between the DMG mount and the .DS_Store write).
    static func resolveInputs(fileURL: URL, mountPoint: URL) throws -> Inputs {
        let fm = FileManager.default
        let absPath = fileURL.standardizedFileURL.path
        let mountPath = mountPoint.standardizedFileURL.path
        guard absPath.hasPrefix(mountPath) else {
            throw LutinError(code: "bookmark_failed",
                             message: "Background file \(absPath) is not under the mount point \(mountPath).")
        }
        let relative = String(absPath.dropFirst(mountPath.count)
                              .drop(while: { $0 == "/" }))
        let pathComponents = relative.split(separator: "/").map(String.init)
        guard !pathComponents.isEmpty else {
            throw LutinError(code: "bookmark_failed",
                             message: "Background file path is empty after stripping mount prefix.")
        }

        // CNID path: stat() each intermediate folder + the file itself.
        var cnidPath: [Int64] = []
        var walk = mountPoint.standardizedFileURL
        for comp in pathComponents {
            walk.appendPathComponent(comp)
            cnidPath.append(Int64(try inode(of: walk)))
        }

        // File attrs (creation date + isDir).
        let fileAttrs = try fm.attributesOfItem(atPath: fileURL.path)
        let fileCreationDate = (fileAttrs[.creationDate] as? Date) ?? Date()
        let fileIsDirectory = (fileAttrs[.type] as? FileAttributeType)
            == .typeDirectory

        // Volume attrs from URL resource values: name, UUID, total capacity,
        // creation date. These are stable across mounts of the same DMG.
        let volURL = URL(fileURLWithPath: mountPath, isDirectory: true)
        let rv = try volURL.resourceValues(forKeys: [
            .volumeNameKey, .volumeUUIDStringKey,
            .volumeTotalCapacityKey, .volumeCreationDateKey,
        ])
        let volumeName = rv.volumeName ?? mountPoint.lastPathComponent
        let volumeUUID = (rv.volumeUUIDString ?? UUID().uuidString).uppercased()
        let volumeSize = Int64(rv.volumeTotalCapacity ?? 0)
        let volumeCreationDate = rv.volumeCreationDate ?? Date()

        return Inputs(
            pathComponents: pathComponents,
            cnidPath: cnidPath,
            fileIsDirectory: fileIsDirectory,
            fileCreationDate: fileCreationDate,
            volumePath: mountPath,
            volumeName: volumeName,
            volumeUUID: volumeUUID,
            volumeSize: volumeSize,
            volumeCreationDate: volumeCreationDate)
    }

    private static func inode(of url: URL) throws -> UInt64 {
        var st = stat()
        if stat(url.path, &st) != 0 {
            throw LutinError(code: "bookmark_failed",
                             message: "stat() failed for \(url.path).")
        }
        return UInt64(st.st_ino)
    }
}

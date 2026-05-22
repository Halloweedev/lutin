import Foundation

/// Encodes a version-2 Carbon alias record pointing at a file inside a mounted
/// HFS+ volume. Used as the `backgroundImageAlias` value in an `icvp` record.
///
/// Modern macOS Finder reads modern bookmarks AND legacy aliases here, but it
/// is unforgiving about the alias *shape*: missing the high-res date tags
/// (16/17), the Carbon HFS path tag (2), the parent-folder tag (0), or a
/// real volume-created timestamp in the fixed header all cause Finder to
/// silently drop the background image (we verified this against a known-good
/// DMG produced by the dmgbuild Python toolchain). The tag set written here
/// mirrors what `mac_alias.Alias.for_file(...)` emits, byte-positioned to
/// match what Finder accepts.
enum AliasRecord {
    /// Inputs for one alias. `volumeCreated` / `fileCreated` are Carbon dates
    /// (seconds since 1904-01-01 00:00:00 UTC); `folderName` is the leaf
    /// folder enclosing the target file (nil if the file sits at the volume
    /// root), and `carbonPath` is the colon-separated HFS-style path from the
    /// volume name down to the file (e.g. `"Lutin:.background:background.png"`).
    struct Inputs {
        var volumeName: String
        var fileName: String
        var volumeRelativePOSIXPath: String     // leading-slash form, e.g. "/.background/background.png"
        var folderName: String?                 // leaf parent folder, or nil at root
        /// Carbon HFS path bytes. Components are joined by `":\0"` (colon +
        /// null) — that's how `mac_alias` formats this tag, and Finder won't
        /// accept the plain `:`-joined form. Built by the resolver, kept as
        /// `Data` so the trailing-null behaviour is explicit.
        var carbonPath: Data
        var volumeCreated: UInt32               // seconds since 1904-01-01 UTC
        var fileCreated: UInt32                 // seconds since 1904-01-01 UTC
        var parentCNID: UInt32                  // HFS+ parent CNID (2 = vol root)
        var fileCNID: UInt32                    // HFS+ file CNID
        /// CNIDs of each intermediate folder from the volume root down to the
        /// target file's parent (not including the volume root itself and not
        /// including the file's own CNID). Empty if the file is at the root.
        var cnidPath: [UInt32]
    }

    static func encode(_ inputs: Inputs) -> Data {
        var buf = ByteBuffer()

        // --- Fixed header (150 bytes for v2) ---
        buf.appendUInt32(0)                       // application info
        buf.appendUInt16(0)                       // record size — backfilled
        buf.appendUInt16(2)                       // version
        buf.appendUInt16(0)                       // alias kind: file
        appendPascalString(&buf, inputs.volumeName, fieldLength: 27)
        buf.appendUInt32(inputs.volumeCreated)    // volume created (Carbon date)
        buf.appendUInt8(0x48)                     // volume signature 'H'
        buf.appendUInt8(0x2B)                     // volume signature '+'
        buf.appendUInt16(0)                       // volume type (0 = generic)
        buf.appendUInt32(inputs.parentCNID)       // parent directory CNID
        appendPascalString(&buf, inputs.fileName, fieldLength: 63)
        buf.appendUInt32(inputs.fileCNID)         // file CNID
        buf.appendUInt32(inputs.fileCreated)      // file created (Carbon date)
        buf.appendUInt32(0)                       // file type
        buf.appendUInt32(0)                       // file creator
        buf.appendUInt16(0xFFFF)                  // nlvl from
        buf.appendUInt16(0xFFFF)                  // nlvl to
        buf.appendUInt32(0)                       // volume attributes
        buf.appendUInt16(0)                       // volume filesystem ID
        buf.appendBytes(Data(repeating: 0, count: 10))  // reserved

        // --- Tag records (order copies mac_alias / Finder) ---

        // Tag 0 = Carbon folder name (leaf parent dir).
        if let folder = inputs.folderName, !folder.isEmpty {
            appendUTF8Tag(&buf, type: 0x0000, string: folder)
        }

        // Tags 16/17 = high-res 8-byte timestamps (Carbon date × 65536).
        // Finder treats these as authoritative on modern macOS; the 4-byte
        // dates in the fixed header are legacy and routinely ignored.
        let voldateHi = UInt64(inputs.volumeCreated) << 16
        let crdateHi  = UInt64(inputs.fileCreated)   << 16
        appendUInt64Tag(&buf, type: 0x0010, value: voldateHi)
        appendUInt64Tag(&buf, type: 0x0011, value: crdateHi)

        // Tag 1 = CNID path: 4-byte CNIDs for each intermediate folder from
        // the volume root down to (but not including) the file. Finder uses
        // these to re-resolve the alias if the POSIX path moved.
        if !inputs.cnidPath.isEmpty {
            buf.appendUInt16(0x0001)
            buf.appendUInt16(UInt16(inputs.cnidPath.count * 4))
            for cnid in inputs.cnidPath { buf.appendUInt32(cnid) }
        }

        // Tag 2 = Carbon HFS path, UTF-8. Components joined by `":\0"` —
        // mac_alias's convention; Finder rejects plain `:`-joined paths.
        appendBytesTag(&buf, type: 0x0002, bytes: inputs.carbonPath)

        // Tag 14 = unicode filename; tag 15 = unicode volume name.
        appendUnicodeTag(&buf, type: 0x000E, string: inputs.fileName)
        appendUnicodeTag(&buf, type: 0x000F, string: inputs.volumeName)

        // Tag 18 = POSIX path *relative to the volume root* (leading slash).
        // Finder rejects the absolute `/Volumes/<name>/...` form here.
        // Tag 19 = POSIX path to the mount point.
        appendUTF8Tag(&buf, type: 0x0012, string: inputs.volumeRelativePOSIXPath)
        appendUTF8Tag(&buf, type: 0x0013, string: "/Volumes/" + inputs.volumeName)

        buf.appendUInt16(0xFFFF)                  // terminator tag type
        buf.appendUInt16(0)                       // terminator length

        // --- Backfill record size at offset 4 (2 bytes, big-endian) ---
        var data = buf.data
        precondition(data.count <= Int(UInt16.max), "AliasRecord too large: \(data.count) bytes")
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
        let dataLength = 2 + unitCount * 2
        buf.appendUInt16(type)
        buf.appendUInt16(UInt16(dataLength))
        buf.appendUInt16(UInt16(unitCount))
        buf.appendUTF16BE(string)
    }

    private static func appendUTF8Tag(_ buf: inout ByteBuffer,
                                      type: UInt16, string: String) {
        let bytes = Array(string.utf8)
        buf.appendUInt16(type)
        buf.appendUInt16(UInt16(bytes.count))
        buf.appendBytes(Data(bytes))
        if bytes.count % 2 != 0 { buf.appendUInt8(0) }
    }

    private static func appendBytesTag(_ buf: inout ByteBuffer,
                                       type: UInt16, bytes: Data) {
        buf.appendUInt16(type)
        buf.appendUInt16(UInt16(bytes.count))
        buf.appendBytes(bytes)
        if bytes.count % 2 != 0 { buf.appendUInt8(0) }
    }

    private static func appendUInt64Tag(_ buf: inout ByteBuffer,
                                        type: UInt16, value: UInt64) {
        buf.appendUInt16(type)
        buf.appendUInt16(8)
        buf.appendUInt64(value)
    }
}

/// Helpers that resolve the runtime values (CNIDs, dates) the alias needs.
enum AliasInputsResolver {
    /// Builds `AliasRecord.Inputs` for a file that exists at `fileURL` inside a
    /// volume mounted at `mountPoint`. Probes the filesystem for real CNIDs
    /// and creation dates; falls back to plausible defaults if any probe
    /// fails. Volume root has CNID 2 on HFS+.
    static func resolve(fileURL: URL, mountPoint: URL,
                        volumeName: String) -> AliasRecord.Inputs {
        let fm = FileManager.default
        let fileName = fileURL.lastPathComponent
        let folder = fileURL.deletingLastPathComponent()
        let isAtRoot = folder.standardizedFileURL.path == mountPoint.standardizedFileURL.path
        let folderName = isAtRoot ? nil : folder.lastPathComponent

        // Volume-relative POSIX path: strip the mount prefix.
        let absPath = fileURL.standardizedFileURL.path
        let mountPath = mountPoint.standardizedFileURL.path
        let relative = absPath.hasPrefix(mountPath)
            ? String(absPath.dropFirst(mountPath.count))
            : absPath
        let posixRelative = relative.hasPrefix("/") ? relative : "/" + relative

        // Carbon HFS path. mac_alias joins components with `":\0"` between
        // each step (with a final `:` then the filename, no trailing null
        // inside the string — the tag encoder pads to even length).
        // For `/.background/background.png` on volume `Lutin`, this is:
        //   "Lutin:" + ".background" + ":\0" + "background.png"
        let components = relative.split(separator: "/").map(String.init)
        var carbon = Data()
        carbon.append(contentsOf: volumeName.utf8)
        carbon.append(0x3A)                                  // ':'
        for (idx, comp) in components.enumerated() {
            carbon.append(contentsOf: comp.utf8)
            if idx != components.count - 1 {
                carbon.append(0x3A); carbon.append(0x00)     // ':\0'
            }
        }

        // CNIDs: file from stat() inode, parent dir from stat() of containing
        // folder. HFS+ inodes ARE CNIDs.
        let fileCNID = inode(of: fileURL) ?? 0
        let parentCNID = isAtRoot ? 2 : (inode(of: folder) ?? 0)

        // CNID path = inodes of every intermediate folder from the volume
        // root down to (but excluding) the file. For `/.background/bg.png`:
        // [inode(/Volumes/X/.background)]. For a file at the root: empty.
        var cnidPath: [UInt32] = []
        if components.count > 1 {
            var walk = mountPoint
            for comp in components.dropLast() {
                walk.appendPathComponent(comp)
                if let i = inode(of: walk) {
                    cnidPath.append(UInt32(truncatingIfNeeded: i))
                }
            }
        }

        // Dates: file mtime as both volume and file creation (Mac epoch).
        let now = Date()
        let macEpoch: Date = {
            // 1904-01-01 00:00:00 UTC. Build via DateComponents for portability.
            var comps = DateComponents()
            comps.year = 1904; comps.month = 1; comps.day = 1
            comps.hour = 0; comps.minute = 0; comps.second = 0
            comps.timeZone = TimeZone(secondsFromGMT: 0)
            return Calendar(identifier: .gregorian).date(from: comps) ?? now
        }()
        let mountCreated = (try? fm.attributesOfItem(atPath: mountPoint.path)[.creationDate] as? Date) ?? now
        let fileCreated  = (try? fm.attributesOfItem(atPath: fileURL.path)[.creationDate] as? Date) ?? now
        let voldateSec = max(0, Int(mountCreated.timeIntervalSince(macEpoch)))
        let crdateSec  = max(0, Int(fileCreated.timeIntervalSince(macEpoch)))

        // CNID path - for the leaf folder, we want a single CNID entry: the
        // parent folder. For `/.background/bg.png`, that's [80].
        if components.count == 1 {
            // file at volume root → no intermediate folders, cnidPath empty
        } else if cnidPath.isEmpty {
            // fallback: use the parent CNID we computed
            cnidPath = [UInt32(truncatingIfNeeded: parentCNID)]
        }

        return AliasRecord.Inputs(
            volumeName: volumeName,
            fileName: fileName,
            volumeRelativePOSIXPath: posixRelative,
            folderName: folderName,
            carbonPath: carbon,
            volumeCreated: UInt32(truncatingIfNeeded: voldateSec),
            fileCreated: UInt32(truncatingIfNeeded: crdateSec),
            parentCNID: UInt32(truncatingIfNeeded: parentCNID),
            fileCNID: UInt32(truncatingIfNeeded: fileCNID),
            cnidPath: cnidPath)
    }

    private static func inode(of url: URL) -> UInt64? {
        var st = stat()
        guard stat(url.path, &st) == 0 else { return nil }
        return UInt64(st.st_ino)
    }
}

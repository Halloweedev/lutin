import Foundation

/// Encodes a `.DS_Store` file for a DMG window layout.
///
/// Lutin always writes a *single-leaf* B-tree (one leaf node, no internal
/// nodes), which is valid for the small number of records a DMG window needs
/// and avoids implementing node splitting. See `BuddyAllocator` for the
/// container format and `ds_store/store.py` for the reference.
enum DSStoreEncoder {
    /// One B-tree record, kept together with its sort keys.
    private struct Record {
        let filename: String
        let structID: String
        let bytes: Data
    }

    /// Builds the `.DS_Store` byte stream for `layout` and `background`.
    // throws reserved for future validation (e.g. invalid filename encoding)
    static func encode(layout: DMGLayout,
                       background: DSStoreRecords.Background) throws -> Data {
        // 1. Build the records. Order doesn't matter (we sort below), but the
        //    record SET must match what dmgbuild / Finder writes itself —
        //    macOS 14+/26 Finder treats a `.DS_Store` missing `vSrn` / `icvl`
        //    / `pBBk` (when there's a background) as "incomplete" and falls
        //    back to default layout, silently ignoring our `Iloc`s and
        //    `icvp.backgroundImageAlias`. See dmgbuild/core.py for the
        //    canonical record set we mirror here.
        var records: [Record] = []

        // The "." pseudo-entry carries the window-level settings.
        let bwsp = DSStoreRecords.bwspBlob(
            windowWidth: layout.windowWidth, windowHeight: layout.windowHeight,
            showSidebar: layout.showSidebar, showToolbar: layout.showToolbar)
        records.append(Record(
            filename: ".", structID: "bwsp",
            bytes: encodeRecord(filename: ".", structID: "bwsp",
                                dataType: "blob", value: bwsp)))

        let icvp = DSStoreRecords.icvpBlob(
            iconSize: layout.iconSize, textSize: layout.textSize,
            background: background)
        records.append(Record(
            filename: ".", structID: "icvp",
            bytes: encodeRecord(filename: ".", structID: "icvp",
                                dataType: "blob", value: icvp)))

        // `vSrn` = (long, 1) — view-style record number. Always present.
        records.append(Record(
            filename: ".", structID: "vSrn",
            bytes: encodeRecord(filename: ".", structID: "vSrn",
                                dataType: "long", value: encodeUInt32(1))))

        // `icvl` = (type, "icnv") — view layout: icon view. Always present.
        records.append(Record(
            filename: ".", structID: "icvl",
            bytes: encodeRecord(filename: ".", structID: "icvl",
                                dataType: "type", value: encodeFourCC("icnv"))))

        // CONFIRMED: omitting the `pBBk` (background bookmark) record is the
        // gate for the background image on macOS 14+/26 Finder. Empirical
        // result from May 21 2026 testing on macOS 26.3: with pBBk present,
        // Finder ignores the entire background image even when everything
        // else (alias, kHasCustomIcon flag, notarized DMG) is correct. With
        // pBBk omitted, Finder falls back to `icvp.backgroundImageAlias`
        // (which we already write correctly) and renders the background.
        // Barry's working dmgbuild-built DMG has no pBBk for the same reason.
        // Keeping `BookmarkRecord.swift` in the tree for future use, just
        // not emitting the record.
        _ = background  // suppress unused-pattern warning

        // Each placed item carries an Iloc (icon location) record.
        for (filename, point) in layout.placements {
            let iloc = DSStoreRecords.ilocBlob(x: point.x, y: point.y)
            records.append(Record(
                filename: filename, structID: "Iloc",
                bytes: encodeRecord(filename: filename, structID: "Iloc",
                                    dataType: "blob", value: iloc)))
        }

        // B-tree sort order: case-insensitive ascending by filename, then by
        // struct id (4CC) — exactly the ordering in ds_store's DSStoreEntry.
        records.sort { lhs, rhs in
            let l = lhs.filename.lowercased()
            let r = rhs.filename.lowercased()
            if l != r { return l < r }
            return lhs.structID < rhs.structID
        }

        // 2. Encode the single leaf node block: P=0 (leaf), record count, then
        //    the records back to back.
        var leaf = ByteBuffer()
        leaf.appendUInt32(0)                                  // P = 0 → leaf node
        leaf.appendUInt32(UInt32(records.count))              // record count
        for record in records { leaf.appendBytes(record.bytes) }

        // 3. Encode the 20-byte DSDB superblock:
        //    root node block #, levels, record count, node count, page size.
        //    The leaf is block #1 within the buddy container (block #0 is the
        //    allocator's own info block); BuddyAllocator places DSDB at #1 and
        //    the leaf at #2 — see assemble().
        // INVARIANT: block 2 = leaf node; must match BuddyAllocator.assemble's reallocate(block: 2, ...).
        let leafBlockNumber: UInt32 = 2
        var dsdb = ByteBuffer()
        dsdb.appendUInt32(leafBlockNumber)                    // root node block #
        // levels = 0 for a single-leaf B-tree — that's what dmgbuild writes
        // and what Finder expects. Writing `1` here silently disables the
        // entire `.DS_Store`.
        dsdb.appendUInt32(0)                                  // levels (height)
        dsdb.appendUInt32(UInt32(records.count))              // record count
        dsdb.appendUInt32(1)                                  // node count
        dsdb.appendUInt32(0x1000)                             // page size

        // 4. Hand both blocks to the Buddy-allocator container writer.
        return BuddyAllocator.assemble(dsdbHeaderBlock: dsdb.data,
                                       leafNodeBlock: leaf.data)
    }

    /// Encodes one B-tree record: filename (UTF-16 length + UTF-16 BE),
    /// struct id 4CC, data type 4CC, value. The data-type sentinel governs
    /// how the value is laid out on disk:
    ///   * `blob` — 4-byte big-endian length, then bytes
    ///   * `long` — 4-byte UInt32 BE (caller supplies the 4 bytes directly)
    ///   * `type` — 4-byte FourCC (caller supplies the 4 bytes directly)
    /// Other ds_store-supported types (`bool`, `ustr`, `comp`, `dutc`) aren't
    /// needed by Finder's DMG layout and are intentionally omitted.
    static func encodeRecord(filename: String, structID: String,
                             dataType: String, value: Data) -> Data {
        var buf = ByteBuffer()
        buf.appendUInt32(UInt32(filename.utf16.count))
        buf.appendUTF16BE(filename)
        buf.appendFourCC(structID)
        buf.appendFourCC(dataType)
        if dataType == "blob" {
            buf.appendUInt32(UInt32(value.count))
        } else {
            precondition(value.count == 4,
                "data type '\(dataType)' must carry a 4-byte payload, got \(value.count)")
        }
        buf.appendBytes(value)
        return buf.data
    }

    private static func encodeUInt32(_ value: UInt32) -> Data {
        var buf = ByteBuffer()
        buf.appendUInt32(value)
        return buf.data
    }

    private static func encodeFourCC(_ code: String) -> Data {
        var buf = ByteBuffer()
        buf.appendFourCC(code)
        return buf.data
    }
}

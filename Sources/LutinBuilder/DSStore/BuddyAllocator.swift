import Foundation

/// Writes the `.DS_Store` Buddy-allocator container around a pre-encoded
/// B-tree (the DSDB header block + the single leaf node block).
///
/// Ported from the `ds_store` reference implementation (`buddy.py`); only the
/// write path and a single-leaf B-tree are supported.
///
/// The Buddy allocator partitions a notional 2 GiB region into power-of-two
/// "buddy" blocks. Each block has a *width* `w` (the block spans `2**w` bytes)
/// and lives at an offset that is a multiple of `2**w`. A block's address is
/// packed into a single 32-bit value as `offset | width` (offsets are always
/// `>= 32`, so the low 5 bits are free to carry the width). There is a fixed
/// 4-byte skew between an allocator offset and the file position: file
/// position `= offset + 4`.
struct BuddyAllocator {
    /// Simulates the buddy free-list allocator from `ds_store/buddy.py`.
    private struct Allocator {
        /// 32 free lists, one per width 0...31. Each holds sorted offsets of
        /// free blocks of that exact width.
        var free: [[Int]]
        /// Block addresses (`offset | width`) keyed by logical block number.
        /// A value of 0 means the slot is reserved but not yet allocated.
        var offsets: [Int]

        init() {
            // Initial state, exactly as `Allocator.open` writes it for a fresh
            // file: the header consumes a 2**5 block and the root/info block a
            // 2**11 block. Splitting the 2**31 region down to 2**5 leaves one
            // free block of every width 5...30, and each free block of width n
            // conveniently sits at offset 2**n.
            free = Array(repeating: [], count: 32)
            for n in 5...30 { free[n] = [1 << n] }
            // The root (info) block, width 11, is already accounted for, but
            // its slot (block 0) is created by the caller via `reallocate`.
            free[11] = []
            offsets = []
        }

        /// Smallest buddy width whose block holds `byteCount` bytes (min 2**5).
        private static func width(forBytes byteCount: Int) -> Int {
            max(byteCount <= 0 ? 0 : byteCount.bitWidth - byteCount.leadingZeroBitCount, 5)
        }

        /// Pops a free block of exactly `width`, splitting larger blocks down
        /// as needed. Mirrors `_alloc` in buddy.py.
        private mutating func alloc(width: Int) -> Int {
            var w = width
            while free[w].isEmpty { w += 1 }
            while w > width {
                let offset = free[w].removeFirst()
                w -= 1
                free[w] = [offset, offset ^ (1 << w)].sorted()
            }
            return free[width].removeFirst()
        }

        /// Returns a free block of `width` back to its free list, coalescing
        /// with its buddy where possible. Mirrors `_release` in buddy.py.
        private mutating func release(offset: Int, width: Int) {
            var offset = offset
            var width = width
            while true {
                let buddy = offset ^ (1 << width)
                guard let ndx = free[width].firstIndex(of: buddy) else { break }
                free[width].remove(at: ndx)
                offset &= buddy
                width += 1
            }
            var list = free[width]
            let insertion = list.firstIndex(where: { $0 > offset }) ?? list.count
            list.insert(offset, at: insertion)
            free[width] = list
        }

        /// Allocates or reallocates logical `block` to hold `byteCount` bytes.
        /// Mirrors `allocate` in buddy.py. Returns the block number.
        @discardableResult
        mutating func reallocate(block: Int, byteCount: Int) -> Int {
            while offsets.count <= block { offsets.append(0) }
            let want = Self.width(forBytes: byteCount)
            let addr = offsets[block]
            if addr != 0 {
                let have = addr & 0x1F
                if have == want { return block }
                release(offset: addr & ~0x1F, width: have)
                offsets[block] = 0
            }
            let offset = alloc(width: want)
            offsets[block] = offset | want
            return block
        }

        /// File position of logical `block` (allocator offset + 4-byte skew).
        func filePosition(of block: Int) -> Int { (offsets[block] & ~0x1F) + 4 }

        /// Byte size of logical `block`.
        func size(of block: Int) -> Int { 1 << (offsets[block] & 0x1F) }
    }

    /// Wraps `dsdbHeaderBlock` (the DSDB superblock) and `leafNodeBlock` (the
    /// single B-tree leaf node) into a complete `.DS_Store` byte stream.
    static func assemble(dsdbHeaderBlock: Data, leafNodeBlock: Data) -> Data {
        var alloc = Allocator()

        // Block 0 is the allocator's own root/info block. Reserve its slot now
        // so it keeps block number 0; it is sized and allocated last because
        // its size depends on the offset list and free lists it must store.
        alloc.offsets = [0]

        // Block 1: DSDB superblock. Block 2: the B-tree leaf node.
        alloc.reallocate(block: 1, byteCount: dsdbHeaderBlock.count)
        alloc.reallocate(block: 2, byteCount: leafNodeBlock.count)

        // The directory ("TOC") maps the name "DSDB" to its block number.
        let directory: [(name: String, block: Int)] = [("DSDB", 1)]

        // Size of the root/info block given an offset-list length. Layout:
        //   offset count (4) + unknown (4)
        //   + 4 * roundUp(offsetCount, 256)        block-address list
        //   + directory count (4) + entries        each: 1 + len(name) + 4
        //   + 32 free-list buckets                  each: 4 + 4 * len(list)
        func rootBlockSize(allocator: Allocator) -> Int {
            var size = 8
            size += 4 * ((allocator.offsets.count + 255) & ~255)
            size += 4
            for entry in directory { size += 5 + entry.name.utf8.count }
            for list in allocator.free { size += 4 + 4 * list.count }
            return size
        }

        // Allocate block 0 to a fixed point: reallocating it can change the
        // free lists, which changes the required size. `reallocate` is a no-op
        // once the width already matches, so the loop terminates quickly.
        while true {
            let before = alloc.offsets[0]
            alloc.reallocate(block: 0, byteCount: rootBlockSize(allocator: alloc))
            if alloc.offsets[0] == before { break }
        }

        // ---- Build the file image ----
        var maxEnd = 36  // 32-byte header + 4-byte skew region
        for block in 0..<alloc.offsets.count {
            maxEnd = max(maxEnd, alloc.filePosition(of: block) + alloc.size(of: block))
        }
        var file = Data(count: maxEnd)

        func writeBlock(_ block: Int, _ payload: Data) {
            let pos = alloc.filePosition(of: block)
            precondition(payload.count <= alloc.size(of: block), "block \(block) overflow")
            file.replaceSubrange(pos..<(pos + payload.count), with: payload)
        }

        // -- Root/info block --
        var root = ByteBuffer()
        root.appendUInt32(UInt32(alloc.offsets.count))           // offset count
        root.appendUInt32(0)                                     // unknown2
        for addr in alloc.offsets { root.appendUInt32(UInt32(addr)) }
        let extra = alloc.offsets.count & 255
        if extra != 0 {
            root.appendBytes(Data(count: 4 * (256 - extra)))     // pad to multiple of 256
        }
        // Directory ("TOC"), keys sorted ascending.
        root.appendUInt32(UInt32(directory.count))
        for entry in directory.sorted(by: { $0.name < $1.name }) {
            root.appendUInt8(UInt8(entry.name.utf8.count))
            root.appendBytes(Data(entry.name.utf8))
            root.appendUInt32(UInt32(entry.block))
        }
        // 32 free-list buckets.
        for list in alloc.free {
            root.appendUInt32(UInt32(list.count))
            for off in list { root.appendUInt32(UInt32(off)) }
        }
        writeBlock(0, root.data)

        // -- DSDB superblock and leaf node --
        writeBlock(1, dsdbHeaderBlock)
        writeBlock(2, leafNodeBlock)

        // -- 32-byte outer header (needs the root block address) --
        let rootAddr = alloc.offsets[0]
        let rootFileOffset = rootAddr & ~0x1F     // allocator offset (no +4 skew)
        let rootSize = 1 << (rootAddr & 0x1F)
        var header = ByteBuffer()
        header.appendUInt32(1)                    // alignment / magic1
        header.appendFourCC("Bud1")
        header.appendUInt32(UInt32(rootFileOffset))   // root block offset
        header.appendUInt32(UInt32(rootSize))         // root block size
        header.appendUInt32(UInt32(rootFileOffset))   // copy of offset
        header.appendBytes(Data(count: 16))           // 16 bytes padding → 36-byte header
        file.replaceSubrange(0..<36, with: header.data)

        return file
    }
}

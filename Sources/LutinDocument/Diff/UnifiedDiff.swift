import Foundation

public struct UnifiedDiff: Equatable {
    public struct Line: Equatable {
        public enum Kind { case context, added, removed }
        public let kind: Kind
        public let text: String
    }
    public struct Hunk: Equatable {
        public let leftStart: Int
        public let rightStart: Int
        public let lines: [Line]
    }
    public let hunks: [Hunk]
}

public extension UnifiedDiff {
    /// Computes a simple line-level diff using the Myers algorithm via LCS.
    /// Files are expected to be small (YAML); this trades the smartest output
    /// for simple, dependency-free code.
    static func diff(left: String, right: String, contextLines: Int = 2) -> UnifiedDiff {
        let l = left.components(separatedBy: "\n")
        let r = right.components(separatedBy: "\n")
        let table = lcs(l, r)
        let edits = backtrack(table, l, r)
        let hunks = groupIntoHunks(edits, contextLines: contextLines)
        return UnifiedDiff(hunks: hunks)
    }

    private enum Edit { case keep(String, Int, Int); case add(String, Int); case remove(String, Int) }

    private static func lcs(_ a: [String], _ b: [String]) -> [[Int]] {
        var t = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0..<a.count {
            for j in 0..<b.count {
                if a[i] == b[j] { t[i+1][j+1] = t[i][j] + 1 }
                else { t[i+1][j+1] = max(t[i+1][j], t[i][j+1]) }
            }
        }
        return t
    }

    private static func backtrack(_ t: [[Int]], _ a: [String], _ b: [String]) -> [Edit] {
        var i = a.count, j = b.count
        var edits: [Edit] = []
        while i > 0 || j > 0 {
            if i > 0, j > 0, a[i-1] == b[j-1] {
                edits.append(.keep(a[i-1], i-1, j-1)); i -= 1; j -= 1
            } else if j > 0, (i == 0 || t[i][j-1] >= t[i-1][j]) {
                edits.append(.add(b[j-1], j-1)); j -= 1
            } else if i > 0 {
                edits.append(.remove(a[i-1], i-1)); i -= 1
            }
        }
        return edits.reversed()
    }

    private static func groupIntoHunks(_ edits: [Edit], contextLines: Int) -> [Hunk] {
        // Find changed regions and pad with `contextLines` of surrounding .keep edits.
        var hunks: [Hunk] = []
        var i = 0
        while i < edits.count {
            if case .keep = edits[i] { i += 1; continue }
            // Found a change. Walk back contextLines.
            let start = max(0, i - contextLines)
            var end = i
            while end < edits.count {
                if case .keep = edits[end] {
                    // Lookahead: are there more changes within 2*contextLines?
                    let lookAhead = min(end + contextLines + 1, edits.count)
                    var sawChange = false
                    for k in end..<lookAhead {
                        if case .keep = edits[k] { continue }
                        sawChange = true; break
                    }
                    if !sawChange { break }
                }
                end += 1
            }
            let finalEnd = min(edits.count, end + contextLines)
            let slice = edits[start..<finalEnd]
            var leftStart = -1, rightStart = -1
            var lines: [Line] = []
            for e in slice {
                switch e {
                case .keep(let s, let li, let ri):
                    if leftStart == -1 { leftStart = li; rightStart = ri }
                    lines.append(Line(kind: .context, text: s))
                case .add(let s, _):
                    if leftStart == -1 { /* rightStart unknown until first keep/remove */ }
                    lines.append(Line(kind: .added, text: s))
                case .remove(let s, let li):
                    if leftStart == -1 { leftStart = li }
                    lines.append(Line(kind: .removed, text: s))
                }
            }
            hunks.append(Hunk(leftStart: max(0, leftStart), rightStart: max(0, rightStart), lines: lines))
            i = finalEnd
        }
        return hunks
    }
}

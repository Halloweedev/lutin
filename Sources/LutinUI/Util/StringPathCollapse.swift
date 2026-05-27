import Foundation

extension String {
    /// Display-only collapse of `$HOME` to `~`. The model still binds the
    /// absolute path; callers use this only when rendering.
    ///
    /// Examples:
    ///   `/Users/me/Projects/Luce/lutin.yml` → `~/Projects/Luce/lutin.yml`
    ///   `/Applications/Luce.app`            → `/Applications/Luce.app`
    ///   `/Users/me`                         → `~`
    ///
    /// Symlinks are not resolved; the comparison is against the literal path prefix returned by `NSHomeDirectory()`.
    var collapsedHome: String {
        let home = NSHomeDirectory()
        guard !home.isEmpty else { return self }
        if self == home { return "~" }
        if hasPrefix(home + "/") {
            return "~" + dropFirst(home.count)
        }
        return self
    }
}

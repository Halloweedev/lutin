import LutinCore

/// Cross-checks Lutin's reading of the metadata tree against asc's.
///
/// `asc metadata validate --output json` reports `filesScanned`. Because asc
/// ignores unrecognised paths **without saying so**, a tool that writes to the
/// wrong directory gets a clean validation and a push that changes nothing.
/// Comparing the two counts turns that invisible failure into a loud one.
///
/// Verified against asc 5.3.0: the count includes `default.json` and every
/// `version/<v>/` directory present, not merely the active one.
public enum StoreMetadataGuard {

    /// - Parameter ascScanned: the `filesScanned` value from
    ///   `asc metadata validate --output json`.
    /// - Throws: `LutinError(code: "store_layout_mismatch")` when the counts
    ///   disagree, or when stray paths exist that asc would silently ignore
    ///   even though the counts happen to agree (e.g. a plural `versions/`
    ///   beside `version/` — asc reports a clean validation while pushing
    ///   nothing). `details` carries both counts and any stray paths.
    public static func assertConsistent(ascScanned: Int,
                                        local: StoreMetadataDirectory) throws {
        let expected = try local.enumeratedFileCount()
        let stray = (try? local.strayDirectories()) ?? []
        guard ascScanned == expected, stray.isEmpty else {
            var details: [String: String] = [
                "ascScanned": String(ascScanned),
                "lutinCounted": String(expected),
            ]
            if !stray.isEmpty { details["stray"] = stray.joined(separator: ", ") }

            let message: String
            if ascScanned != expected {
                message = "asc recognised \(ascScanned) metadata file(s) but Lutin found \(expected). "
                       + "asc ignores unrecognised paths silently, so a push would change "
                       + "nothing while reporting success. "
                       + (stray.isEmpty
                          ? "Check for a stray `versions/` (plural) directory."
                          : "Stray path(s): \(stray.joined(separator: ", ")).")
            } else {
                message = "Lutin found stray path(s) asc would silently ignore: "
                       + "\(stray.joined(separator: ", ")). "
                       + "asc reports a clean validation while a push would change "
                       + "nothing — remove or relocate the stray path(s)."
            }

            throw LutinError(code: "store_layout_mismatch", message: message, details: details)
        }
    }
}

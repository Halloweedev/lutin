/// The Lutin tool version. Single source of truth for `lutin --version`.
///
/// Bump this on each release, in lockstep with the git tag and the
/// Homebrew formula's `url`/`sha256`. The Homebrew test asserts the
/// installed binary reports the same version the formula declares.
public enum LutinVersion {
    public static let current = "0.2.0"
}

# macOS DMG packaging notes

Hard-won lessons from getting Lutin's DMGs to render their `.DS_Store`
layout (background image + icon positions) correctly on macOS 14+/26.

## TL;DR

For a DMG to render its background image and honor its icon positions on
modern macOS, all of the following must be true:

1. The DMG must be **code-signed with a Developer ID Application**
   certificate.
2. The DMG must be **notarized** by Apple's notary service.
3. The notarization ticket must be **stapled** to the DMG (`xcrun stapler
   staple`).
4. The DMG's filesystem must have an **Apple Partition Map**
   (`hdiutil create` default `-layout SPUD`, NOT `-layout NONE`).
5. The `.DS_Store` file at the volume root must **NOT** include a `pBBk`
   (background bookmark) record. The legacy `icvp.backgroundImageAlias`
   (Carbon alias) is the path Finder still trusts. A malformed-or-just-
   slightly-off `pBBk` will make Finder ignore the background entirely
   instead of falling back to the alias.
6. The `.DS_Store` itself must be structurally correct — see
   `Sources/LutinBuilder/DSStore/` for the byte-level details we ended
   up needing (buddy allocator magic at offset 20, root block at offset
   0x800, DSDB `levels=0`, full alias tag set 0/1/2/10/11/12/13/14/15,
   `icvp` with the full set of keys including `backgroundColor*` and
   `scrollPosition*`, `vSrn` + `icvl` records present, etc.).

## What the silver bullet was

On 2026-05-21, after most of a day of byte-level diffing against a
known-working DMG (Barry-1.9.7.dmg from 2026-05-12), the *single change*
that made Lutin's DMGs render correctly was **removing the `pBBk` record**
from `.DS_Store`. Everything else we fixed during that investigation was
either already correct or a quality improvement (proper Assets.car via
`actool`, PkgInfo, full Xcode-provenance keys in Info.plist, etc.) — but
none of those alone unlocked the background image.

## Why we (initially) added pBBk

The current `dmgbuild` Python package writes `pBBk` alongside the legacy
alias, on the theory that modern Finder prefers the bookmark format.
That's true in some contexts (e.g., LaunchServices bookmark resolution),
but for the specific case of DMG window backgrounds on macOS 26.3, Finder
seems to use a fail-fast bookmark check — if the bookmark is present and
doesn't validate exactly the way Finder wants, the background is dropped.
The legacy alias path is more lenient.

The Barry DMG that we used as our ground-truth reference was built with an
older `dmgbuild` that didn't write `pBBk`, which is why it worked.

## Verify a built DMG

```sh
DMG=release/Lutin-X.dmg

# 1. Notarized + stapled?
spctl --assess --type open --context context:primary-signature -vv "$DMG"
# expected: "accepted, source=Notarized Developer ID"
stapler validate "$DMG"
# expected: "The validate action worked!"

# 2. Partition map present?
hdiutil attach "$DMG" -nobrowse
diskutil info /Volumes/<vol> | grep "Partition Type"
# expected: "Partition Type: Apple_HFS"

# 3. No pBBk record in DS_Store?
python3 -c "
from ds_store import DSStore
with DSStore.open('/Volumes/<vol>/.DS_Store','r') as d:
    print([(e.filename, e.code) for e in d])"
# expected: no entry with code b'pBBk'
```

## Pipeline order

Lutin's `lutin release` does, in order:

1. Read `lutin.yml`, resolve app bundle + version.
2. `CodeSigner.signApp`: codesign with `--options runtime --timestamp
   --entitlements ... --sign $DEV_ID`.
3. `LutinRender.renderBackground`: render background PNG with decorations.
4. `DMGBuilder.build`:
   - `hdiutil create -fs HFS+ -volname X` (default SPUD layout).
   - `hdiutil attach -nobrowse -noverify -noautoopen -plist`.
   - Copy app + `/Applications` symlink + `.background.png`.
   - Copy `.VolumeIcon.icns` (auto-extracted from app's `AppIcon.icns`
     if no explicit `assets/VolumeIcon.icns` exists) + `SetFile -a C` on
     the volume root (sets `kHasCustomIcon`).
   - Write `.DS_Store` via `DSStoreEncoder` (no `pBBk`).
   - `hdiutil detach` + `hdiutil convert -format UDZO`.
5. `CodeSigner.signDMG`: codesign the DMG container.
6. `Notarizer.submit`: `xcrun notarytool submit --wait`.
7. `Stapler.staple`: `xcrun stapler staple`.

## Tools required

All built-in to a Mac with Xcode CLT installed:

- `swift build` (CLI binary)
- `xcrun actool` (asset catalog compilation, called from
  `LutinAppPackager.BundleAssembler`)
- `xcodebuild`, `xcrun --sdk macosx --show-sdk-version`, `sw_vers`
  (toolchain provenance, called from `InfoPlistWriter`)
- `hdiutil`, `codesign`, `SetFile`, `xcrun notarytool`, `xcrun stapler`

No third-party dependencies.

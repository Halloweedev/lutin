# Lutin

A macOS DMG packaging tool — agent-operable CLI plus a native SwiftUI app.

## Sub-projects

- **SP1** — `lutin` CLI core (`lutin init`, `lutin list`, `lutin validate`, registry).
- **SP2** — release pipeline (sign, notarize, staple, DMG build).
- **SP3** — background renderer (template + decorations).
- **SP4** — `Lutin.app` native macOS GUI (this sub-project).

## Lutin.app — Visual Editor

A native macOS GUI built on top of the same core as the CLI.

- `swift run lutin-app` launches the app.
- Project Switcher modal (⌘O or click the project name in the toolbar) selects
  a project from the registry — the permanent left sidebar is gone.
- Four-tab editor on a left icon rail:
  - **Design** — Library chips, Layers list, Inspector. Canvas on the right
    renders at 1:1 device pixels with zoom controls.
  - **Window** — width/height/iconSize/textSize/showToolbar/showSidebar.
  - **Project** — identity (name/bundleId/app.path) and output settings.
  - **Release** — signing/notarization/sparkle with populated pickers
    (`security find-identity`, `xcrun notarytool list-keychain-profiles`).
- Add items four ways: drag a `.app` from Finder, drag a Library chip,
  click the `+` toolbar menu, or right-click the canvas.
- Multi-select with ⌘-click / shift-click or marquee drag. Drag, ⌫,
  arrow-key nudge, and align/distribute all commit one undoable
  `moveMany` intent.
- Off-canvas items are flagged in the Design tab's status strip.
- Every edit goes through the same intent layer as the CLI's
  `lutin apply-intents --json`. Run `./scripts/verify-editor-parity.sh`
  to prove byte-for-byte parity between GUI and CLI.

Spec: `docs/superpowers/specs/2026-05-22-visual-editor-polish-design.md`.
Plan: `docs/superpowers/plans/2026-05-22-visual-editor-polish.md`.

## CLI quickstart

```sh
swift build
swift run lutin init MyApp
swift run lutin projects
swift run lutin build         # in a project directory containing lutin.yml
```

## Tests

```sh
swift test
```

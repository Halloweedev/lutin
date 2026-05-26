# Lutin

A macOS DMG packaging tool — agent-operable CLI plus a native SwiftUI app.

## Sub-projects

- **SP1** — `lutin` CLI core (`lutin init`, `lutin projects`, `lutin validate`, registry).
- **SP2** — release pipeline (sign, notarize, staple, DMG build).
- **SP3** — background renderer (template + decorations).
- **SP4** — `Lutin.app` native macOS GUI (this sub-project).

## Lutin.app — Visual Editor

A native macOS GUI built on top of the same core as the CLI.

- `./scripts/dev-app.sh` is the recommended local launcher. It builds the
  debug executable, assembles a real `Lutin.app`, and opens it with normal
  Dock/focus behavior.
- `swift run lutin-app` runs the bare SwiftPM executable and is mainly useful
  when debugging process startup from a terminal.
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
swift run lutin init --app /path/to/MyApp.app
swift run lutin projects
swift run lutin build         # in a project directory containing lutin.yml
```

Common CLI surfaces:

- `lutin init [--app PATH] [--template NAME]` writes `lutin.yml` in the current
  directory and registers the project.
- `lutin projects` lists registered projects.
- `lutin add PATH [--name NAME]`, `lutin remove NAME`, and
  `lutin open --name NAME` manage the project registry.
- `lutin validate [--config PATH | --name NAME]` checks `lutin.yml`.
- `lutin doctor [--config PATH | --name NAME]` checks release readiness,
  including required local tools and signing/notary configuration.
- `lutin build [--config PATH | --name NAME] [--json]` builds an unsigned DMG.
- `lutin release [--config PATH | --name NAME] [--json]` builds, signs,
  notarizes, and staples according to `lutin.yml`.
- `lutin preview [--config PATH | --name NAME] [--json]` builds the DMG, mounts
  it, and opens it in Finder for visual inspection.
- `lutin notary setup [--profile NAME] [--apple-id ID --team-id TEAM --password PASSWORD]`
  stores a notarytool keychain profile.
- `lutin apply-intents --config PATH [--file intents.json] [--json]` applies
  editor intents to a project file; omit `--file` to read intents from stdin.

## Tests

```sh
swift test
```

`swift test` runs the full suite, including macOS integration tests that create,
mount, inspect, and detach DMGs with `hdiutil` and Finder-compatible layout
metadata. If the process is interrupted, a temporary volume can be left mounted;
detach it with `hdiutil detach /Volumes/<name> -force`.

For fast iteration on docs, config, CLI parsing, and UI model code, prefer
focused filters such as:

```sh
swift test --filter LutinCLITests
swift test --filter LutinConfigTests
swift test --filter LutinDocumentTests
swift test --filter LutinUITests
```

Avoid `LutinBuilderTests`, `LutinReleaseTests`, and full unfiltered runs unless
you intentionally want the DMG/build/release integration coverage.

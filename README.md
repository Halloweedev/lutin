# Lutin

A macOS DMG packaging tool — agent-operable CLI plus a native SwiftUI app.

## Sub-projects

- **SP1** — `lutin` CLI core (`lutin init`, `lutin list`, `lutin validate`, registry).
- **SP2** — release pipeline (sign, notarize, staple, DMG build).
- **SP3** — background renderer (template + decorations).
- **SP4** — `Lutin.app` native macOS GUI (this sub-project).

## Lutin.app (SP4)

A native macOS GUI built on top of the same core as the CLI.

- `swift run lutin-app` launches the app.
- Open any project from the sidebar; design visually on the canvas; click Build.
- Every edit also works as a `.yml` change — the GUI and CLI are peers.

See `docs/superpowers/specs/2026-05-20-lutin-subproject-4-app-design.md` for design.

## CLI quickstart

```sh
swift build
swift run lutin init MyApp
swift run lutin list
swift run lutin build         # in a project directory containing lutin.yml
```

## Tests

```sh
swift test
```

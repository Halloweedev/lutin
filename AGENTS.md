# Lutin for AI agents

This guide is for LLMs and AI coding agents (Claude Code, Cursor, Codex, etc.) driving Lutin programmatically. Humans should start with [README.md](README.md).

## TL;DR

Lutin is agent-operable by design:

- **`lutin.yml` is the only source of truth.** The GUI and CLI both read and write it.
- **Every CLI subcommand accepts `--json`** and emits a structured `{ ok, data, error }` envelope.
- **Editing is via typed intents**, not raw YAML manipulation. Use `lutin apply-intents` so undo/redo, validation, and dirty-tracking stay coherent.
- **Exit codes mean something.** `0` = success; non-zero = a `LutinError` is on stderr (in JSON mode) or stdout.

If you remember nothing else: **`--json` everywhere, `apply-intents` for edits, `doctor` before `release`**.

## Core workflow

```sh
# 1. Validate the config (cheap, structural check)
lutin validate --config ./lutin.yml --json

# 2. Edit the config programmatically
echo '[{"kind":"moveItem","id":"app","x":180,"y":220}]' \
  | lutin apply-intents --config ./lutin.yml --json

# 3. Check release readiness before any expensive operation
lutin doctor --config ./lutin.yml --json

# 4. Build (unsigned) or release (signed + notarized + stapled)
lutin build --config ./lutin.yml --json
lutin release --config ./lutin.yml --json
```

Always run `doctor` before `release`. Notarization can take 30–120 seconds and fails for stupid reasons (missing keychain profile, missing entitlements) — `doctor` catches all of them locally in under a second.

## JSON envelope

Every `--json` output is shaped:

```json
{ "ok": true,  "data": { ... },           "error": null }
{ "ok": false, "data": null,              "error": { "code": "LTN_...", "message": "...", "details": { ... } } }
```

- `code` is a **stable** string identifier. Branch on this, not on the human-readable message.
- `details` is an optional `{ string: string }` map with context (paths, identifiers, etc.).
- The process exit code mirrors `ok` — non-zero on failure.

## Intent envelope

`apply-intents` reads a JSON **array** of intent envelopes, one per edit, applied in order. Each envelope has a `kind` string and the parameters that intent needs.

```json
[
  { "kind": "setProjectMetadata", "name": "MyApp", "bundleId": "com.example.myapp" },
  { "kind": "setApp", "path": "./build/MyApp.app" },
  { "kind": "setOutput", "directory": "./release", "dmgName": "MyApp-${version}.dmg", "volumeName": "MyApp" },
  { "kind": "moveItem", "id": "app", "x": 180, "y": 220 },
  { "kind": "moveItem", "id": "applications", "x": 500, "y": 220 },
  { "kind": "setWindow", "width": 680, "height": 420, "iconSize": 96, "textSize": 12 }
]
```

### Supported intent kinds

| Kind | Required fields | Notes |
|---|---|---|
| `setProjectMetadata` | `name`, `bundleId` | |
| `setApp` | `path` | Path to the `.app` bundle relative to `lutin.yml`. |
| `setOutput` | `directory`, `dmgName`, `volumeName` | `${version}`, `${name}`, `${build}` are substituted. |
| `setWindow` | `width`/`height`/`iconSize`/`textSize`/`showToolbar`/`showSidebar` (all optional) | Partial updates supported — omit fields you don't want to change. |
| `moveItem` | `id`, `x`, `y` | Top-left in device pixels. |
| `renameItemLabel` | `id`, `label` (optional — `null` clears) | |
| `deleteItem` | `id` | |
| `setItemHidden` | `id`, `hidden` | |
| `setItemID` | `id` (old), `new` | Renames the stable item ID. |
| `reorderItem` | `id`, `index` | |
| `moveMany` | `deltas: [{ kind: "item"\|"image", id?, index?, dx, dy }]` | Single undo step. |
| `addImageDecoration` | `path`, `x`, `y`, `width` | PNG/JPEG/SVG. |
| `moveImageDecoration` | `index`, `x`, `y`, `width` | |
| `deleteImageDecoration` | `index` | |
| `setImageHidden` | `index`, `hidden` | |
| `reorderImageDecoration` | `x` (fromIndex), `index` (toIndex) | |

Arrows: drawn arrows were removed — add an arrow PNG via `addImageDecoration` instead. Any `addArrow`/`deleteArrow`/etc. intent will return an error.

## Reading state

| Goal | Command |
|---|---|
| Check the installed CLI version | `lutin --version` |
| List registered projects | `lutin projects --json` |
| Read the current `lutin.yml` | Read the file directly — it's plain YAML. |
| Check the config is structurally valid | `lutin validate --config X --json` |
| Check release readiness | `lutin doctor --config X --json` |
| Preview before shipping | `lutin preview --config X --json` (mounts the DMG in Finder) |

There is no `lutin show` or `lutin get` — for read access, just read `lutin.yml`. The config format is stable and YAML-parseable.

## Writing state

**Always go through `apply-intents`.** Don't generate or hand-edit YAML directly. Reasons:

- Intents validate atomically — the file is either updated cleanly or left unchanged.
- Intents respect schema invariants (item IDs unique, coordinates in-canvas, etc.) that raw YAML doesn't.
- Intents undo/redo cleanly in the GUI if a human opens the project after you.
- The same intent applied via the GUI and the CLI produces byte-identical YAML.

If an intent kind you need doesn't exist, that's a real gap — open an issue, don't work around it with raw YAML.

## Error codes you'll actually see

Branch on `error.code`, not on the message. Common ones:

| Code prefix | Means |
|---|---|
| `LTN_CONFIG_...` | `lutin.yml` is malformed or invalid. |
| `LTN_DOCTOR_...` | A precondition for `release` is missing (no signing identity, no notary profile, etc.). |
| `LTN_BUILD_...` | DMG assembly failed (usually `hdiutil`). |
| `LTN_SIGN_...` | `codesign` failed. |
| `LTN_NOTARIZE_...` | `notarytool` failed or timed out. |
| `LTN_STAPLE_...` | `stapler` failed. |
| `LTN_INTENT_...` | An intent envelope was malformed or referenced an unknown ID. |

Full list and remediation: run any command with `--help`, or grep `LutinError(code:` in `Sources/`.

## Don'ts

- **Don't write raw YAML edits.** Use intents.
- **Don't skip `lutin doctor` in CI.** Notarization failures cost minutes; doctor catches almost all of them in milliseconds.
- **Don't parse human-readable messages.** They evolve. Codes are stable.
- **Don't assume coordinates are points.** They're device pixels at the canvas's native scale.
- **Don't try to drive the GUI directly** (no AppleScript / no synthetic mouse events). The intent layer is the supported surface — use it.

## Where to look

| Source of truth | Location |
|---|---|
| Intent envelope schema | `Sources/LutinIntentBridge/IntentEnvelope.swift` |
| Intent semantics | `Sources/LutinDocument/DocumentIntents.swift` |
| JSON envelope shape | `Sources/LutinCore/LutinError.swift` |
| Config schema | `Sources/LutinConfig/LutinConfig.swift` |
| Example project | `Examples/Barry/` |

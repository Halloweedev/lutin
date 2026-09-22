#!/usr/bin/env bash
# Records real `asc` output as test fixtures.
#
# Tests never invoke asc — they read these files. Re-record deliberately, on
# purpose, and commit the result: a fixture refresh is a reviewable event, not
# an incidental one, because invented fixtures encode the wrong contract.
#
# Usage: ./scripts/record-asc-fixtures.sh
#
# Set ASC_APP_ID to also record the real Catalog and review artifacts
# (network + auth). ASC_VERSION selects the version those review artifacts are
# read from and defaults to 1.2.3; it is only read when ASC_APP_ID is set.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO_ROOT/Tests/LutinStoreConnectTests/Fixtures"

# Resolve the optional inputs before anything destructive runs: `set -u` would
# otherwise abort on ASC_VERSION partway through, after `rm -rf` had already
# removed the committed fixtures.
ASC_VERSION="${ASC_VERSION:-1.2.3}"

if ! command -v asc >/dev/null 2>&1; then
    echo "error: asc not found. brew install asc" >&2
    exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "→ recording asc $(asc --version)"

asc --version > "$OUT/version.txt"

asc capabilities --output json > "$OUT/capabilities.json"

# A clean tree: app-info + one version, one locale.
mkdir -p "$WORK/clean/metadata"
asc metadata init --dir "$WORK/clean/metadata" --version 1.2.3 --locale en-US \
    --output json > "$OUT/metadata-init.json"
cat > "$WORK/clean/metadata/app-info/en-US.json" <<'JSON'
{"name":"MyApp","subtitle":"A subtitle","privacyPolicyUrl":"https://example.com/privacy"}
JSON
cat > "$WORK/clean/metadata/version/1.2.3/en-US.json" <<'JSON'
{"description":"A description of the app.","keywords":"alpha,beta","supportUrl":"https://example.com/support"}
JSON
asc metadata validate --dir "$WORK/clean/metadata" --output json > "$OUT/validate-clean.json"

# Warnings only — must exit 0.
mkdir -p "$WORK/warn/metadata/version/1.2.3" "$WORK/warn/metadata/app-info"
cp "$WORK/clean/metadata/app-info/en-US.json" "$WORK/warn/metadata/app-info/en-US.json"
echo '{"description":"short","supportUrl":"not-a-url"}' \
    > "$WORK/warn/metadata/version/1.2.3/en-US.json"
asc metadata validate --dir "$WORK/warn/metadata" --output json > "$OUT/validate-warnings.json"

# Errors — must exit 1.
mkdir -p "$WORK/bad/metadata/app-info"
cp "$WORK/clean/metadata/version/1.2.3/en-US.json" /dev/null 2>/dev/null || true
mkdir -p "$WORK/bad/metadata/version/1.2.3"
cp "$WORK/clean/metadata/version/1.2.3/en-US.json" "$WORK/bad/metadata/version/1.2.3/en-US.json"
echo '{"name":"ThisNameIsFarTooLongToPassTheThirtyCharacterLimit"}' \
    > "$WORK/bad/metadata/app-info/en-US.json"
set +e
asc metadata validate --dir "$WORK/bad/metadata" --output json > "$OUT/validate-errors.json" 2>&1
echo $? > "$OUT/validate-errors.exitcode"
set -e

# Schema error — exit 2, stderr only, help text appended.
mkdir -p "$WORK/schema/metadata/version/1.2.3"
echo '{"bogusField":"x"}' > "$WORK/schema/metadata/version/1.2.3/en-US.json"
set +e
asc metadata validate --dir "$WORK/schema/metadata" --output json \
    > "$OUT/validate-schema.stdout" 2> "$OUT/validate-schema.stderr"
echo $? > "$OUT/validate-schema.exitcode"
set -e

# The plural directory that asc silently ignores.
mkdir -p "$WORK/plural/metadata/app-info" "$WORK/plural/metadata/versions/1.2.3"
cp "$WORK/clean/metadata/app-info/en-US.json" "$WORK/plural/metadata/app-info/en-US.json"
cp "$WORK/clean/metadata/version/1.2.3/en-US.json" "$WORK/plural/metadata/versions/1.2.3/en-US.json"
asc metadata validate --dir "$WORK/plural/metadata" --output json > "$OUT/validate-plural-versions.json"

# Review artifacts, offline: status and approve with no plan present.
mkdir -p "$WORK/review"
set +e
asc metadata status --review-dir "$WORK/review" --output json \
    > "$OUT/review-status-missing.stdout" 2> "$OUT/review-status-missing.stderr"
echo $? > "$OUT/review-status-missing.exitcode"
set -e

# Auth state — redact the profile name, which is personal.
asc auth status --output json \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); [c.update({"name":"REDACTED","keyId":"REDACTED"}) for c in d.get("credentials",[])]; print(json.dumps(d,sort_keys=True))' \
    > "$OUT/auth-status.json"

# Web-session state. This is a *different* credential system from the ASC API
# key — 28 of asc's 48 capabilities need it. The raw output carries the Apple ID
# email and the developer team ID, so both are redacted before commit.
asc web auth status --output json \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); d.update({"appleId":"REDACTED","developerTeamId":"REDACTED"}); print(json.dumps(d,sort_keys=True))' \
    > "$OUT/web-auth-status.json"

# Optional: real Catalog and review artifacts. Set ASC_APP_ID (network + auth).
if [ -n "${ASC_APP_ID:-}" ]; then
    asc apps view --id "$ASC_APP_ID" --output json > "$OUT/apps-view.json"
    asc versions list --app "$ASC_APP_ID" --paginate --output json > "$OUT/versions-list.json"
    # pull into a temp dir, make one local edit, plan into a temp review dir —
    # plan and approve are local-only; apply is never run by this script.
    asc metadata pull --app "$ASC_APP_ID" --version "$ASC_VERSION" --dir "$WORK/real/metadata" --platform MAC_OS
    python3 - "$WORK/real/metadata" <<'PY'
import json, os, sys

root = sys.argv[1]
for base, _, files in os.walk(root):
    for name in files:
        if name.endswith(".json"):
            path = os.path.join(base, name)
            with open(path) as f:
                data = json.load(f)
            data["subtitle"] = (data.get("subtitle") or "Recorded by Lutin")[:30]
            with open(path, "w") as f:
                json.dump(data, f)
            sys.exit(0)
PY
    asc metadata plan --app "$ASC_APP_ID" --version "$ASC_VERSION" --platform MAC_OS \
        --dir "$WORK/real/metadata" --review-dir "$WORK/real/review" --output json > /dev/null
    cp "$WORK/real/review/plan.json" "$OUT/plan.json"
    asc metadata approve --review-dir "$WORK/real/review" --key "subtitle" --note "recorded" --output json > "$OUT/approved.json"
    asc metadata status --review-dir "$WORK/real/review" --output json > "$OUT/review-status.json"
    echo "→ recorded real Catalog + review fixtures for app $ASC_APP_ID" >&2
else
    echo "→ ASC_APP_ID unset: Catalog/review fixtures are the derived ones" >&2
fi

cat > "$OUT/RECORDED_WITH" <<EOF
Recorded with: $(asc --version)
Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Host: $(sw_vers -productVersion)
EOF

echo "→ wrote $(ls -1 "$OUT" | wc -l | tr -d ' ') fixtures to $OUT"

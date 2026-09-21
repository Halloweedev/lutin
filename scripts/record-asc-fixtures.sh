#!/usr/bin/env bash
# Records real `asc` output as test fixtures.
#
# Tests never invoke asc — they read these files. Re-record deliberately, on
# purpose, and commit the result: a fixture refresh is a reviewable event, not
# an incidental one, because invented fixtures encode the wrong contract.
#
# Usage: ./scripts/record-asc-fixtures.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO_ROOT/Tests/LutinStoreConnectTests/Fixtures"

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

cat > "$OUT/RECORDED_WITH" <<EOF
Recorded with: $(asc --version)
Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Host: $(sw_vers -productVersion)
EOF

echo "→ wrote $(ls -1 "$OUT" | wc -l | tr -d ' ') fixtures to $OUT"

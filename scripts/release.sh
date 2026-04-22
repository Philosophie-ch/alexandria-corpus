#!/usr/bin/env bash
# Release corpus data to a live Alexandria Nexus instance.
#
# Usage: ./scripts/release.sh [API_URL] [API_KEY]
# Defaults: http://localhost:8080 / dev-admin-key
#
# Steps:
#   1. Read version from data_version.yml
#   2. Check DB current version — fail if already at this version
#   3. Wipe DB
#   4. Import all corpus CSVs (one API call per table)
#   5. Record version in data_version table
set -euo pipefail

API="${1:-http://localhost:8080}"
KEY="${2:-dev-admin-key}"
CORPUS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$(dirname "$0")"

die() { echo "FAIL: $*" >&2; exit 1; }

# ── step 1: read version ──────────────────────────────────────────────────────

VERSION=$(python3 -c "
import sys
with open('$CORPUS_DIR/data_version.yml') as f:
    for line in f:
        line = line.strip()
        if line.startswith('version:'):
            print(line.split(':', 1)[1].strip().strip('\"'))
            sys.exit()
")
DESCRIPTION=$(python3 -c "
import sys
with open('$CORPUS_DIR/data_version.yml') as f:
    for line in f:
        line = line.strip()
        if line.startswith('description:'):
            print(line.split(':', 1)[1].strip().strip('\"'))
            sys.exit()
print('')
")

[[ -n "$VERSION" ]] || die "Could not parse version from data_version.yml"
echo "Release version: $VERSION"
echo "Description:     $DESCRIPTION"

# ── step 2: check current DB version ─────────────────────────────────────────

echo ""
echo "=== Checking current DB version ==="
CURRENT=$(curl -sf "$API/api/v1/data-version?limit=1&sort=imported_at&order=desc" \
  -H "Authorization: Bearer $KEY" \
  | python3 -c "
import json, sys
items = json.load(sys.stdin).get('items', [])
print(items[0]['version'] if items else '')
") || die "Could not reach $API"

if [[ -n "$CURRENT" ]]; then
  echo "  Current DB version: $CURRENT"
  [[ "$CURRENT" != "$VERSION" ]] || die "DB is already at version $VERSION — bump data_version.yml before releasing"
else
  echo "  No version in DB yet"
fi

# ── step 3: wipe ──────────────────────────────────────────────────────────────

echo ""
echo "=== Wiping database ==="
curl -sf -X POST "$API/api/v1/admin/wipe?confirm=true" -H "Authorization: Bearer $KEY" > /dev/null \
  || die "wipe failed"
echo "  done"

# ── step 4: import ────────────────────────────────────────────────────────────

echo ""
"$SCRIPTS_DIR/import-from-corpus.sh" "$API" "$KEY"

# ── step 5: record version ────────────────────────────────────────────────────

echo ""
echo "=== Recording version $VERSION ==="
IMPORTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
curl -sf -X POST "$API/api/v1/data-version" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json
print(json.dumps({
  'version': '$VERSION',
  'description': '$DESCRIPTION',
  'imported_at': '$IMPORTED_AT',
}))
")" > /dev/null || die "Failed to record version"
echo "  recorded version=$VERSION imported_at=$IMPORTED_AT"

echo ""
echo "RELEASE COMPLETE: version $VERSION"

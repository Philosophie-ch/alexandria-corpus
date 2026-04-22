#!/usr/bin/env bash
# Read version and description from data_version.yml and POST to the API.
#
# Usage: ./scripts/record-data-version.sh [API_URL] [API_KEY]
# Defaults: http://localhost:8080 / dev-admin-key
set -euo pipefail

API="${1:-http://localhost:8080}"
KEY="${2:-dev-admin-key}"
CORPUS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
YML="$CORPUS_DIR/data_version.yml"

die() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$YML" ] || die "data_version.yml not found at $CORPUS_DIR"

VERSION=$(python3 -c "
with open('$YML') as f:
    for line in f:
        line = line.strip()
        if line.startswith('version:'):
            print(line.split(':', 1)[1].strip().strip('\"'))
            break
")
DESCRIPTION=$(python3 -c "
with open('$YML') as f:
    for line in f:
        line = line.strip()
        if line.startswith('description:'):
            print(line.split(':', 1)[1].strip().strip('\"'))
            break
")

[ -n "$VERSION" ]     || die "version not found in data_version.yml"
[ -n "$DESCRIPTION" ] || die "description not found in data_version.yml"

IMPORTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

curl -sS --fail-with-body -X POST "$API/api/v1/data-version" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
        --arg v "$VERSION" \
        --arg d "$DESCRIPTION" \
        --arg t "$IMPORTED_AT" \
        '{version: $v, description: $d, imported_at: $t}')"

echo ""
echo "Recorded version $VERSION"

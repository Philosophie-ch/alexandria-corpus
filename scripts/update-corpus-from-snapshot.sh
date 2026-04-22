#!/usr/bin/env bash
# Pull a fresh snapshot from a running Alexandria Nexus instance and replace
# the corpus data/ directory with it.
#
# Usage: ./scripts/update-corpus-from-snapshot.sh [API_URL] [API_KEY]
# Defaults: http://localhost:8080 / dev-admin-key
#
# Preserves: data_version.yml, README.md, scripts/, .github/
# Replaces:  data/  (entirely)
set -euo pipefail

API="${1:-http://localhost:8080}"
KEY="${2:-dev-admin-key}"
CORPUS_DIR="$(cd "$(dirname "$0")/.." && pwd)"

TMPDIR_SNAP="$(mktemp -d /tmp/alx_snapshot_XXXXXX)"
trap 'rm -rf "$TMPDIR_SNAP"' EXIT

die() { echo "FAIL: $*" >&2; exit 1; }

echo "=== Fetching snapshot from $API ==="
curl -sf -X POST "$API/api/v1/admin/snapshot" \
  -H "Authorization: Bearer $KEY" \
  --output "$TMPDIR_SNAP/snapshot.zip" \
  || die "snapshot request failed"

ZIPSIZE=$(du -sh "$TMPDIR_SNAP/snapshot.zip" | cut -f1)
echo "  downloaded: $ZIPSIZE"

echo "=== Extracting ==="
unzip -q "$TMPDIR_SNAP/snapshot.zip" -d "$TMPDIR_SNAP/extracted"
ls "$TMPDIR_SNAP/extracted/"

echo "=== Replacing data/ ==="
rm -rf "$CORPUS_DIR/data"
mv "$TMPDIR_SNAP/extracted" "$CORPUS_DIR/data"

echo ""
echo "Done. Corpus data/ updated from snapshot."
echo "Review changes with: git -C $CORPUS_DIR diff --stat"

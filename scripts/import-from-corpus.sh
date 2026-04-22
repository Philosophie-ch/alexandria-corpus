#!/usr/bin/env bash
# Import all corpus CSVs into a live Alexandria Nexus instance via COPY.
#
# Usage: ./scripts/import-from-corpus.sh [API_URL] [API_KEY]
# Defaults: http://localhost:8080 / dev-admin-key
#
# Uses POST /api/v1/admin/bulk-import/{table} (PostgreSQL COPY FROM STDIN).
# Split CSVs are merged into one before uploading — one API call per table.
# Does NOT wipe first — call wipe separately if needed.
set -euo pipefail

API="${1:-http://localhost:8080}"
KEY="${2:-dev-admin-key}"
CORPUS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="$CORPUS_DIR/data"

TMPDIR_IMPORT="$(mktemp -d /tmp/alx_import_XXXXXX)"
trap 'rm -rf "$TMPDIR_IMPORT"' EXIT

# ── helpers ───────────────────────────────────────────────────────────────────

die() { echo "FAIL: $*" >&2; exit 1; }

# Merge split CSVs (skip all.csv) into one temp file and return its path.
# If there are no split files, return the all.csv path directly.
corpus_csv() {
  local dir="$DATA_DIR/$1"
  local splits
  splits=$(find "$dir" -maxdepth 1 -name "*.csv" ! -name "all.csv" | wc -l)
  if [[ "$splits" -gt 0 ]]; then
    local out="$TMPDIR_IMPORT/$1.csv"
    local first=1
    for f in "$dir"/*.csv; do
      [[ "$(basename "$f")" == "all.csv" ]] && continue
      if [[ $first -eq 1 ]]; then cat "$f" > "$out"; first=0
      else tail -n +2 "$f" >> "$out"; fi
    done
    echo "$out"
  else
    echo "$dir/all.csv"
  fi
}

bulk_import() {
  local table="$1" csv="$2"
  local resp
  resp=$(curl -sf -X POST "$API/api/v1/admin/bulk-import/$table" \
    -H "Authorization: Bearer $KEY" \
    -F "file=@$csv;type=text/csv") \
    || die "bulk-import $table failed (curl error)"
  local rows
  rows=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin)['rows'])")
  echo "  $table: rows=$rows"
}

# ── import ────────────────────────────────────────────────────────────────────

START=$(date +%s)

echo "=== Entities ==="
bulk_import "journals"      "$DATA_DIR/journal/all.csv"
bulk_import "publishers"    "$DATA_DIR/publisher/all.csv"
bulk_import "institutions"  "$DATA_DIR/institution/all.csv"
bulk_import "schools"       "$DATA_DIR/school/all.csv"
bulk_import "series"        "$DATA_DIR/series/all.csv"
bulk_import "keywords"      "$DATA_DIR/keyword/all.csv"

echo "=== Authors ==="
bulk_import "authors" "$(corpus_csv author)"

echo "=== Bibitems ==="
bulk_import "bibitems" "$(corpus_csv bibitem)"

echo "=== Bibitem junctions ==="
bulk_import "bibitem_authors"   "$(corpus_csv bibitem_authors)"
bulk_import "bibitem_keywords"  "$(corpus_csv bibitem_keywords)"

echo "=== Refs & Notes ==="
bulk_import "bibitem_refs"   "$DATA_DIR/bibitem_refs/all.csv"
bulk_import "bibitem_notes"  "$DATA_DIR/bibitem_notes/all.csv"

END=$(date +%s)
echo ""
echo "Done in $((END - START))s"

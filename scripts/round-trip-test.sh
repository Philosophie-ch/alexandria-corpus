#!/usr/bin/env bash
# Round-trip test: snapshot data → wipe → reimport → verify counts match.
#
# Usage: ./scripts/round-trip-test.sh [API_URL] [API_KEY]
# Defaults: http://localhost:8080 / dev-admin-key
set -euo pipefail

API="${1:-http://localhost:8080}"
KEY="${2:-dev-admin-key}"
CORPUS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$(dirname "$0")"

# ── helpers ───────────────────────────────────────────────────────────────────

die() { echo "FAIL: $*" >&2; exit 1; }

api_count() {
  curl -sf "$API/api/v1/$1" -H "Authorization: Bearer $KEY" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['total'])"
}

# ── step 1: pre-wipe counts ───────────────────────────────────────────────────

echo "=== Pre-wipe counts ==="
declare -A BEFORE
for table in authors bibitems journals publishers institutions schools series keywords; do
  BEFORE[$table]=$(api_count "$table")
  echo "  $table: ${BEFORE[$table]}"
done

# ── step 2: wipe ─────────────────────────────────────────────────────────────

echo ""
echo "=== Wiping database ==="
curl -sf -X POST "$API/api/v1/admin/wipe?confirm=true" -H "Authorization: Bearer $KEY" > /dev/null \
  || die "wipe failed"
echo "  done"

# ── step 3: reimport ─────────────────────────────────────────────────────────

echo ""
echo "=== Reimporting from corpus ==="
"$SCRIPTS_DIR/import-from-corpus.sh" "$API" "$KEY"

# ── step 4: post-import counts ───────────────────────────────────────────────

echo ""
echo "=== Post-import counts ==="
declare -A AFTER
for table in authors bibitems journals publishers institutions schools series keywords; do
  AFTER[$table]=$(api_count "$table")
  echo "  $table: ${AFTER[$table]}"
done

# ── step 5: assert ───────────────────────────────────────────────────────────

echo ""
echo "=== Assertions ==="
FAILED=0
for table in authors bibitems journals publishers institutions schools series keywords; do
  if [[ "${BEFORE[$table]}" == "${AFTER[$table]}" ]]; then
    echo "  OK  $table: ${BEFORE[$table]}"
  else
    echo "  FAIL $table: before=${BEFORE[$table]} after=${AFTER[$table]}"
    FAILED=1
  fi
done

echo ""
if [[ $FAILED -eq 0 ]]; then
  echo "PASS: all counts match."
else
  die "count mismatch detected (see above)"
fi

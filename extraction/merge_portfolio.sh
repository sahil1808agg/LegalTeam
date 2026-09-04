#!/usr/bin/env bash
# merge_portfolio.sh — UC4/UC5: merge every completed extraction in
# extraction/output/*_extracted.json into a single master_portfolio.json
# array, so the database/search layer (UC5) has one file to ingest instead
# of one-per-contract. Only annotates and counts — never re-derives or
# alters an extracted value, so it cannot introduce a fabrication (Legal
# Accuracy Rule 1) that wasn't already in the source extraction.
#
# Added per-entry fields:
#   contract_id           — sha256(source_filename), deterministic so the
#                            same file always maps to the same id across runs
#   source_filename        — the *_extracted.json file this entry came from
#   extraction_timestamp   — ISO 8601 UTC timestamp of this merge, not of
#                            the original extraction (extract.sh/
#                            parallel_extract.sh don't record that)
#   field_null_count       — count of the 22 schema fields whose "value" is
#                            null in the source file, computed before any
#                            of the fields above are added
#
# Usage: extraction/merge_portfolio.sh
# Input:  extraction/output/*_extracted.json
# Output: extraction/output/master_portfolio.json
#
# Files that aren't a completed extraction — e.g. the contract-extractor
# agent's {"error": "no_text_layer", ...} shape for unreadable documents,
# or anything that fails to parse as a JSON object — are skipped and
# reported, never silently folded into the portfolio as if they succeeded.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/output"
MASTER_FILE="$OUT_DIR/master_portfolio.json"

command -v jq >/dev/null || { echo "Error: jq not found — install jq" >&2; exit 1; }

if command -v sha256sum >/dev/null; then
  HASH_CMD=(sha256sum)
elif command -v shasum >/dev/null; then
  HASH_CMD=(shasum -a 256)
else
  echo "Error: no sha256sum or shasum found — needed to derive contract_id" >&2
  exit 1
fi

[[ -d "$OUT_DIR" ]] || { echo "Error: output directory not found: $OUT_DIR" >&2; exit 1; }

shopt -s nullglob
EXTRACTED_FILES=("$OUT_DIR"/*_extracted.json)
shopt -u nullglob
[[ ${#EXTRACTED_FILES[@]} -gt 0 ]] || { echo "Error: no *_extracted.json files found in $OUT_DIR — run extract.sh or parallel_extract.sh first" >&2; exit 1; }

TMP_ENTRIES="$(mktemp -d)"
trap 'rm -rf "$TMP_ENTRIES"' EXIT

ok_count=0
skip_count=0

for f in "${EXTRACTED_FILES[@]}"; do
  filename="$(basename "$f")"

  if ! jq -e 'type == "object"' "$f" >/dev/null 2>&1; then
    echo "SKIP  $filename — not a JSON object, cannot merge" >&2
    skip_count=$((skip_count + 1))
    continue
  fi

  if jq -e 'has("error")' "$f" >/dev/null 2>&1; then
    echo "SKIP  $filename — marked as a failed extraction (has an \"error\" key), not merging into portfolio" >&2
    skip_count=$((skip_count + 1))
    continue
  fi

  contract_id="$("${HASH_CMD[@]}" <<< "$filename" | cut -d' ' -f1)"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  entry_file="$TMP_ENTRIES/$(printf '%05d' "$ok_count").json"
  if ! jq \
      --arg contract_id "$contract_id" \
      --arg source_filename "$filename" \
      --arg extraction_timestamp "$timestamp" \
      '
      (to_entries | map(select(.value.value == null)) | length) as $null_count
      | {
          contract_id: $contract_id,
          source_filename: $source_filename,
          extraction_timestamp: $extraction_timestamp,
          field_null_count: $null_count
        } + .
      ' "$f" > "$entry_file" 2>/dev/null; then
    echo "SKIP  $filename — jq failed to annotate/merge this file" >&2
    skip_count=$((skip_count + 1))
    rm -f "$entry_file"
    continue
  fi

  ok_count=$((ok_count + 1))
done

[[ $ok_count -gt 0 ]] || { echo "Error: no extraction files could be merged (see SKIP lines above)" >&2; exit 1; }

jq -s 'sort_by(.source_filename)' "$TMP_ENTRIES"/*.json > "$MASTER_FILE"

echo "---"
echo "Merged $ok_count contract(s) into $MASTER_FILE ($skip_count skipped)"

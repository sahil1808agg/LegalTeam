#!/usr/bin/env bash
# run_pipeline.sh — single-command, end-to-end ContractIQ pipeline for one
# contract file (.txt or .pdf):
#
#   1. Detect file type. PDFs are converted to text via contracts/chunker.sh
#      (which wraps pdftotext, with an OCR fallback) — CLAUDE.md PDF Handling.
#   2. PDFs over --chunk-threshold-pages (default 15) are split one page per
#      chunk for parallel extraction; shorter PDFs become a single chunk.
#      Exit code 2 from chunker.sh (no text layer at all) stops the pipeline
#      immediately and routes to manual/OCR review, per CLAUDE.md.
#   3. Each chunk is extracted independently via extraction/extract.sh
#      (bounded parallelism), then field-merged: a field's value is kept only
#      when every chunk that found a non-null value for it agrees. Chunks
#      disagreeing on a field's value is never resolved silently — the merged
#      field is set to null and flagged for human review (Legal Accuracy
#      Rule 4).
#   4. The merged contract_type selects a redlining/playbooks/*.md playbook
#      (MSA/NDA only — SOW/DPA have no playbook yet in this repo) and runs
#      redlining/redline.sh against it (Redline Rules 1, 3, 6 — decision
#      support only, nothing auto-sent to a counterparty).
#   5. The merged extraction is upserted into the Notion "Contract
#      Intelligence" database via extraction/insert_hotspots.sh + Notion MCP.
#   6. extraction/merge_portfolio.sh rebuilds the searchable portfolio and
#      obligations/check_deadlines.sh scans it for deadlines within the
#      lookahead window, posting a tiered Slack alert if any are found (UC6).
#
# All deadline/date arithmetic is deterministic bash sourced from
# obligations/lib_deadlines.sh — never LLM-guessed (Legal Accuracy Rules
# 1/2). The only LLM-authored text in the final report is the Executive
# Summary and Next Steps sections, and that call is Read-only and grounded
# strictly in the deterministic artifacts this script already wrote to disk
# — it is never given free rein to state a fact on its own.
#
# Usage: ./run_pipeline.sh <contract_file> [options]
# Output: pipeline_report_<contract_stem>_<YYYY-MM-DD>.md (repo root)
#
# Options:
#   --chunk-threshold-pages N  Split PDFs over N pages into per-page chunks (default: 15)
#   --max-parallel-jobs N      Max concurrent chunk-extraction sessions (default: 4)
#   --days N                   Obligations lookahead window in days (default: 90)
#   --slack-channel CHANNEL    Slack channel for the UC6 deadline alert (default: #legal-contracts)
#   --notion-db-id ID          Override the Notion "Contract Intelligence" database id
#   --auto-notion              Auto-post the Notion insert non-interactively via MCP
#                              (default: writes a prompt file for manual review/run,
#                              same as extraction/insert_hotspots.sh's own default —
#                              a write to a shared external database gets an explicit
#                              opt-in rather than silent full automation)
#   --skip-redline             Don't run the UC2/UC3 redline comparison stage
#   --skip-notion              Don't run the UC5 Notion insert stage
#   --skip-slack               Run UC6 obligations check but never post to Slack
#                              (passes --dry-run through to check_deadlines.sh)
#   -h, --help                 Show this help

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- defaults ---------------------------------------------------------------
CHUNK_THRESHOLD_PAGES=15
MAX_PARALLEL_JOBS=4
DAYS_WINDOW=90
SLACK_CHANNEL="#legal-contracts"
NOTION_DB_ID=""
SKIP_REDLINE=0
SKIP_NOTION=0
SKIP_SLACK=0
AUTO_NOTION=0
CONTRACT_FILE=""

usage() {
  cat >&2 <<'EOF'
Usage: run_pipeline.sh <contract_file> [options]

  <contract_file>            Path to a .txt or .pdf contract (required)

  --chunk-threshold-pages N  Split PDFs over N pages into per-page chunks
                             for parallel extraction (default: 15)
  --max-parallel-jobs N      Max concurrent extraction sessions per chunk (default: 4)
  --days N                   Obligations lookahead window in days (default: 90)
  --slack-channel CHANNEL    Slack channel for the UC6 deadline alert (default: #legal-contracts)
  --notion-db-id ID          Override the Notion "Contract Intelligence" database id
  --auto-notion              Auto-post the Notion insert non-interactively via MCP
                             (default: writes a prompt file for manual review/run)
  --skip-redline             Don't run the UC2/UC3 redline comparison stage
  --skip-notion              Don't run the UC5 Notion insert stage
  --skip-slack               Run UC6 obligations check but never post to Slack
                             (passes --dry-run to check_deadlines.sh)
  -h, --help                 Show this help
EOF
}

# ---- args --------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --chunk-threshold-pages) CHUNK_THRESHOLD_PAGES="${2:-}"; shift 2 ;;
    --max-parallel-jobs) MAX_PARALLEL_JOBS="${2:-}"; shift 2 ;;
    --days) DAYS_WINDOW="${2:-}"; shift 2 ;;
    --slack-channel) SLACK_CHANNEL="${2:-}"; shift 2 ;;
    --notion-db-id) NOTION_DB_ID="${2:-}"; shift 2 ;;
    --auto-notion) AUTO_NOTION=1; shift ;;
    --skip-redline) SKIP_REDLINE=1; shift ;;
    --skip-notion) SKIP_NOTION=1; shift ;;
    --skip-slack) SKIP_SLACK=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Error: unknown argument: $1" >&2; usage; exit 1 ;;
    *)
      if [[ -n "$CONTRACT_FILE" ]]; then
        echo "Error: unexpected extra argument: $1" >&2; usage; exit 1
      fi
      CONTRACT_FILE="$1"; shift ;;
  esac
done

[[ -n "$CONTRACT_FILE" ]] || { echo "Error: <contract_file> is required" >&2; usage; exit 1; }
[[ -f "$CONTRACT_FILE" ]] || { echo "Error: file not found: $CONTRACT_FILE" >&2; exit 1; }
[[ "$CHUNK_THRESHOLD_PAGES" =~ ^[0-9]+$ ]] || { echo "Error: --chunk-threshold-pages must be a positive integer" >&2; exit 1; }
[[ "$MAX_PARALLEL_JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "Error: --max-parallel-jobs must be a positive integer" >&2; exit 1; }
[[ "$DAYS_WINDOW" =~ ^[0-9]+$ ]] || { echo "Error: --days must be a non-negative integer" >&2; exit 1; }

command -v claude >/dev/null || { echo "Error: claude CLI not found — install Claude Code" >&2; exit 1; }
command -v jq >/dev/null || { echo "Error: jq not found — install jq" >&2; exit 1; }

STEM_BASENAME="$(basename "$CONTRACT_FILE")"
STEM="${STEM_BASENAME%.*}"
EXT_LOWER="$(echo "${STEM_BASENAME##*.}" | tr '[:upper:]' '[:lower:]')"
DATE_STAMP="$(date -u +%Y-%m-%d)"
CHUNK_DIR="$REPO_ROOT/contracts/chunks/$STEM"

stage() { echo; echo "=== $* ==="; }

CLEANUP_PATHS=()
cleanup() {
  local p
  for p in "${CLEANUP_PATHS[@]:-}"; do
    [[ -n "$p" ]] && rm -rf "$p"
  done
}
trap cleanup EXIT

# ==============================================================================
# Stage 1+2 — detect file type, convert PDF via chunker.sh, chunk if oversized
# ==============================================================================
declare -a CHUNK_FILES

case "$EXT_LOWER" in
  txt)
    CHUNK_FILES=("$CONTRACT_FILE")
    ;;
  pdf)
    command -v pdfinfo >/dev/null || { echo "Error: pdfinfo not found (install poppler-utils)" >&2; exit 1; }
    PAGE_COUNT="$(pdfinfo "$CONTRACT_FILE" | awk '/^Pages:/ {print $2}')"
    [[ -n "$PAGE_COUNT" && "$PAGE_COUNT" -ge 1 ]] || { echo "Error: could not read page count from $CONTRACT_FILE" >&2; exit 1; }

    if (( PAGE_COUNT > CHUNK_THRESHOLD_PAGES )); then
      PAGES_PER_CHUNK=1
    else
      PAGES_PER_CHUNK="$PAGE_COUNT"
    fi

    stage "Converting PDF ($PAGE_COUNT pages) via contracts/chunker.sh — $PAGES_PER_CHUNK page(s)/chunk"
    set +e
    "$REPO_ROOT/contracts/chunker.sh" "$CONTRACT_FILE" "$CHUNK_DIR" "$PAGES_PER_CHUNK"
    CHUNK_STATUS=$?
    set -e
    if [[ "$CHUNK_STATUS" -eq 2 ]]; then
      echo "Error: $CONTRACT_FILE has no extractable text layer (scanned PDF) — stopping per CLAUDE.md's PDF Handling rule. Route to OCR/manual review; do not re-run until a text layer is available." >&2
      exit 2
    elif [[ "$CHUNK_STATUS" -ne 0 ]]; then
      echo "Error: contracts/chunker.sh failed (exit $CHUNK_STATUS)" >&2
      exit 1
    fi

    shopt -s nullglob
    CHUNK_FILES=("$CHUNK_DIR"/chunk_*.txt)
    shopt -u nullglob
    [[ ${#CHUNK_FILES[@]} -gt 0 ]] || { echo "Error: chunker produced no chunk files in $CHUNK_DIR" >&2; exit 1; }
    ;;
  *)
    echo "Error: unsupported file type '.$EXT_LOWER' — only .txt and .pdf are supported" >&2
    exit 1
    ;;
esac

# ==============================================================================
# Stage 3 — extract 22-field schema per chunk (parallel), then field-merge.
# Upholds Legal Accuracy Rules 1-4: never fabricates a value, absent -> null,
# every non-null value keeps its citation, and disagreement across chunks is
# flagged rather than silently resolved.
# ==============================================================================
MERGED_JSON="$REPO_ROOT/extraction/output/${STEM}_extracted.json"

if [[ "$EXT_LOWER" == "txt" ]]; then
  stage "Extracting 22-field schema"
  "$REPO_ROOT/extraction/extract.sh" "$CONTRACT_FILE"
else
  # Chunk basenames (chunk_01.txt, ...) are not unique across different
  # contracts' chunk runs, and extract.sh names its output after the input
  # basename — copy each chunk under a contract-stem-prefixed name first so
  # two run_pipeline.sh invocations can never collide on the same
  # extraction/output/*.json filename.
  EXTRACT_INPUT_DIR="$CHUNK_DIR/extract_input"
  mkdir -p "$EXTRACT_INPUT_DIR"
  CLEANUP_PATHS+=("$EXTRACT_INPUT_DIR")

  declare -a UNIQUE_INPUTS=()
  for cf in "${CHUNK_FILES[@]}"; do
    uniq="$EXTRACT_INPUT_DIR/${STEM}__$(basename "$cf")"
    cp "$cf" "$uniq"
    UNIQUE_INPUTS+=("$uniq")
  done

  stage "Extracting 22-field schema from ${#UNIQUE_INPUTS[@]} chunk(s), up to $MAX_PARALLEL_JOBS parallel"

  CHUNK_RESULTS_DIR="$(mktemp -d)"
  CLEANUP_PATHS+=("$CHUNK_RESULTS_DIR")

  extract_chunk() {
    local f="$1" stem
    stem="$(basename "$f" .txt)"
    if "$REPO_ROOT/extraction/extract.sh" "$f" >"$CHUNK_RESULTS_DIR/${stem}.log" 2>&1; then
      echo "$REPO_ROOT/extraction/output/${stem}_extracted.json" > "$CHUNK_RESULTS_DIR/${stem}.ok"
    else
      echo "FAIL  $f — see $CHUNK_RESULTS_DIR/${stem}.log" >&2
      : > "$CHUNK_RESULTS_DIR/${stem}.fail"
    fi
  }

  for f in "${UNIQUE_INPUTS[@]}"; do
    while (( $(jobs -rp | wc -l) >= MAX_PARALLEL_JOBS )); do
      wait -n
    done
    extract_chunk "$f" &
  done
  wait

  shopt -s nullglob
  OK_FILES=("$CHUNK_RESULTS_DIR"/*.ok)
  FAIL_FILES=("$CHUNK_RESULTS_DIR"/*.fail)
  shopt -u nullglob

  [[ ${#OK_FILES[@]} -gt 0 ]] || { echo "Error: every chunk extraction failed — nothing to merge (logs in $CHUNK_RESULTS_DIR)" >&2; exit 1; }
  if [[ ${#FAIL_FILES[@]} -gt 0 ]]; then
    echo "Warning: ${#FAIL_FILES[@]}/${#UNIQUE_INPUTS[@]} chunk(s) failed extraction and are excluded from the merge — see logs in $CHUNK_RESULTS_DIR" >&2
  fi

  declare -a CHUNK_JSON_PATHS=()
  for okf in "${OK_FILES[@]}"; do
    CHUNK_JSON_PATHS+=("$(cat "$okf")")
  done

  FIELDS_JSON="$(printf '%s\n' \
    contract_type counterparty_name effective_date execution_date term_length \
    termination_notice_period auto_renewal_flag renewal_notice_deadline \
    payment_amount payment_frequency payment_terms late_payment_penalty \
    limitation_of_liability_cap indemnification_clause_present \
    confidentiality_survival_period governing_law jurisdiction \
    dispute_resolution_mechanism sla_commitments sla_credit_remedy \
    data_processing_terms assignment_clause_terms | jq -R . | jq -s .)"

  jq -s --argjson fields "$FIELDS_JSON" '
    . as $chunks
    | reduce ($fields[]) as $f (
        {};
        . + { ($f): (
          ($chunks | map(.[$f]) | map(select(. != null))) as $entries
          | ($entries | map(select(.flag != null)) | (.[0].flag // null)) as $existing_flag
          | ($entries | map(select(.value != null))) as $nonnull
          | if ($nonnull | length) == 0 then
              { value: null, citation: null, flag: $existing_flag }
            else
              ($nonnull | map(.value) | unique) as $distinct
              | if ($distinct | length) == 1 then
                  ($nonnull[0] + { flag: $existing_flag })
                else
                  { value: null, citation: null,
                    flag: { type: "conflicting_extraction_across_chunks",
                            reason: ("Chunks disagree on this field'\''s value: " + ($nonnull | map(.value | tostring) | join(" | "))) } }
                end
            end
        )}
      )
  ' "${CHUNK_JSON_PATHS[@]}" > "$MERGED_JSON"

  # Move per-chunk extraction artifacts out of extraction/output/ so
  # merge_portfolio.sh (globs *_extracted.json) never mistakes a page
  # fragment for an independent contract.
  mkdir -p "$CHUNK_DIR/extracted"
  for j in "${CHUNK_JSON_PATHS[@]}"; do
    mv "$j" "$CHUNK_DIR/extracted/$(basename "$j")"
  done
fi

[[ -f "$MERGED_JSON" ]] || { echo "Error: expected extraction output not found: $MERGED_JSON" >&2; exit 1; }
jq -e 'type == "object"' "$MERGED_JSON" >/dev/null || { echo "Error: $MERGED_JSON is not a JSON object — aborting" >&2; exit 1; }
KEY_COUNT="$(jq 'keys | length' "$MERGED_JSON")"
[[ "$KEY_COUNT" -eq 22 ]] || { echo "Error: merged extraction at $MERGED_JSON has $KEY_COUNT keys, expected 22 — aborting" >&2; exit 1; }

echo "Merged extraction written to $MERGED_JSON"

# ==============================================================================
# Stage 4 — redline vs. the playbook matching the extracted contract_type
# (Redline Rules 1, 3, 6 — decision support only, nothing auto-sent).
# ==============================================================================
CONTRACT_TYPE="$(jq -r '.contract_type.value // "null"' "$MERGED_JSON")"
REDLINE_REPORT=""
REDLINE_SKIP_REASON=""

if [[ "$SKIP_REDLINE" -eq 1 ]]; then
  REDLINE_SKIP_REASON="Redline stage skipped (--skip-redline)."
else
  PLAYBOOK=""
  case "$CONTRACT_TYPE" in
    MSA) PLAYBOOK="$REPO_ROOT/redlining/playbooks/msa_playbook.md" ;;
    NDA) PLAYBOOK="$REPO_ROOT/redlining/playbooks/nda_playbook.md" ;;
  esac

  if [[ -z "$PLAYBOOK" || ! -f "$PLAYBOOK" ]]; then
    REDLINE_SKIP_REASON="No playbook available for contract_type '${CONTRACT_TYPE}' (only redlining/playbooks/msa_playbook.md and nda_playbook.md exist in this repo) — redline comparison skipped."
    echo "Warning: $REDLINE_SKIP_REASON" >&2
  else
    stage "Redlining against $(basename "$PLAYBOOK")"

    if [[ ${#CHUNK_FILES[@]} -eq 1 ]]; then
      REDLINE_INPUT="${CHUNK_FILES[0]}"
    else
      # redline.sh reads one file directly and is not chunk-aware — assemble
      # a single plain-text rendition, stripping the "[OVERLAP FROM PREVIOUS
      # CHUNK]" blocks chunker.sh inserts so duplicated boundary text isn't
      # read twice.
      REDLINE_INPUT="$CHUNK_DIR/full_text_for_redline.txt"
      awk '
        /^\[OVERLAP FROM PREVIOUS CHUNK\]$/ { skip=1; next }
        /^\[--- END OVERLAP ---\]$/ { skip=0; next }
        !skip
      ' "${CHUNK_FILES[@]}" > "$REDLINE_INPUT"
    fi

    if REDLINE_OUTPUT=$("$REPO_ROOT/redlining/redline.sh" --incoming "$REDLINE_INPUT" --playbook "$PLAYBOOK" 2>&1); then
      echo "$REDLINE_OUTPUT"
      REDLINE_REPORT="$(printf '%s\n' "$REDLINE_OUTPUT" | grep -m1 '^Written to ' | sed 's/^Written to //')"
      if [[ -z "$REDLINE_REPORT" || ! -f "$REDLINE_REPORT" ]]; then
        echo "Warning: redline.sh reported success but its output file could not be located" >&2
        REDLINE_SKIP_REASON="redline.sh ran but its report file could not be located afterward."
        REDLINE_REPORT=""
      fi
    else
      echo "$REDLINE_OUTPUT" >&2
      REDLINE_SKIP_REASON="redlining/redline.sh failed for this contract — see stderr above."
    fi
  fi
fi

# ==============================================================================
# Stage 5 — insert the merged extraction into Notion (UC5).
# ==============================================================================
NOTION_STATUS_NOTE=""

if [[ "$SKIP_NOTION" -eq 1 ]]; then
  NOTION_STATUS_NOTE="Notion insert skipped (--skip-notion)."
else
  stage "Preparing Notion insert"
  declare -a INSERT_ARGS=("$MERGED_JSON")
  [[ -n "$NOTION_DB_ID" ]] && INSERT_ARGS+=("$NOTION_DB_ID")

  INSERT_OUTPUT="$("$REPO_ROOT/extraction/insert_hotspots.sh" "${INSERT_ARGS[@]}")"
  echo "$INSERT_OUTPUT"
  PROMPT_FILE="$(printf '%s\n' "$INSERT_OUTPUT" | grep -m1 '^Prompt saved to: ' | sed 's/^Prompt saved to: //')"

  if [[ "$AUTO_NOTION" -eq 1 && -n "$PROMPT_FILE" && -f "$PROMPT_FILE" ]]; then
    stage "Auto-posting Notion insert via MCP"
    # Exact Notion MCP tool names vary by workspace/connector configuration
    # (settings.json wires "notion@anthropic-tools" as server "notion"); both
    # plausible prefixes are allowed so a name mismatch degrades to "no tool
    # available" rather than a hard failure.
    # A free-text keyword scan for "created"/"updated"/etc. is too brittle —
    # a refusal message that *describes* what it would insert (e.g. "I'd add
    # three properties, then insert this record...") contains those same
    # words without anything having been written. Ask for an explicit,
    # unambiguous marker line instead of guessing from prose.
    NOTION_AUTO_PROMPT="$(cat "$PROMPT_FILE")"$'\n\n'"After completing (or declining) the task above, end your entire response with exactly one final line, on its own: \"RESULT: SUCCESS\" if and only if you actually created or updated a Notion record just now, or \"RESULT: BLOCKED\" if you did not write anything (e.g. you are waiting on a schema decision or hit a permissions error)."
    if NOTION_RESULT=$(claude -p "$NOTION_AUTO_PROMPT" --allowedTools "Read,mcp__notion__notion-search,mcp__notion__notion-query-data-sources,mcp__notion__notion-fetch,mcp__notion__notion-create-pages,mcp__notion__notion-update-page,mcp__claude_ai_Notion__notion-search,mcp__claude_ai_Notion__notion-query-data-sources,mcp__claude_ai_Notion__notion-fetch,mcp__claude_ai_Notion__notion-create-pages,mcp__claude_ai_Notion__notion-update-page" 2>&1); then
      echo "$NOTION_RESULT"
      if grep -q '^RESULT: SUCCESS$' <<< "$NOTION_RESULT"; then
        NOTION_STATUS_NOTE="Auto-inserted/updated in Notion — see output above for the record URL."
      else
        NOTION_STATUS_NOTE="Notion auto-insert did not confirm a write — verify manually. Prompt file: $PROMPT_FILE"
      fi
    else
      echo "$NOTION_RESULT" >&2
      NOTION_STATUS_NOTE="Notion auto-insert failed — run \`claude < $PROMPT_FILE\` manually to complete the insert."
    fi
  else
    NOTION_STATUS_NOTE="Notion insert prompt prepared at $PROMPT_FILE — run \`claude < $PROMPT_FILE\` to complete the insert (or re-run with --auto-notion)."
  fi
fi

# ==============================================================================
# Stage 6 — rebuild the portfolio and run the UC6 obligations check across it
# (posts a tiered Slack alert if anything is due within --days).
# ==============================================================================
stage "Rebuilding contract portfolio"
"$REPO_ROOT/extraction/merge_portfolio.sh"

stage "Computing this contract's own obligations (for the report)"
# shellcheck source=obligations/lib_deadlines.sh
source "$REPO_ROOT/obligations/lib_deadlines.sh"

EFFECTIVE_DATE="$(jq -r '.effective_date.value // "null"' "$MERGED_JSON")"
EXECUTION_DATE="$(jq -r '.execution_date.value // "null"' "$MERGED_JSON")"
TERM_LENGTH="$(jq -r '.term_length.value // "null"' "$MERGED_JSON")"
NOTICE_PERIOD_RAW="$(jq -r '.termination_notice_period.value // "null"' "$MERGED_JSON")"
AUTO_RENEWAL="$(jq -r '.auto_renewal_flag.value // false' "$MERGED_JSON")"
RENEWAL_NOTICE_DEADLINE="$(jq -r '.renewal_notice_deadline.value // "null"' "$MERGED_JSON")"
COUNTERPARTY="$(jq -r '.counterparty_name.value // "UNKNOWN"' "$MERGED_JSON")"

EXPIRY_DATE="$(compute_expiry_date "$EFFECTIVE_DATE" "$EXECUTION_DATE" "$TERM_LENGTH")"

RENEWAL_DATE="null"
if [[ "$RENEWAL_NOTICE_DEADLINE" != "null" ]]; then
  RENEWAL_DATE="$RENEWAL_NOTICE_DEADLINE"
elif [[ "$EXPIRY_DATE" != "null" && "$NOTICE_PERIOD_RAW" != "null" ]]; then
  NOTICE_OFFSET="$(parse_duration "$NOTICE_PERIOD_RAW" || echo "")"
  if [[ -n "$NOTICE_OFFSET" ]]; then
    NOTICE_OFFSET="${NOTICE_OFFSET/+/-}"
    RENEWAL_DATE="$(date -u -d "$EXPIRY_DATE $NOTICE_OFFSET" +%Y-%m-%d 2>/dev/null || echo "null")"
  fi
fi

bucket_for() {
  local d=$1
  if (( d <= 30 )); then echo "0-30 days"
  elif (( d <= 60 )); then echo "31-60 days"
  else echo "61-90 days"
  fi
}

OBLIGATIONS_TMP="$(mktemp)"
CLEANUP_PATHS+=("$OBLIGATIONS_TMP")

for pair in "renewal:$RENEWAL_DATE" "expiry:$EXPIRY_DATE"; do
  dtype="${pair%%:*}"
  ddate="${pair#*:}"
  [[ "$ddate" == "null" ]] && continue
  days="$(days_until "$ddate" 2>/dev/null || echo "")"
  [[ -z "$days" ]] && continue
  (( days < 0 || days > DAYS_WINDOW )) && continue

  bucket="$(bucket_for "$days")"
  action="Review and confirm the $dtype position with $COUNTERPARTY."
  [[ "$dtype" == "renewal" && "$AUTO_RENEWAL" == "true" ]] && action="Auto-renewal — file a non-renewal notice before this date if not renewing, or confirm renewal terms."

  jq -cn \
    --arg dtype "$dtype" --arg ddate "$ddate" --argjson days "$days" \
    --arg bucket "$bucket" --arg action "$action" --arg counterparty "$COUNTERPARTY" \
    '{deadline_type:$dtype, deadline_date:$ddate, days_until_deadline:$days, bucket:$bucket, action_required:$action, counterparty:$counterparty}' \
    >> "$OBLIGATIONS_TMP"
done

if [[ -s "$OBLIGATIONS_TMP" ]]; then
  OBLIGATIONS_JSON="$(jq -s 'sort_by(.days_until_deadline)' "$OBLIGATIONS_TMP")"
else
  OBLIGATIONS_JSON="[]"
fi

mkdir -p "$REPO_ROOT/obligations/output"
OBLIGATIONS_SNAPSHOT="$REPO_ROOT/obligations/output/${STEM}_snapshot_${DATE_STAMP}.json"
echo "$OBLIGATIONS_JSON" > "$OBLIGATIONS_SNAPSHOT"

stage "Checking obligations portfolio-wide and posting a Slack alert if needed"
declare -a CHECK_ARGS=(--days "$DAYS_WINDOW" --channel "$SLACK_CHANNEL")
[[ "$SKIP_SLACK" -eq 1 ]] && CHECK_ARGS+=(--dry-run)
"$REPO_ROOT/obligations/check_deadlines.sh" "${CHECK_ARGS[@]}" || echo "Warning: check_deadlines.sh reported an issue — see output above" >&2

# ==============================================================================
# Build the deterministic report sections (jq-rendered, no LLM involved —
# these are the sections where a wrong figure would matter most).
# ==============================================================================
TERMS_TABLE_FILE="$(mktemp)"; CLEANUP_PATHS+=("$TERMS_TABLE_FILE")
{
  echo "| Field | Value | Citation | Flag |"
  echo "|---|---|---|---|"
  jq -r '
    def esc: if type == "string" then gsub("\\|"; "\\|") | gsub("\n"; " ") else . end;
    to_entries[] |
    (.value.value) as $v |
    ((.value.citation.paragraph_number // "") | esc) as $cite |
    (.value.flag) as $flag |
    [
      (.key | esc),
      ( if $v == null then "*Not stated in document*"
        elif ($v | type) == "object" then
          ( if ($v | has("currency")) and ($v | has("amount")) then
              (($v.currency // "") + " " + (($v.amount // "") | tostring))
            else
              ($v | to_entries | map("\(.key): \(.value)") | join("; "))
            end | esc )
        else ($v | tostring | esc) end ),
      ( if $cite == "" then "—" else $cite end ),
      ( if $flag == null then "—" else (($flag.type + ": " + $flag.reason) | esc) end )
    ] | "| " + join(" | ") + " |"
  ' "$MERGED_JSON"
} > "$TERMS_TABLE_FILE"

REDLINE_SECTION_FILE="$(mktemp)"; CLEANUP_PATHS+=("$REDLINE_SECTION_FILE")
if [[ -n "$REDLINE_REPORT" ]]; then
  tail -n +2 "$REDLINE_REPORT" > "$REDLINE_SECTION_FILE"
else
  echo "_Not run. ${REDLINE_SKIP_REASON:-No redline report was produced.}_" > "$REDLINE_SECTION_FILE"
fi

OBLIGATIONS_TABLE_FILE="$(mktemp)"; CLEANUP_PATHS+=("$OBLIGATIONS_TABLE_FILE")
{
  echo "| Bucket | Type | Date | Days Left | Action Required |"
  echo "|---|---|---|---|---|"
  if [[ "$(echo "$OBLIGATIONS_JSON" | jq 'length')" -eq 0 ]]; then
    echo "| — | — | — | — | No obligations due within $DAYS_WINDOW days for this contract. |"
  else
    echo "$OBLIGATIONS_JSON" | jq -r '.[] | "| " + .bucket + " | " + .deadline_type + " | " + .deadline_date + " | " + (.days_until_deadline | tostring) + " | " + .action_required + " |"'
  fi
} > "$OBLIGATIONS_TABLE_FILE"

# ==============================================================================
# LLM synthesis — Executive Summary + Next Steps only. Read-only, grounded
# strictly in the three files already written above; the model is not asked
# (and not permitted, via --allowedTools) to write, save, or invent anything.
# ==============================================================================
stage "Drafting Executive Summary and Next Steps"

SYNTHESIS_PROMPT=$(cat <<PROMPT_EOF
You are drafting two sections of a legal contract pipeline report for a
non-lawyer business stakeholder. Read these files — do not use any other
source, and do not invent a fact, date, party name, amount, or citation
that isn't in them (Legal Accuracy Rules 1-4 from CLAUDE.md):

1. Extraction data (22-field schema with citations/flags): $MERGED_JSON
2. Redline report: ${REDLINE_REPORT:-"NONE — reason: $REDLINE_SKIP_REASON"}
3. This contract's obligations snapshot (deterministic, already computed —
   do not recompute or alter any date or day-count in it): $OBLIGATIONS_SNAPSHOT

Output ONLY the following two markdown sections, in this exact order, with
no commentary before or after, starting exactly with "## Executive Summary":

## Executive Summary

Exactly 3 bullet points in plain, non-lawyer language covering: (1) what
this contract is and who the counterparty is, (2) the single most
important redline risk if any HIGH-risk deviation exists in file 2 (or a
note that none was found / redline wasn't run), (3) the nearest upcoming
obligation deadline from file 3 if one exists (or a note that none is due
within the window).

## Next Steps

A prioritized bulleted action list (most urgent first, 3-6 items) drawn
only from: HIGH-risk redline deviations in file 2, flagged/ambiguous
fields in file 1, and obligations in file 3. Each item must include a
suggested owner (e.g. "Contract Owner", "Legal Ops", "Outside Counsel")
and a deadline suggestion grounded in an actual date already present in
these files (or "no fixed deadline" if none applies). Label every item as
a suggestion for lawyer review — never as a decision already made or
auto-executed (CLAUDE.md Redline Rule 6).

Do not attempt to write, save, or create any file, and do not use any tool
other than reading the files named above. Never mention tools,
permissions, or your own process anywhere in the response.
PROMPT_EOF
)

SYNTHESIS_OK=1
SYNTHESIS_OUTPUT="$(claude -p "$SYNTHESIS_PROMPT" --allowedTools "Read" --output-format text < /dev/null)" || SYNTHESIS_OK=0

FIRST_LINE="$(grep -m1 -v '^[[:space:]]*$' <<< "$SYNTHESIS_OUTPUT" || true)"
if [[ "$SYNTHESIS_OK" -eq 0 ]] \
   || [[ -z "$(tr -d '[:space:]' <<< "$SYNTHESIS_OUTPUT")" ]] \
   || [[ "$FIRST_LINE" != "## Executive Summary" ]] \
   || ! grep -q '^## Next Steps' <<< "$SYNTHESIS_OUTPUT"; then
  echo "Warning: report synthesis was empty, failed, or malformed — substituting a placeholder for Executive Summary/Next Steps. Review the Extracted Terms Table, Redline Report, and Obligations Calendar sections directly." >&2
  EXEC_SUMMARY_SECTION=$'## Executive Summary\n\n_Could not be generated automatically this run — review the Extracted Terms Table, Redline Report, and Obligations Calendar sections below directly._'
  NEXT_STEPS_SECTION=$'## Next Steps\n\n_Could not be generated automatically this run — review flagged fields, HIGH-risk redline deviations, and the Obligations Calendar above, and assign owners/deadlines manually._'
else
  EXEC_SUMMARY_SECTION="$(awk '/^## Next Steps/{exit} {print}' <<< "$SYNTHESIS_OUTPUT")"
  NEXT_STEPS_SECTION="$(awk '/^## Next Steps/{f=1} f' <<< "$SYNTHESIS_OUTPUT")"
fi

# ==============================================================================
# Assemble the final report.
# ==============================================================================
REPORT_FILE="$REPO_ROOT/pipeline_report_${STEM}_${DATE_STAMP}.md"

SLACK_NOTE=""
[[ "$SKIP_SLACK" -eq 1 ]] && SLACK_NOTE=" (Slack posting was skipped this run: --skip-slack.)"

{
  echo "# Pipeline Report — $STEM"
  echo
  echo "**Source file:** $CONTRACT_FILE  "
  echo "**Generated:** $DATE_STAMP  "
  echo "**Contract type:** $CONTRACT_TYPE  "
  echo
  echo "$EXEC_SUMMARY_SECTION"
  echo
  echo "## Extracted Terms Table"
  echo
  echo "22-field hotspot schema — full citations/flags in \`$MERGED_JSON\`."
  echo
  cat "$TERMS_TABLE_FILE"
  echo
  echo "## Redline Report"
  echo
  cat "$REDLINE_SECTION_FILE"
  echo
  echo "## Obligations Calendar (next $DAYS_WINDOW days)"
  echo
  cat "$OBLIGATIONS_TABLE_FILE"
  echo
  echo "_Portfolio-wide obligations were also rescanned this run — see \`obligations/output/deadline_alerts_${DATE_STAMP}.json\` and the Slack channel $SLACK_CHANNEL for any other contracts due.${SLACK_NOTE}_"
  echo
  echo "$NEXT_STEPS_SECTION"
  echo
  echo "---"
  echo
  echo "_Notion: ${NOTION_STATUS_NOTE}_"
  echo
  echo "_This report is decision support only. No redline is sent to a counterparty, no obligation action is executed, and no fallback clause is inserted without explicit lawyer sign-off (CLAUDE.md Redline Rules 3 and 6)._"
} > "$REPORT_FILE"

echo
echo "=== Pipeline complete ==="
echo "Extraction:  $MERGED_JSON"
if [[ -n "$REDLINE_REPORT" ]]; then
  echo "Redline:     $REDLINE_REPORT"
else
  echo "Redline:     skipped ($REDLINE_SKIP_REASON)"
fi
echo "Notion:      $NOTION_STATUS_NOTE"
echo "Obligations: $OBLIGATIONS_SNAPSHOT"
echo "Report:      $REPORT_FILE"

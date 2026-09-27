#!/usr/bin/env bash
# morning_digest.sh — UC6: daily all-contracts summary across the merged
# portfolio and any open redline reports.
#
# Reports four numbers, each derived without any LLM guessing (Legal
# Accuracy Rules 1/2 — pure jq/date arithmetic; see obligations/lib_deadlines.sh):
#
#   total_active           Contracts in master_portfolio.json whose computed
#                          expiry_date is null (unknown/perpetual term) or
#                          still in the future.
#   expiring_this_quarter  Of those active contracts, ones whose expiry_date
#                          falls between today and the end of the current
#                          calendar quarter.
#   high_risk_deviations   Total rows whose Risk Level column starts with
#                          "HIGH" across every redlining/output/*.md report.
#                          Redline reports are pre-execution negotiation
#                          drafts for an *incoming* counterparty document —
#                          they have no reliable filename/id link back to a
#                          specific executed contract_id in the portfolio, so
#                          this is reported portfolio-wide (with a per-report
#                          breakdown), not attributed to one contract.
#   missing_sla_terms      MSA/SOW contracts (the types the 22-field schema
#                          says sla_commitments/sla_credit_remedy primarily
#                          apply to) where either field is null.
#
# Usage: obligations/morning_digest.sh [--portfolio PATH] [--redline-dir PATH]
#                                       [--slack] [--channel CHANNEL]
#
# Reads:  extraction/output/master_portfolio.json
#         (built by extraction/merge_portfolio.sh — run that first if this
#         script reports the file missing)
#         redlining/output/*.md (optional — an empty/missing dir just means
#         zero open redlines, not an error)
# Writes: obligations/output/morning_digest_<today>.md
#         obligations/output/morning_digest_<today>.json
# Posts:  with --slack, one Slack message via `claude -p` +
#         mcp__claude_ai_Slack__slack_send_message (MCP posting only works
#         from a local Claude Code session, not from GitHub Actions — see
#         check_deadlines.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PORTFOLIO_FILE="$REPO_ROOT/extraction/output/master_portfolio.json"
REDLINE_DIR="$REPO_ROOT/redlining/output"
OUT_DIR="$SCRIPT_DIR/output"
CHANNEL="#legal-contracts"
POST_SLACK=0

usage() {
  cat >&2 <<'EOF'
Usage: morning_digest.sh [--portfolio PATH] [--redline-dir PATH] [--slack] [--channel CHANNEL]

  --portfolio   Path to the merged portfolio JSON (default: extraction/output/master_portfolio.json)
  --redline-dir Directory of redline reports to scan (default: redlining/output)
  --slack       Also post the digest to Slack via claude -p + Slack MCP
  --channel     Slack channel to post to if --slack is set (default: #legal-contracts)
  -h|--help     Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --portfolio) PORTFOLIO_FILE="${2:-}"; shift 2 ;;
    --redline-dir) REDLINE_DIR="${2:-}"; shift 2 ;;
    --slack) POST_SLACK=1; shift ;;
    --channel) CHANNEL="${2:-#legal-contracts}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

command -v jq >/dev/null || { echo "Error: jq not found — install jq" >&2; exit 1; }
if [[ "$POST_SLACK" -eq 1 ]]; then
  command -v claude >/dev/null || { echo "Error: claude CLI not found — install it or drop --slack" >&2; exit 1; }
fi

[[ -f "$PORTFOLIO_FILE" ]] || {
  echo "Error: portfolio file not found: $PORTFOLIO_FILE" >&2
  echo "Run extraction/merge_portfolio.sh first to build it from extraction/output/*_extracted.json" >&2
  exit 1
}

mkdir -p "$OUT_DIR"

# shellcheck source=obligations/lib_deadlines.sh
source "$SCRIPT_DIR/lib_deadlines.sh"

# --- current calendar quarter boundaries -----------------------------------
YEAR="$(date -u -d "$TODAY" +%Y)"
MONTH="$((10#$(date -u -d "$TODAY" +%m)))"
QUARTER=$(( (MONTH - 1) / 3 + 1 ))
QUARTER_START_MONTH=$(( (QUARTER - 1) * 3 + 1 ))
QUARTER_START="$(printf '%04d-%02d-01' "$YEAR" "$QUARTER_START_MONTH")"
QUARTER_END="$(date -u -d "$QUARTER_START +3 months -1 day" +%Y-%m-%d)"
QUARTER_END_EPOCH="$(date -u -d "$QUARTER_END" +%s)"

# --- pass 1: walk the portfolio for active / expiring-this-quarter / SLA ----
ACTIVE_TMP=$(mktemp)
EXPIRING_TMP=$(mktemp)
SLA_TMP=$(mktemp)

TOTAL_CONTRACTS=0
while IFS= read -r entry; do
  jq -e 'has("contract_type")' <<<"$entry" >/dev/null 2>&1 || continue
  ((++TOTAL_CONTRACTS)) || true

  source_filename=$(jq -r '.source_filename // "unknown"' <<<"$entry")
  contract_name="${source_filename%_extracted.json}"
  contract_type=$(jq -r '.contract_type.value // "UNKNOWN"' <<<"$entry")
  counterparty=$(jq -r '.counterparty_name.value // "UNKNOWN"' <<<"$entry")
  effective_date=$(jq -r '.effective_date.value // "null"' <<<"$entry")
  execution_date=$(jq -r '.execution_date.value // "null"' <<<"$entry")
  term_length=$(jq -r '.term_length.value // "null"' <<<"$entry")
  sla_commitments=$(jq -r '.sla_commitments.value // "null"' <<<"$entry")
  sla_credit_remedy=$(jq -r '.sla_credit_remedy.value // "null"' <<<"$entry")

  expiry_date=$(compute_expiry_date "$effective_date" "$execution_date" "$term_length")

  is_active=0
  if [[ "$expiry_date" == "null" ]]; then
    is_active=1
  else
    exp_epoch=$(date -u -d "$expiry_date" +%s 2>/dev/null || echo "")
    [[ -n "$exp_epoch" && "$exp_epoch" -ge "$TODAY_EPOCH" ]] && is_active=1
  fi

  if [[ "$is_active" -eq 1 ]]; then
    jq -cn \
      --arg n "$contract_name" --arg c "$counterparty" --arg t "$contract_type" \
      --arg e "$expiry_date" \
      '{contract_name:$n, counterparty:$c, contract_type:$t, expiry_date: (if $e == "null" then null else $e end)}' \
      >> "$ACTIVE_TMP"

    if [[ "$expiry_date" != "null" ]]; then
      exp_epoch="$(date -u -d "$expiry_date" +%s)"
      if (( exp_epoch <= QUARTER_END_EPOCH )); then
        jq -cn \
          --arg n "$contract_name" --arg c "$counterparty" --arg t "$contract_type" --arg e "$expiry_date" \
          '{contract_name:$n, counterparty:$c, contract_type:$t, expiry_date:$e}' \
          >> "$EXPIRING_TMP"
      fi
    fi
  fi

  # SLA fields primarily apply to MSA/SOW per the 22-field schema (CLAUDE.md)
  if [[ "$contract_type" == "MSA" || "$contract_type" == "SOW" ]]; then
    if [[ "$sla_commitments" == "null" || "$sla_credit_remedy" == "null" ]]; then
      missing_commitments=false; [[ "$sla_commitments" == "null" ]] && missing_commitments=true
      missing_credit_remedy=false; [[ "$sla_credit_remedy" == "null" ]] && missing_credit_remedy=true
      jq -cn \
        --arg n "$contract_name" --arg c "$counterparty" --arg t "$contract_type" \
        --argjson mc "$missing_commitments" --argjson mr "$missing_credit_remedy" \
        '{contract_name:$n, counterparty:$c, contract_type:$t, missing_sla_commitments:$mc, missing_sla_credit_remedy:$mr}' \
        >> "$SLA_TMP"
    fi
  fi
done < <(jq -c '.[]' "$PORTFOLIO_FILE")

TOTAL_ACTIVE=$(wc -l < "$ACTIVE_TMP" | tr -d ' ')
EXPIRING_COUNT=$(wc -l < "$EXPIRING_TMP" | tr -d ' ')
MISSING_SLA_COUNT=$(wc -l < "$SLA_TMP" | tr -d ' ')

ACTIVE_JSON=$(jq -s '.' "$ACTIVE_TMP")
EXPIRING_JSON=$(jq -s 'sort_by(.expiry_date)' "$EXPIRING_TMP")
SLA_JSON=$(jq -s '.' "$SLA_TMP")

# --- pass 2: scan redline reports for HIGH-risk deviation rows --------------
# Table format is fixed by redlining/redline.sh:
#   | # | Clause | Standard Position | Counterparty Position | Deviation (YES/NO) | Risk Level | Recommended Response |
# Risk Level is the 6th content column ($7 after an awk -F'|' split, since
# $1 is the empty string before the leading pipe). Header/separator rows are
# excluded with the same grep patterns redline.sh itself uses to validate a
# report's row count, so this stays consistent with how reports are written.
REDLINE_BREAKDOWN_TMP=$(mktemp)
trap 'rm -f "$ACTIVE_TMP" "$EXPIRING_TMP" "$SLA_TMP" "$REDLINE_BREAKDOWN_TMP"' EXIT

HIGH_TOTAL=0
REPORT_COUNT=0
shopt -s nullglob
REDLINE_FILES=("$REDLINE_DIR"/*.md)
shopt -u nullglob

for f in "${REDLINE_FILES[@]}"; do
  ((++REPORT_COUNT)) || true
  high_count=$(grep -E '^\|' "$f" \
    | grep -vE '^\| *# *\|' \
    | grep -vE '^\|[-| ]+\|$' \
    | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $7); if (tolower($7) ~ /^high/) print}' \
    | wc -l | tr -d ' ')
  HIGH_TOTAL=$(( HIGH_TOTAL + high_count ))
  jq -cn --arg report "$(basename "$f")" --argjson high "$high_count" \
    '{report: $report, high_risk_deviations: $high}' >> "$REDLINE_BREAKDOWN_TMP"
done

REDLINE_BREAKDOWN_JSON=$(jq -s 'sort_by(-.high_risk_deviations)' "$REDLINE_BREAKDOWN_TMP")

# --- assemble digest ---------------------------------------------------------
DIGEST_JSON=$(jq -n \
  --arg date "$TODAY" \
  --arg quarter "Q$QUARTER $YEAR" \
  --arg quarter_start "$QUARTER_START" \
  --arg quarter_end "$QUARTER_END" \
  --argjson total_contracts "$TOTAL_CONTRACTS" \
  --argjson total_active "$TOTAL_ACTIVE" \
  --argjson expiring_count "$EXPIRING_COUNT" \
  --argjson expiring_contracts "$EXPIRING_JSON" \
  --argjson high_risk_total "$HIGH_TOTAL" \
  --argjson high_risk_by_report "$REDLINE_BREAKDOWN_JSON" \
  --argjson missing_sla_count "$MISSING_SLA_COUNT" \
  --argjson missing_sla_contracts "$SLA_JSON" \
  '{
    date: $date,
    current_quarter: $quarter,
    quarter_start: $quarter_start,
    quarter_end: $quarter_end,
    total_contracts: $total_contracts,
    total_active: $total_active,
    expiring_this_quarter: { count: $expiring_count, contracts: $expiring_contracts },
    high_risk_deviations: { total: $high_risk_total, by_report: $high_risk_by_report },
    missing_sla_terms: { count: $missing_sla_count, contracts: $missing_sla_contracts }
  }')

DIGEST_FILE_JSON="$OUT_DIR/morning_digest_$TODAY.json"
DIGEST_FILE_MD="$OUT_DIR/morning_digest_$TODAY.md"
echo "$DIGEST_JSON" > "$DIGEST_FILE_JSON"

{
  echo "# Morning Digest — $TODAY"
  echo ""
  echo "**Current quarter:** Q$QUARTER $YEAR ($QUARTER_START to $QUARTER_END)"
  echo ""
  echo "| Metric | Count |"
  echo "|---|---|"
  echo "| Total active contracts | $TOTAL_ACTIVE (of $TOTAL_CONTRACTS total) |"
  echo "| Expiring this quarter | $EXPIRING_COUNT |"
  echo "| High-risk deviations (open redlines) | $HIGH_TOTAL |"
  echo "| Contracts missing SLA terms | $MISSING_SLA_COUNT |"
  echo ""

  echo "## Expiring This Quarter ($QUARTER_END)"
  echo ""
  if [[ "$EXPIRING_COUNT" -eq 0 ]]; then
    echo "None."
  else
    echo "$EXPIRING_JSON" | jq -r '.[] | "- **\(.counterparty)** (\(.contract_name), \(.contract_type)) — expires \(.expiry_date)"'
  fi
  echo ""

  echo "## High-Risk Deviations (Open Redlines)"
  echo ""
  if [[ "$REPORT_COUNT" -eq 0 ]]; then
    echo "No redline reports found in $REDLINE_DIR."
  elif [[ "$HIGH_TOTAL" -eq 0 ]]; then
    echo "$REPORT_COUNT open redline report(s) scanned — no HIGH-risk deviations."
  else
    echo "$HIGH_TOTAL HIGH-risk deviation(s) across $REPORT_COUNT open redline report(s):"
    echo ""
    echo "$REDLINE_BREAKDOWN_JSON" | jq -r '.[] | select(.high_risk_deviations > 0) | "- \(.report): \(.high_risk_deviations) HIGH"'
  fi
  echo ""

  echo "## Contracts Missing SLA Terms (MSA/SOW)"
  echo ""
  if [[ "$MISSING_SLA_COUNT" -eq 0 ]]; then
    echo "None."
  else
    echo "$SLA_JSON" | jq -r '.[] | "- **\(.counterparty)** (\(.contract_name), \(.contract_type)): " +
      ([ (if .missing_sla_commitments then "no sla_commitments" else empty end),
         (if .missing_sla_credit_remedy then "no sla_credit_remedy" else empty end) ] | join(", "))'
  fi
} > "$DIGEST_FILE_MD"

cat "$DIGEST_FILE_MD"
echo "" >&2
echo "Written: $DIGEST_FILE_MD" >&2
echo "Written: $DIGEST_FILE_JSON" >&2

if [[ "$POST_SLACK" -eq 0 ]]; then
  exit 0
fi

PROMPT=$(cat <<PROMPT_EOF
You will read a markdown digest file and post it to Slack via MCP.

File to read: $DIGEST_FILE_MD

This file already contains the final, correct numbers and contract lists —
do not recompute, second-guess, or alter any count or date in it, and never
invent a contract or number not present in the file (Legal Accuracy Rule 1 —
no fabrication).

Task:
1. Read the file.
2. Post it as a single well-formatted Slack message to: $CHANNEL
   - Keep the four headline metrics (total active, expiring this quarter,
     high-risk deviations, missing SLA terms) prominent at the top.
   - Preserve the section breakdown below them.
   - Use emoji for quick scanning (e.g. 📊 for the headline, ⚠️ for high-risk
     deviations, 🕑 for expiring-this-quarter, 📋 for missing SLA terms).
3. Use mcp__claude_ai_Slack__slack_send_message to post.

Go ahead and post the message to Slack now.
PROMPT_EOF
)

OUTPUT=$(claude -p "$PROMPT" --allowedTools "Read,mcp__claude_ai_Slack__slack_send_message" 2>&1 || true)
echo "$OUTPUT"

if echo "$OUTPUT" | grep -qi "posted\|sent\|success"; then
  echo "Digest posted to Slack." >&2
  exit 0
elif echo "$OUTPUT" | grep -qi "error\|failed"; then
  echo "Error: Claude/Slack MCP reported a failure — see output above" >&2
  exit 1
else
  echo "Warning: unclear result from claude -p — check output above" >&2
  exit 1
fi

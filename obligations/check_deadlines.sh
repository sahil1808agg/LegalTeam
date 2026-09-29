#!/usr/bin/env bash
# check_deadlines.sh — UC6: scan the merged contract portfolio for upcoming
# renewal-notice and expiry deadlines, then post a tiered Slack alert digest.
#
# Legal Accuracy Rules 1/2 (CLAUDE.md): all date arithmetic in this script is
# deterministic bash/jq, never LLM-guessed. expiry_date, renewal_date,
# days_to_expiry, days_to_renewal, and the urgency tier are all computed here
# and treated as final by the time the embedded Claude prompt runs. The
# prompt is only asked to draft a recommended_action (an advisory suggestion,
# per Redline Rule 6 — never an auto-executed decision) and to format/post
# the Slack alert; it must not recompute or invent a date, contract, or
# counterparty that isn't already in the candidate file.
#
# Reads:   extraction/output/master_portfolio.json
#          (built by extraction/merge_portfolio.sh — run that first if this
#          script reports the file missing)
# Writes:  obligations/output/deadline_alerts_<today>.json
#          (the filtered, tiered candidate list — one entry per contract per
#          triggering deadline type, so a contract can appear twice if both
#          its renewal and expiry dates fall inside the window)
# Posts:   one Slack message per non-empty urgency tier, via
#          `claude -p` + mcp__claude_ai_Slack__slack_send_message
#          (skipped with --dry-run; the prompt and candidate file are still
#          written to disk so the run can be reviewed before posting)
#
# Usage: obligations/check_deadlines.sh [--days N] [--channel CHANNEL]
#                                        [--portfolio PATH] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PORTFOLIO_FILE="$REPO_ROOT/extraction/output/master_portfolio.json"
OUT_DIR="$SCRIPT_DIR/output"
DAYS_WINDOW=90
CHANNEL="#legal-contracts"
DRY_RUN=0

usage() {
  cat >&2 <<'EOF'
Usage: check_deadlines.sh [--days N] [--channel CHANNEL] [--portfolio PATH] [--dry-run]

  --days       Lookahead window in days for renewal AND expiry dates (default: 90)
  --channel    Slack channel to post alerts to (default: #legal-contracts)
  --portfolio  Path to the merged portfolio JSON (default: extraction/output/master_portfolio.json)
  --dry-run    Compute candidates and build the Claude prompt, but don't call
               claude/Slack — prints the prompt instead
  -h|--help    Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) DAYS_WINDOW="${2:-90}"; shift 2 ;;
    --channel) CHANNEL="${2:-#legal-contracts}"; shift 2 ;;
    --portfolio) PORTFOLIO_FILE="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

command -v jq >/dev/null || { echo "Error: jq not found — install jq" >&2; exit 1; }
if [[ "$DRY_RUN" -eq 0 ]]; then
  command -v claude >/dev/null || { echo "Error: claude CLI not found — install it or use --dry-run" >&2; exit 1; }
fi

[[ -f "$PORTFOLIO_FILE" ]] || {
  echo "Error: portfolio file not found: $PORTFOLIO_FILE" >&2
  echo "Run extraction/merge_portfolio.sh first to build it from extraction/output/*_extracted.json" >&2
  exit 1
}

mkdir -p "$OUT_DIR"

# shellcheck source=obligations/lib_deadlines.sh
source "$SCRIPT_DIR/lib_deadlines.sh"

urgency_tier() {
  local d=$1
  if (( d < 30 )); then echo "URGENT"
  elif (( d < 60 )); then echo "ACTION_NEEDED"
  else echo "WATCH"
  fi
}

CANDIDATES_TMP=$(mktemp)
trap 'rm -f "$CANDIDATES_TMP"' EXIT

total=0
while IFS= read -r entry; do
  ((++total)) || true

  jq -e 'has("contract_type")' <<<"$entry" >/dev/null 2>&1 || continue

  source_filename=$(jq -r '.source_filename // "unknown"' <<<"$entry")
  contract_id=$(jq -r '.contract_id // "unknown"' <<<"$entry")
  contract_name="${source_filename%_extracted.json}"
  contract_type=$(jq -r '.contract_type.value // "UNKNOWN"' <<<"$entry")
  counterparty=$(jq -r '.counterparty_name.value // "UNKNOWN"' <<<"$entry")
  effective_date=$(jq -r '.effective_date.value // "null"' <<<"$entry")
  execution_date=$(jq -r '.execution_date.value // "null"' <<<"$entry")
  term_length=$(jq -r '.term_length.value // "null"' <<<"$entry")
  notice_period_raw=$(jq -r '.termination_notice_period.value // "null"' <<<"$entry")
  auto_renewal=$(jq -r '.auto_renewal_flag.value // false' <<<"$entry")
  renewal_notice_deadline=$(jq -r '.renewal_notice_deadline.value // "null"' <<<"$entry")

  # expiry_date = start_date (effective_date, else execution_date) + term_length
  expiry_date=$(compute_expiry_date "$effective_date" "$execution_date" "$term_length")

  # renewal_date = the extracted notice deadline if present, else
  # expiry_date minus the termination notice period
  renewal_date="null"
  if [[ "$renewal_notice_deadline" != "null" ]]; then
    renewal_date="$renewal_notice_deadline"
  elif [[ "$expiry_date" != "null" && "$notice_period_raw" != "null" ]]; then
    notice_offset=$(parse_duration "$notice_period_raw" || echo "")
    if [[ -n "$notice_offset" ]]; then
      notice_offset="${notice_offset/+/-}"
      renewal_date=$(date -u -d "$expiry_date $notice_offset" +%Y-%m-%d 2>/dev/null || echo "null")
    fi
  fi

  notice_period_days=$(duration_to_days "$notice_period_raw" 2>/dev/null || echo "null")

  days_to_expiry="null"
  [[ "$expiry_date" != "null" ]] && days_to_expiry=$(days_until "$expiry_date" || echo "null")

  days_to_renewal="null"
  [[ "$renewal_date" != "null" ]] && days_to_renewal=$(days_until "$renewal_date" || echo "null")

  for pair in "renewal:$renewal_date:$days_to_renewal" "expiry:$expiry_date:$days_to_expiry"; do
    deadline_type="${pair%%:*}"
    rest="${pair#*:}"
    deadline_date="${rest%%:*}"
    days_remaining="${rest#*:}"

    [[ "$deadline_date" == "null" || "$days_remaining" == "null" ]] && continue
    (( days_remaining < 0 || days_remaining > DAYS_WINDOW )) && continue

    tier=$(urgency_tier "$days_remaining")

    jq -cn \
      --arg contract_name "$contract_name" \
      --arg counterparty "$counterparty" \
      --arg contract_type "$contract_type" \
      --arg deadline_type "$deadline_type" \
      --arg deadline_date "$deadline_date" \
      --argjson days_until_deadline "$days_remaining" \
      --arg urgency_tier "$tier" \
      --arg auto_renewal "$auto_renewal" \
      --arg notice_period_days "$notice_period_days" \
      --arg notice_period_raw "$notice_period_raw" \
      --arg source_filename "$source_filename" \
      --arg contract_id "$contract_id" \
      '{
        contract_name: $contract_name,
        counterparty: $counterparty,
        contract_type: $contract_type,
        deadline_type: $deadline_type,
        deadline_date: $deadline_date,
        days_until_deadline: $days_until_deadline,
        urgency_tier: $urgency_tier,
        auto_renewal: ($auto_renewal == "true"),
        notice_period_days: (if $notice_period_days == "null" then null else ($notice_period_days | tonumber) end),
        notice_period_raw: (if $notice_period_raw == "null" then null else $notice_period_raw end),
        source_filename: $source_filename,
        contract_id: $contract_id
      }' >> "$CANDIDATES_TMP"
  done
done < <(jq -c '.[]' "$PORTFOLIO_FILE")

CANDIDATE_COUNT=$(wc -l < "$CANDIDATES_TMP" | tr -d ' ')
ALERTS_FILE="$OUT_DIR/deadline_alerts_$TODAY.json"

if [[ "$CANDIDATE_COUNT" -gt 0 ]]; then
  jq -s 'sort_by(.days_until_deadline)' "$CANDIDATES_TMP" > "$ALERTS_FILE"
else
  echo "[]" > "$ALERTS_FILE"
fi

echo "Scanned $total contract(s) in $PORTFOLIO_FILE; $CANDIDATE_COUNT deadline(s) within $DAYS_WINDOW days -> $ALERTS_FILE" >&2

if [[ "$CANDIDATE_COUNT" -eq 0 ]]; then
  echo "No deadlines within the window — nothing to post." >&2
  exit 0
fi

PROMPT=$(cat <<PROMPT_EOF
You will read a JSON array of contract deadline alerts and post them to Slack via MCP.

File to read: $ALERTS_FILE

Each entry already has final, correct values computed deterministically — do
not recompute, second-guess, or alter deadline_date, days_until_deadline, or
urgency_tier. Never invent a contract, counterparty, or date that is not in
this file (Legal Accuracy Rule 1 — no fabrication).

Each entry has:
- contract_name, counterparty, contract_type
- deadline_type: "renewal" or "expiry"
- deadline_date (ISO 8601), days_until_deadline (integer)
- urgency_tier: URGENT (<30 days), ACTION_NEEDED (30-60 days), or WATCH (60-90 days)
- auto_renewal (boolean)
- notice_period_days (integer or null), notice_period_raw (original extracted string or null)

Task:
1. Read the JSON file.
2. Group entries by urgency_tier.
3. For each entry, draft a recommended_action, one of: renew, renegotiate,
   terminate, let-expire. You only have the fields above — no visibility into
   deal quality, budget, or relationship health — so default to the most
   conservative, reversible suggestion:
   - auto_renewal is true and tier is URGENT or ACTION_NEEDED -> "renegotiate"
     (there's still a window to act before it locks in)
   - auto_renewal is true and tier is WATCH -> "renew" (monitor, no action needed yet)
   - auto_renewal is false or null and deadline_type is "expiry" -> "let-expire"
     unless a renewal path is evident elsewhere in the same contract's other
     alert entry, in which case "renegotiate"
   - otherwise -> "renegotiate"
   Do not recommend "terminate" from this data alone — nothing here indicates
   an active decision to end the relationship. Label every recommendation as
   a suggestion for lawyer review, never as a decision (consistent with this
   project's rule that fallback/negotiation suggestions are surfaced only,
   never auto-acted-on).
4. Post exactly one Slack message per non-empty tier, in this order: URGENT,
   ACTION_NEEDED, WATCH. Skip a tier's message entirely if it has zero entries.
   - URGENT tier: red color/emoji (e.g. 🔴), header like "🔴 URGENT — Contract Deadlines (<30 days)"
   - ACTION_NEEDED tier: orange (e.g. 🟠), header like "🟠 ACTION NEEDED — Contract Deadlines (30-60 days)"
   - WATCH tier: yellow (e.g. 🟡), header like "🟡 WATCH — Contract Deadlines (60-90 days)"
   - Within each message, list every entry in that tier with: contract_name,
     counterparty, deadline_date, deadline_type, auto_renewal status,
     notice_period_days, and recommended_action (clearly marked "Suggested —
     requires lawyer review").
5. Use mcp__claude_ai_Slack__slack_send_message to post each tier's message to: $CHANNEL

Go ahead and post the messages to Slack now.
PROMPT_EOF
)

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "--- DRY RUN: not calling claude/Slack. Prompt that would be sent: ---"
  echo "$PROMPT"
  exit 0
fi

OUTPUT=$(claude -p "$PROMPT" --allowedTools "Read,mcp__claude_ai_Slack__slack_send_message,mcp__claude_ai_Slack__slack_search_channels,mcp__claude_ai_Slack__slack_list_user_channels" 2>&1 || true)
echo "$OUTPUT"

if echo "$OUTPUT" | grep -qi "posted\|sent\|success"; then
  echo "Alerts posted to Slack ($CANDIDATE_COUNT deadline(s) across up to 3 tier messages)." >&2
  exit 0
elif echo "$OUTPUT" | grep -qi "error\|failed"; then
  echo "Error: Claude/Slack MCP reported a failure — see output above" >&2
  exit 1
else
  echo "Warning: unclear result from claude -p — check output above" >&2
  exit 1
fi

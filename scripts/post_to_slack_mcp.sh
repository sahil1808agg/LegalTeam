#!/usr/bin/env bash
# post_to_slack_mcp.sh — Post contract review or renewal summary to Slack via Claude MCP
#
# This script uses Claude Code with Slack MCP to send rich formatted messages.
# It's designed to run locally or in environments with Claude Code + MCP access.
#
# Usage:
#   scripts/post_to_slack_mcp.sh --type contract --file extraction/output/contract_extracted.json
#   scripts/post_to_slack_mcp.sh --type renewals --file renewals_digest.json
#
# Environment:
#   CLAUDE_MCP_ENABLED=true (required)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- args ---------------------------------------------------------------
MESSAGE_TYPE=""
INPUT_FILE=""
CHANNEL="#legal-contracts"
VERBOSE=0

usage() {
  cat >&2 <<'EOF'
Usage: post_to_slack_mcp.sh --type TYPE --file FILE [--channel CHANNEL] [--verbose]

  --type       Message type: contract | renewals (required)
  --file       Input JSON file with message data (required)
  --channel    Slack channel (default: #legal-contracts)
  --verbose    Show detailed output
  -h|--help    Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type) MESSAGE_TYPE="${2:-}"; shift 2 ;;
    --file) INPUT_FILE="${2:-}"; shift 2 ;;
    --channel) CHANNEL="${2:-}"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

# --- validation -------------------------------------------------------
command -v claude >/dev/null || { echo "Error: claude CLI not found"; exit 1; }
command -v jq >/dev/null || { echo "Error: jq not found"; exit 1; }

[[ -n "$MESSAGE_TYPE" ]] || { echo "Error: --type is required" >&2; usage; exit 1; }
[[ -n "$INPUT_FILE" ]] || { echo "Error: --file is required" >&2; usage; exit 1; }
[[ -f "$INPUT_FILE" ]] || { echo "Error: file not found: $INPUT_FILE" >&2; exit 1; }

# --- build prompt -------------------------------------------------------

build_contract_message_prompt() {
  local json_file="$1"
  local channel="$2"

  cat <<'PROMPT_EOF'
You will read a JSON file with contract review data and post it to Slack via MCP.

The file contains:
- filename: contract name
- type: contract type (MSA/NDA/SOW/DPA)
- completeness: extraction completeness (e.g., "18/22")
- completeness_pct: percentage (e.g., 82)
- flagged: number of flagged fields
- deviations: deviation summary (e.g., "HIGH: 11, MED: 2, LOW: 2")
- risk_assessment: Claude analysis (risk_rating, key_risks, etc.)

Task:
1. Read the JSON file
2. Format as a Slack message with:
   - Contract title with filename and type
   - Completeness bar (emoji-based)
   - AI risk rating as emoji/text
   - Key risks as bullet points
   - Recommended actions
   - Link to GitHub issue
3. Use mcp__claude_ai_Slack__slack_send_message to post to CHANNEL

Format the message to be visually clear and highlight risks.
Use emoji for quick scanning (⚠️ HIGH, 🟡 MEDIUM, ✅ LOW).

Channel: CHANNEL

Go ahead and post the message to Slack now.
PROMPT_EOF
}

build_renewals_message_prompt() {
  local json_file="$1"
  local channel="$2"

  cat <<'PROMPT_EOF'
You will read a JSON array of renewal deadlines and post a digest to Slack via MCP.

The file contains an array where each object has:
- counterparty: company name
- contract_type: MSA/NDA/SOW/DPA
- renewal_notice_deadline: ISO date
- days_until_deadline: integer
- risk_level: CRITICAL/URGENT/WARNING
- auto_renewal: boolean
- action: REVIEW_REQUIRED or TRACK

Task:
1. Read the JSON file
2. Format as a Slack message with:
   - Summary of total contracts and urgent count
   - CRITICAL items (due ≤14 days) with emoji ⏰
   - URGENT items (15-30 days) with emoji ⚠️
   - Auto-renewal warnings with emoji 🔄
   - Summary paragraph
3. Use mcp__claude_ai_Slack__slack_send_message to post to CHANNEL

Make the message scannable - use sections, emojis, and clear formatting.
Highlight CRITICAL items prominently (red emoji).

Channel: CHANNEL

Go ahead and post the message to Slack now.
PROMPT_EOF
}

# --- prepare prompt -------------------------------------------------------

if [ "$MESSAGE_TYPE" = "contract" ]; then
  PROMPT=$(build_contract_message_prompt "$INPUT_FILE" "$CHANNEL" | \
    sed "s|CHANNEL|$CHANNEL|g" | \
    cat - <(echo "

File to read: $INPUT_FILE"))
elif [ "$MESSAGE_TYPE" = "renewals" ]; then
  PROMPT=$(build_renewals_message_prompt "$INPUT_FILE" "$CHANNEL" | \
    sed "s|CHANNEL|$CHANNEL|g" | \
    cat - <(echo "

File to read: $INPUT_FILE"))
else
  echo "Error: unknown message type: $MESSAGE_TYPE" >&2
  exit 1
fi

# --- invoke claude with mcp -------------------------------------------------------

if [ "$VERBOSE" -eq 1 ]; then
  echo "📤 Posting $MESSAGE_TYPE message to $CHANNEL via Slack MCP..."
  echo "Input file: $INPUT_FILE"
  echo ""
fi

# Call Claude with MCP access to Slack
OUTPUT=$(claude -p "$PROMPT" --allowedTools "Read,mcp__claude_ai_Slack__slack_send_message" 2>&1 || true)

if [ "$VERBOSE" -eq 1 ]; then
  echo "Response:"
  echo "$OUTPUT"
  echo ""
fi

# Check for success
if echo "$OUTPUT" | grep -qi "posted\|sent\|success"; then
  echo "✅ Message posted to Slack successfully"
  exit 0
elif echo "$OUTPUT" | grep -qi "error\|failed"; then
  echo "❌ Failed to post message:"
  echo "$OUTPUT" >&2
  exit 1
else
  echo "⚠️ Unclear result - check logs above"
  echo "$OUTPUT"
  exit 1
fi

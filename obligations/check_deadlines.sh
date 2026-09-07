#!/usr/bin/env bash
# check_deadlines.sh — UC6: scan all extracted contracts and flag renewal
# notice deadlines within the next N days (default 90).
#
# Reads all extraction/output/*.json files, calculates renewal notice
# deadlines based on effective_date + term_length + renewal_notice_period,
# and outputs a JSON array of contracts with deadlines in the target window.
#
# Usage: obligations/check_deadlines.sh [--days N] [--output FORMAT]
# Outputs JSON array to stdout; each object includes counterparty, dates,
# days_until_deadline, and a risk_level (URGENT/CRITICAL/WARNING) based on
# proximity to the deadline.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTRACTION_DIR="$REPO_ROOT/extraction/output"
DAYS_UNTIL_DEADLINE=90
OUTPUT_FORMAT="json"  # could be json, markdown, slack

usage() {
  cat >&2 <<'EOF'
Usage: check_deadlines.sh [--days N] [--output FORMAT]

  --days       Number of days to look ahead (default: 90)
  --output     Output format: json, markdown, slack (default: json)
  -h|--help    Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) DAYS_UNTIL_DEADLINE="${2:-90}"; shift 2 ;;
    --output) OUTPUT_FORMAT="${2:-json}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

command -v jq >/dev/null || { echo "Error: jq not found — install jq" >&2; exit 1; }

# Calculate dates
TODAY=$(date -u +%Y-%m-%d)
TODAY_EPOCH=$(date -u -d "$TODAY" +%s)
DEADLINE_DATE=$(date -u -d "$TODAY + $DAYS_UNTIL_DEADLINE days" +%Y-%m-%d)
DEADLINE_EPOCH=$(date -u -d "$DEADLINE_DATE" +%s)

# Helper function to parse date string (handles ISO 8601 and common formats)
parse_date() {
  local date_str="$1"
  # Remove any quotes, whitespace
  date_str=$(echo "$date_str" | tr -d '"' | xargs)

  # If empty or null, return empty
  [[ -z "$date_str" || "$date_str" == "null" ]] && return 1

  # Try ISO 8601 format first
  if [[ $date_str =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "$date_str"
    return 0
  fi

  # Try to parse with date command (handles various formats)
  date -u -d "$date_str" +%Y-%m-%d 2>/dev/null || return 1
}

# Helper function to parse duration (e.g., "10 years", "6 months", "30 days")
parse_duration() {
  local duration_str="$1"
  duration_str=$(echo "$duration_str" | tr -d '"' | xargs | tr '[:upper:]' '[:lower:]')

  [[ -z "$duration_str" || "$duration_str" == "null" ]] && return 1

  # Extract number and unit
  if [[ $duration_str =~ ^([0-9]+)\.?[0-9]* +([a-z]+) ]]; then
    local num="${BASH_REMATCH[1]}"
    local unit="${BASH_REMATCH[2]}"

    case "$unit" in
      year|years) echo "+$num years" ;;
      month|months) echo "+$num months" ;;
      day|days) echo "+$num days" ;;
      week|weeks) echo "+$((num * 7)) days" ;;
      *) echo "" ;;
    esac
  fi
}

# Helper to calculate days until date
days_until() {
  local target_date="$1"
  local target_epoch=$(date -u -d "$target_date" +%s 2>/dev/null || return 1)
  echo $(( (target_epoch - TODAY_EPOCH) / 86400 ))
}

# Calculate risk level based on days remaining
risk_level() {
  local days_remaining=$1
  if [ "$days_remaining" -le 14 ]; then
    echo "CRITICAL"
  elif [ "$days_remaining" -le 30 ]; then
    echo "URGENT"
  else
    echo "WARNING"
  fi
}

# Process all extraction files
declare -a contracts_due

if [ ! -d "$EXTRACTION_DIR" ]; then
  echo "[]"
  exit 0
fi

# Count processing
processed=0
found=0

for extraction_file in "$EXTRACTION_DIR"/*.json; do
  [ -f "$extraction_file" ] || continue

  ((processed++))

  # Extract contract data
  contract_type=$(jq -r '.contract_type.value // "UNKNOWN"' "$extraction_file" 2>/dev/null || echo "UNKNOWN")
  counterparty=$(jq -r '.counterparty_name.value // "UNKNOWN"' "$extraction_file" 2>/dev/null || echo "UNKNOWN")
  effective_date=$(jq -r '.effective_date.value // null' "$extraction_file" 2>/dev/null)
  execution_date=$(jq -r '.execution_date.value // null' "$extraction_file" 2>/dev/null)
  term_length=$(jq -r '.term_length.value // null' "$extraction_file" 2>/dev/null)
  renewal_notice_deadline=$(jq -r '.renewal_notice_deadline.value // null' "$extraction_file" 2>/dev/null)
  renewal_notice_period=$(jq -r '.termination_notice_period.value // null' "$extraction_file" 2>/dev/null)
  auto_renewal=$(jq -r '.auto_renewal_flag.value // false' "$extraction_file" 2>/dev/null)

  # Determine the most relevant start date
  start_date=""
  if [ -n "$effective_date" ] && [ "$effective_date" != "null" ]; then
    start_date="$effective_date"
  elif [ -n "$execution_date" ] && [ "$execution_date" != "null" ]; then
    start_date="$execution_date"
  fi

  # Calculate renewal notice deadline if not explicitly stated
  calculated_deadline=""
  if [ -n "$start_date" ] && [ "$start_date" != "null" ]; then
    # If term_length exists, calculate when term ends, then subtract notice period
    if [ -n "$term_length" ] && [ "$term_length" != "null" ]; then
      term_offset=$(parse_duration "$term_length" || echo "")
      if [ -n "$term_offset" ]; then
        term_end=$(date -u -d "$start_date $term_offset" +%Y-%m-%d 2>/dev/null || echo "")

        if [ -n "$term_end" ]; then
          # Subtract notice period from term end to get deadline
          if [ -n "$renewal_notice_period" ] && [ "$renewal_notice_period" != "null" ]; then
            notice_offset=$(parse_duration "$renewal_notice_period" || echo "")
            if [ -n "$notice_offset" ]; then
              # Convert notice_offset to negative for subtraction
              notice_offset="${notice_offset/+/-}"
              calculated_deadline=$(date -u -d "$term_end $notice_offset" +%Y-%m-%d 2>/dev/null || echo "")
            fi
          else
            # Default to 30 days before term end if no explicit notice period
            calculated_deadline=$(date -u -d "$term_end -30 days" +%Y-%m-%d 2>/dev/null || echo "")
          fi
        fi
      fi
    fi
  fi

  # Use explicit deadline if present, otherwise calculated
  target_deadline="$renewal_notice_deadline"
  if [ -z "$target_deadline" ] || [ "$target_deadline" = "null" ]; then
    target_deadline="$calculated_deadline"
  fi

  # Check if deadline is within the window
  if [ -n "$target_deadline" ] && [ "$target_deadline" != "null" ]; then
    days_remain=$(days_until "$target_deadline" || echo "999")

    if [ "$days_remain" -ge 0 ] && [ "$days_remain" -le "$DAYS_UNTIL_DEADLINE" ]; then
      risk=$(risk_level "$days_remain")

      contract_data=$(jq -n \
        --arg counterparty "$counterparty" \
        --arg type "$contract_type" \
        --arg file "$(basename "$extraction_file")" \
        --arg effective_date "$start_date" \
        --arg term_length "$term_length" \
        --arg deadline "$target_deadline" \
        --arg days_until "$days_remain" \
        --arg risk "$risk" \
        --arg auto_renewal "$auto_renewal" \
        '{
          counterparty: $counterparty,
          contract_type: $type,
          extraction_file: $file,
          effective_date: $effective_date,
          term_length: $term_length,
          renewal_notice_deadline: $deadline,
          days_until_deadline: ($days_until | tonumber),
          risk_level: $risk,
          auto_renewal: ($auto_renewal == "true" or $auto_renewal == "yes" or $auto_renewal == true),
          action: (if ($risk == "CRITICAL" or $risk == "URGENT") then "REVIEW_REQUIRED" else "TRACK" end)
        }')

      contracts_due+=("$contract_data")
      ((found++))
    fi
  fi
done

# Sort by days_until_deadline (ascending - most urgent first)
if [ ${#contracts_due[@]} -gt 0 ]; then
  case "$OUTPUT_FORMAT" in
    json)
      printf '%s\n' "${contracts_due[@]}" | jq -s 'sort_by(.days_until_deadline)'
      ;;
    markdown)
      echo "# Renewal Deadlines (Next $DAYS_UNTIL_DEADLINE Days)"
      echo ""
      echo "| Counterparty | Type | Deadline | Days Left | Risk | Auto-Renew? |"
      echo "|---|---|---|---|---|---|"
      printf '%s\n' "${contracts_due[@]}" | jq -r '.[] | "| \(.counterparty) | \(.contract_type) | \(.renewal_notice_deadline) | \(.days_until_deadline) | \(.risk_level) | \(.auto_renewal) |"' | sort -t'|' -k3
      echo ""
      echo "---"
      echo "_Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ) | Scanned: $processed contracts_"
      ;;
    slack)
      printf '%s\n' "${contracts_due[@]}" | jq -s '.'
      ;;
  esac
else
  echo "[]"
fi

exit 0

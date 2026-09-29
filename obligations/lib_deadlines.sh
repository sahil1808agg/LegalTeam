#!/usr/bin/env bash
# lib_deadlines.sh — shared deterministic date-math helpers for the UC6
# obligation scripts (check_deadlines.sh, morning_digest.sh).
#
# Legal Accuracy Rules 1/2 (CLAUDE.md): every function here is pure date
# arithmetic on values already present in an extraction — never a guess, and
# never delegated to an LLM. Both scripts source this file so a fix or
# behavior change to expiry-date math can't silently drift between them.
#
# Source this file (`source lib_deadlines.sh`); it is not meant to be
# executed directly.

TODAY="$(date -u +%Y-%m-%d)"
TODAY_EPOCH="$(date -u -d "$TODAY" +%s)"

# Parses "N years|months|weeks|days" into a normalized "+N days|months|years"
# offset date(1) understands. Returns nothing (never a guessed value) when
# the string can't be parsed.
parse_duration() {
  local duration_str
  # Trim via parameter expansion, not `xargs` — xargs treats an apostrophe
  # in the source text (e.g. "ninety (90) days' notice") as an unmatched
  # quote and errors instead of just trimming whitespace.
  duration_str=$(echo "$1" | tr -d '"')
  duration_str="${duration_str#"${duration_str%%[![:space:]]*}"}"
  duration_str="${duration_str%"${duration_str##*[![:space:]]}"}"
  duration_str=$(echo "$duration_str" | tr '[:upper:]' '[:lower:]')
  [[ -z "$duration_str" || "$duration_str" == "null" ]] && return 1

  if [[ $duration_str =~ ^([0-9]+)\.?[0-9]*[[:space:]]+([a-z]+) ]]; then
    local num="${BASH_REMATCH[1]}" unit="${BASH_REMATCH[2]}"
    case "$unit" in
      year|years) echo "+$num years" ;;
      month|months) echo "+$num months" ;;
      day|days) echo "+$num days" ;;
      week|weeks) echo "+$((num * 7)) days" ;;
      *) return 1 ;;
    esac
  else
    return 1
  fi
}

# Approximate day count for display only (e.g. notice_period_days). Actual
# deadline dates always come from date(1) arithmetic on the real calendar,
# never from this approximation — years=365d/months=30d is a display
# convenience, not a computation used for any deadline math.
duration_to_days() {
  local normalized
  normalized=$(parse_duration "$1") || return 1
  if [[ $normalized =~ ^\+([0-9]+)[[:space:]]+([a-z]+)$ ]]; then
    local n="${BASH_REMATCH[1]}" unit="${BASH_REMATCH[2]}"
    case "$unit" in
      days) echo "$n" ;;
      months) echo $((n * 30)) ;;
      years) echo $((n * 365)) ;;
    esac
  else
    return 1
  fi
}

days_until() {
  local target_epoch
  target_epoch=$(date -u -d "$1" +%s 2>/dev/null) || return 1
  echo $(( (target_epoch - TODAY_EPOCH) / 86400 ))
}

# expiry_date = start_date (effective_date, else execution_date) + term_length.
# Args: effective_date execution_date term_length — each either an ISO 8601
# date / duration string, or the literal "null" sentinel for an absent field.
# Echoes the computed YYYY-MM-DD, or "null" if it can't be determined.
compute_expiry_date() {
  local effective_date="$1" execution_date="$2" term_length="$3"
  local start_date="null"
  [[ "$effective_date" != "null" ]] && start_date="$effective_date"
  [[ "$start_date" == "null" && "$execution_date" != "null" ]] && start_date="$execution_date"

  if [[ "$start_date" == "null" || "$term_length" == "null" ]]; then
    echo "null"
    return
  fi

  local term_offset
  term_offset=$(parse_duration "$term_length" || echo "")
  if [[ -z "$term_offset" ]]; then
    echo "null"
    return
  fi

  date -u -d "$start_date $term_offset" +%Y-%m-%d 2>/dev/null || echo "null"
}

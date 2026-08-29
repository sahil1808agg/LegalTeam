#!/usr/bin/env bash
# post_redline.sh — PostToolUse hook: appends an audit metadata header to
# every redline report produced by redlining/redline.sh (UC2/UC3).
#
# redline.sh writes its report via shell redirection inside the script
# itself, not through Claude's Write tool, so this hook is registered
# against the Bash tool and filters internally: it only acts when the
# executed command referenced redline.sh AND that command's own stdout
# contains its "Written to <path>" success line (see redline.sh). Any
# other Bash call — or a redline.sh run that failed validation before
# writing a file — is a silent no-op. A redline.sh invocation whose stdout
# doesn't match the expected shape is NOT a silent no-op: it exits 2 with a
# diagnostic, since that indicates the hook's assumptions about the
# tool_response payload have broken (never silently swallow a parsing
# failure — see CLAUDE.md Coding Conventions).

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMING_DIR="$HOOK_DIR/.redline_timing"

INPUT="$(cat)"

# Parsed via node (jq is not available in this environment). Fields are
# base64-encoded individually so embedded newlines/quotes in the command
# or captured stdout can never corrupt the delimiter-based split on the
# bash side.
PARSED="$(node -e '
let input = "";
process.stdin.on("data", d => input += d);
process.stdin.on("end", () => {
  let j;
  try { j = JSON.parse(input); } catch { j = {}; }
  const toolName = j.tool_name || "";
  const command = (j.tool_input && j.tool_input.command) || "";
  const toolUseId = j.tool_use_id || "";
  const transcriptPath = j.transcript_path || "";
  const resp = j.tool_response;
  let responseText = "";
  if (typeof resp === "string") responseText = resp;
  else if (resp && typeof resp === "object") {
    responseText = resp.stdout || resp.output || resp.text || JSON.stringify(resp);
  }
  const fields = [toolName, command, toolUseId, transcriptPath, responseText];
  process.stdout.write(fields.map(f => Buffer.from(String(f), "utf8").toString("base64")).join("\n"));
});
' <<<"$INPUT")"

mapfile -t B64 <<<"$PARSED"
TOOL_NAME="$(base64 -d <<<"${B64[0]}")"
COMMAND="$(base64 -d <<<"${B64[1]}")"
TOOL_USE_ID="$(base64 -d <<<"${B64[2]}")"
TRANSCRIPT_PATH="$(base64 -d <<<"${B64[3]}")"
STDOUT="$(base64 -d <<<"${B64[4]}")"

[[ "$TOOL_NAME" == "Bash" ]] || exit 0
# Path/word-boundary before "redline.sh" — a plain substring match would
# also fire on this hook's own filenames (pre_redline.sh, post_redline.sh)
# whenever a command merely mentions them, e.g. `bash -n .../post_redline.sh`.
[[ "$COMMAND" =~ ([[:space:]/]|^)redline\.sh([[:space:]]|$) ]] || exit 0
[[ "$COMMAND" == *--playbook* ]] || exit 0

OUT_FILE="$(grep -m1 -oE '^Written to .+' <<<"$STDOUT" | sed -E 's/^Written to //')"

if [[ -z "$OUT_FILE" ]]; then
  if grep -qE '^Error:' <<<"$STDOUT"; then
    exit 0 # redline.sh failed validation/generation — nothing was written, nothing to annotate
  fi
  echo "post_redline.sh: redline.sh ran but no 'Written to <path>' line was found in its captured output — skipping metadata append. Either the run failed before writing a file, or this hook's assumptions about the tool_response payload shape no longer hold." >&2
  exit 2
fi

if [[ ! -f "$OUT_FILE" ]]; then
  echo "post_redline.sh: parsed output path '$OUT_FILE' from redline.sh's stdout but that file doesn't exist — skipping metadata append." >&2
  exit 2
fi

PLAYBOOK="$(grep -m1 -oE '^Comparing .+ against .+ \([0-9]+ clauses\)' <<<"$STDOUT" | sed -E 's/^Comparing .+ against (.+) \([0-9]+ clauses\)$/\1/')"

# --- processing duration ----------------------------------------------
# duration_ms is not part of the documented PostToolUse payload; the
# companion pre_redline.sh (PreToolUse) stashed a start time keyed by
# tool_use_id, so elapsed time is computed rather than guessed.
DURATION="unknown"
START_FILE="$TIMING_DIR/$TOOL_USE_ID.start"
if [[ -n "$TOOL_USE_ID" && -f "$START_FILE" ]]; then
  START_EPOCH="$(cat "$START_FILE")"
  END_EPOCH="$(date +%s)"
  DURATION="$(( END_EPOCH - START_EPOCH ))s"
  rm -f "$START_FILE"
fi

# --- model ---------------------------------------------------------------
# Not exposed to PostToolUse hooks; best-effort recovery from the most
# recent "model" field in the session transcript. Falls back to "unknown"
# rather than fabricating a value (CLAUDE.md: never fabricate).
MODEL="unknown"
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  FOUND_MODEL="$(grep -oE '"model":"[^"]+"' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 | sed -E 's/"model":"([^"]+)"/\1/' || true)"
  [[ -n "$FOUND_MODEL" ]] && MODEL="$FOUND_MODEL"
fi

# --- playbook version ------------------------------------------------------
# No version field exists in the playbook files today; per project
# decision, the playbook file's last-modified timestamp is used as a
# pseudo-version rather than inventing a semantic version number.
PLAYBOOK_VERSION="unknown"
if [[ -n "$PLAYBOOK" && -f "$PLAYBOOK" ]]; then
  PLAYBOOK_VERSION="last modified $(date -r "$PLAYBOOK" '+%Y-%m-%dT%H:%M:%S%z')"
fi

# --- deviation counts --------------------------------------------------
# Counts Risk Level cells only inside actual table data rows (mirrors the
# row-isolation logic redline.sh itself uses for CLAUSE_COUNT/ROW_COUNT) so
# prose in the Summary section (e.g. "the HIGH risk deviations") never
# inflates the count.
TABLE_ROWS="$(grep -E '^\|' "$OUT_FILE" | grep -vE '^\| *# *\|' | grep -vE '^\|[-| ]+\|$' || true)"
HIGH_COUNT="$(grep -cE '\| *HIGH:' <<<"$TABLE_ROWS" || true)"
MED_COUNT="$(grep -cE '\| *MED:' <<<"$TABLE_ROWS" || true)"
LOW_COUNT="$(grep -cE '\| *LOW:' <<<"$TABLE_ROWS" || true)"

# --- append metadata header ------------------------------------------------
{
  echo ""
  echo "---"
  echo ""
  echo "## Report Metadata"
  echo ""
  echo "- **Generated:** $(date '+%Y-%m-%dT%H:%M:%S%z')"
  echo "- **Model:** $MODEL"
  echo "- **Playbook:** ${PLAYBOOK:-unknown} ($PLAYBOOK_VERSION)"
  echo "- **Deviation counts:** HIGH: $HIGH_COUNT, MED: $MED_COUNT, LOW: $LOW_COUNT"
  echo "- **Processing duration:** $DURATION"
} >> "$OUT_FILE"

exit 0

#!/usr/bin/env bash
# pre_redline.sh — PreToolUse hook: stashes a start timestamp for any Bash
# call that invokes redlining/redline.sh, keyed by tool_use_id.
#
# PostToolUse hook payloads don't expose call duration (verified against
# Claude Code's hooks reference — no duration_ms field is documented for
# PostToolUse), so post_redline.sh reads the timestamp this hook writes to
# compute a real elapsed processing time instead of guessing or omitting it.

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMING_DIR="$HOOK_DIR/.redline_timing"

INPUT="$(cat)"

# Parsed via node (jq is not available in this environment). Fields are
# base64-encoded individually so embedded newlines/quotes in the command
# text can never corrupt the delimiter-based split on the bash side.
PARSED="$(node -e '
let input = "";
process.stdin.on("data", d => input += d);
process.stdin.on("end", () => {
  let j;
  try { j = JSON.parse(input); } catch { j = {}; }
  const toolName = j.tool_name || "";
  const command = (j.tool_input && j.tool_input.command) || "";
  const toolUseId = j.tool_use_id || "";
  const fields = [toolName, command, toolUseId];
  process.stdout.write(fields.map(f => Buffer.from(String(f), "utf8").toString("base64")).join("\n"));
});
' <<<"$INPUT")"

mapfile -t B64 <<<"$PARSED"
TOOL_NAME="$(base64 -d <<<"${B64[0]}")"
COMMAND="$(base64 -d <<<"${B64[1]}")"
TOOL_USE_ID="$(base64 -d <<<"${B64[2]}")"

[[ "$TOOL_NAME" == "Bash" ]] || exit 0
# Path/word-boundary before "redline.sh" — a plain substring match would
# also fire on this hook's own filenames (pre_redline.sh, post_redline.sh)
# whenever a command merely mentions them, e.g. `bash -n .../pre_redline.sh`.
[[ "$COMMAND" =~ ([[:space:]/]|^)redline\.sh([[:space:]]|$) ]] || exit 0
[[ "$COMMAND" == *--playbook* ]] || exit 0
[[ -n "$TOOL_USE_ID" ]] || exit 0

mkdir -p "$TIMING_DIR"
date +%s > "$TIMING_DIR/$TOOL_USE_ID.start"

exit 0

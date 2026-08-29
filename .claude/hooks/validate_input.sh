#!/usr/bin/env bash
# validate_input.sh — PreToolUse hook: sanity-checks the incoming contract
# passed to redlining/redline.sh (UC2/UC3) before the redline comparison
# runs, since a near-empty or truncated file (e.g. a failed PDF text
# extraction) would otherwise get silently redlined as if it were the real
# contract.
#
# Word count is a heuristic for "long enough to plausibly be a real
# contract, not a stub/placeholder/failed extraction" — it is advisory
# only (per project decision): a genuinely short contract (e.g. a brief
# NDA) is never blocked, it just gets a visible warning surfaced to Claude
# via systemMessage. PreToolUse hooks cannot force an interactive
# confirmation prompt (verified against Claude Code's hooks reference —
# exit 2 is a hard, unappealable block, especially inside redline.sh's own
# non-interactive `claude -p` subprocess where no user is present to
# confirm anything), so hard-blocking was rejected in favor of a visible,
# non-blocking warning that Claude can relay to the user.

set -euo pipefail

INPUT="$(cat)"

# Parsed via node (jq is not available in this environment). Fields are
# base64-encoded individually so embedded quotes/newlines in the command
# can never corrupt the delimiter-based split on the bash side.
PARSED="$(node -e '
let input = "";
process.stdin.on("data", d => input += d);
process.stdin.on("end", () => {
  let j;
  try { j = JSON.parse(input); } catch { j = {}; }
  const toolName = j.tool_name || "";
  const command = (j.tool_input && j.tool_input.command) || "";
  const cwd = j.cwd || "";
  const fields = [toolName, command, cwd];
  process.stdout.write(fields.map(f => Buffer.from(String(f), "utf8").toString("base64")).join("\n"));
});
' <<<"$INPUT")"

mapfile -t B64 <<<"$PARSED"
TOOL_NAME="$(base64 -d <<<"${B64[0]}")"
COMMAND="$(base64 -d <<<"${B64[1]}")"
CWD="$(base64 -d <<<"${B64[2]}")"

[[ "$TOOL_NAME" == "Bash" ]] || exit 0
# Same invocation signature pre_redline.sh/post_redline.sh use: a
# path/word boundary before "redline.sh" plus the --playbook flag, so this
# never fires on unrelated commands that merely mention the filename.
[[ "$COMMAND" =~ ([[:space:]/]|^)redline\.sh([[:space:]]|$) ]] || exit 0
[[ "$COMMAND" == *--playbook* ]] || exit 0

# Extract the --incoming argument with a small quote-aware tokenizer
# (respects '...' and "..." so paths containing spaces, e.g. Windows
# Downloads paths, are handled correctly) rather than a naive word split.
INCOMING="$(node -e '
const command = process.argv[1];
function tokenize(cmd) {
  const tokens = [];
  let cur = "", quote = null;
  for (const c of cmd) {
    if (quote) { if (c === quote) quote = null; else cur += c; }
    else if (c === "\"" || c === "\x27") quote = c;
    else if (/\s/.test(c)) { if (cur) { tokens.push(cur); cur = ""; } }
    else cur += c;
  }
  if (cur) tokens.push(cur);
  return tokens;
}
const tokens = tokenize(command);
const idx = tokens.indexOf("--incoming");
process.stdout.write(idx >= 0 && tokens[idx + 1] ? tokens[idx + 1] : "");
' "$COMMAND")"

[[ -n "$INCOMING" ]] || exit 0

# Resolve relative to the hook's reported cwd, matching how redline.sh
# itself resolves the --incoming path.
if [[ "$INCOMING" != /* && "$INCOMING" != [A-Za-z]:* ]]; then
  INCOMING="$CWD/$INCOMING"
fi

[[ -f "$INCOMING" ]] || exit 0 # missing file — redline.sh's own validation reports this clearly

WORD_COUNT="$(wc -w < "$INCOMING" | tr -d ' ')"

if (( WORD_COUNT < 500 )); then
  REASON="Incoming contract '$INCOMING' is only $WORD_COUNT words (< 500) — this may be a stub, placeholder, or a failed/partial text extraction rather than a full contract. Proceeding with the redline comparison anyway (advisory only, per project decision), but flag this to the user before treating the report as complete."
  node -e '
const reason = process.argv[1];
process.stdout.write(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    systemMessage: "WARNING: " + reason
  }
}));
' "$REASON"
fi

exit 0

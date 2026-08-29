#!/usr/bin/env bash
# freshness_check.sh — PreToolUse hook: blocks reading a redlining playbook
# (redlining/playbooks/*.md) if its last-modified date is more than 90 days
# old, since a stale-but-unnoticed playbook could quietly drive redline
# comparisons (UC2/UC3) against firm standard positions that no longer
# reflect current legal guidance.
#
# Scoped via "if": "Read(redlining/playbooks/*.md)" on this hook's entry in
# settings.json, so this script only ever runs for genuine playbook reads —
# no in-script path matching needed.
#
# A PreToolUse hook cannot pop a real interactive y/n prompt (verified
# against Claude Code's hooks reference: exit 2 is a hard, unappealable
# block — there is no live channel to collect a keypress and thread it back
# into the tool-call decision). So "Continue? (y/n)" is realized as: block
# by default (exit 2) with the requested alert text, plus a single-use
# bypass marker file that Claude creates only after a human has actually
# confirmed "yes, continue" in chat — never created automatically.

set -euo pipefail

STALE_DAYS_THRESHOLD=90
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERRIDE_DIR="$HOOK_DIR/.freshness_override"

INPUT="$(cat)"

FILE_PATH="$(node -e '
let input = "";
process.stdin.on("data", d => input += d);
process.stdin.on("end", () => {
  let j;
  try { j = JSON.parse(input); } catch { j = {}; }
  const filePath = (j.tool_input && j.tool_input.file_path) || "";
  process.stdout.write(filePath);
});
' <<<"$INPUT")"

[[ -n "$FILE_PATH" && -f "$FILE_PATH" ]] || exit 0 # nothing to check — let the Read tool's own error handle a missing file

# settings.json's "if": "Read(redlining/playbooks/*.md)" glob does not match
# real absolute Windows paths (backslashes, drive letters, spaces in the
# directory name), so this hook is registered as a broad Read matcher and
# the playbook-path scoping is done here instead, in-script — same
# defensive pattern already used by pre_redline.sh/validate_input.sh for
# their own command-string matching.
NORMALIZED="${FILE_PATH//\\//}"
[[ "$NORMALIZED" == *"/redlining/playbooks/"*.md ]] || exit 0

# mtime/age computed via node (fs.statSync) rather than shelling out to
# `date -r`, since coreutils flags for file-mtime and Windows-style
# absolute paths behave inconsistently across environments.
RESULT="$(node -e '
const fs = require("fs");
const path = process.argv[1];
const thresholdDays = Number(process.argv[2]);
const stat = fs.statSync(path);
const ageMs = Date.now() - stat.mtime.getTime();
const ageDays = Math.floor(ageMs / (1000 * 60 * 60 * 24));
const isoDate = stat.mtime.toISOString().slice(0, 10);
process.stdout.write([ageDays > thresholdDays ? "STALE" : "FRESH", ageDays, isoDate].join("\t"));
' "$FILE_PATH" "$STALE_DAYS_THRESHOLD")"

IFS=$'\t' read -r STATUS AGE_DAYS LAST_UPDATED <<<"$RESULT"

[[ "$STATUS" == "STALE" ]] || exit 0

# Single-use bypass: a human has already confirmed "yes, continue" for
# this exact file after seeing a prior block (see the reason text below
# for the exact command that creates this marker). Consumed immediately
# so every fresh stale-playbook read requires a fresh confirmation rather
# than silently skipping the check forever.
OVERRIDE_KEY="$(node -e 'process.stdout.write(require("crypto").createHash("sha256").update(process.argv[1]).digest("hex"))' "$FILE_PATH")"
OVERRIDE_FILE="$OVERRIDE_DIR/$OVERRIDE_KEY"
if [[ -f "$OVERRIDE_FILE" ]]; then
  rm -f "$OVERRIDE_FILE"
  exit 0
fi

ALERT="PLAYBOOK MAY BE OUTDATED - last updated ${LAST_UPDATED} (${AGE_DAYS} days ago). Continue? (y/n)"
REASON="$ALERT This hook cannot collect an interactive answer directly — Claude must relay this alert to the user, and only on an explicit yes run: mkdir -p \"$OVERRIDE_DIR\" && touch \"$OVERRIDE_FILE\" — then retry the read. Never create that file without the user's explicit confirmation."

node -e '
const reason = process.argv[1];
process.stdout.write(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: reason
  }
}));
' "$REASON"

echo "$REASON" >&2
exit 2

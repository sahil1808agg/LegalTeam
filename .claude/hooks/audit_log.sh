#!/usr/bin/env bash
# audit_log.sh — PreToolUse hook (matcher: all tools): appends one JSONL
# record per tool call to obligations/audit/access_log.jsonl.
#
# CLAUDE.md's Coding Conventions require "any action that modifies a
# contract record ... logged with who/what/when — this is a compliance
# requirement, not optional logging." This hook generalizes that to every
# tool call (reads included), since the security audit of this repo
# (security_audit.md) found no standing record of *what Claude actually
# accessed* — only of what it was permitted to access. Permission grants and
# access logs answer different questions; this hook produces the latter.
#
# Unlike pre_redline.sh/validate_input.sh/freshness_check.sh, this hook is
# NOT scoped to a specific tool matcher — it fires on every PreToolUse event
# (Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, Agent, every
# mcp__* tool, etc.), so no in-script tool-name filtering is needed or
# applied.
#
# This hook never blocks a tool call and never emits a permissionDecision.
# If logging itself fails (directory can't be created, disk full, etc.),
# the failure is surfaced on stderr but the hook still exits 0 — a broken
# audit hook must not be able to halt every other tool in the session; a
# missed log line is a lesser failure than an outage of the entire pipeline.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HOOK_DIR/../.." && pwd)"
AUDIT_DIR="$REPO_ROOT/obligations/audit"
LOG_FILE="$AUDIT_DIR/access_log.jsonl"

INPUT="$(cat)"

# Millisecond-precision UTC timestamp where the platform's date(1) supports
# %3N (GNU coreutils); falls back to whole-second precision otherwise
# (never fails the hook over a formatting nicety).
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"

# No user identity is present in the hook's stdin payload (verified against
# the fields pre_redline.sh/post_redline.sh/validate_input.sh already parse
# out of it — tool_name, tool_input, tool_use_id, cwd, transcript_path,
# session_id, none of which is a human identity), so the OS account running
# the session is used instead: $USER (bash/git-bash), else $USERNAME
# (Windows), else `whoami`, else the literal "unknown" — never fabricated.
AUDIT_USER="${USER:-${USERNAME:-}}"
[[ -n "$AUDIT_USER" ]] || AUDIT_USER="$(whoami 2>/dev/null || echo unknown)"

# Parsed and classified via node (jq is not available in this environment —
# same constraint documented in the other hooks). All classification logic
# lives in this one node call so it emits the final JSONL record directly;
# bash only appends it to the log file.
LOG_LINE="$(node -e '
let input = "";
process.stdin.on("data", d => input += d);
process.stdin.on("end", () => {
  const timestamp = process.argv[1];
  const user = process.argv[2];

  let j;
  try { j = JSON.parse(input); } catch { j = {}; }

  const sessionId = j.session_id || "unknown";
  const toolName = j.tool_name || "unknown";
  const toolInput = (j.tool_input && typeof j.tool_input === "object") ? j.tool_input : {};

  const isMcp = toolName.startsWith("mcp__");

  // file_path or MCP endpoint: prefer an explicit file_path (Read/Write/
  // Edit/NotebookEdit), then the tool name itself for an MCP call (the
  // tool name *is* the endpoint, e.g. "mcp__claude_ai_Slack__slack_send_message"),
  // then whatever else identifies the target for tools with neither
  // (Bash command, Glob/Grep pattern, generic path input). Never guess —
  // null if none of these fields are present.
  let target = null;
  if (typeof toolInput.file_path === "string") target = toolInput.file_path;
  else if (isMcp) target = toolName;
  else if (typeof toolInput.command === "string") target = toolInput.command;
  else if (typeof toolInput.pattern === "string") target = toolInput.pattern;
  else if (typeof toolInput.path === "string") target = toolInput.path;

  // action_type: coarse read/write/execute classification. MCP tools have
  // no fixed verb in tool_name, so a keyword heuristic on the tool name
  // decides mcp_read vs mcp_write — this is a heuristic, not a guarantee,
  // and is documented as such rather than presented as certain.
  let actionType;
  const writeIntent = /(send|create|update|insert|delete|post|write|upload|add|remove|trash|move|schedule|complete|react)/i;
  if (isMcp) {
    actionType = writeIntent.test(toolName) ? "mcp_write" : "mcp_read";
  } else {
    switch (toolName) {
      case "Read": actionType = "read"; break;
      case "Write": actionType = "write"; break;
      case "Edit":
      case "NotebookEdit": actionType = "edit"; break;
      case "Bash":
      case "PowerShell": actionType = "execute"; break;
      case "Glob":
      case "Grep": actionType = "search"; break;
      case "AskUserQuestion": actionType = "prompt"; break;
      case "Agent": actionType = "delegate"; break;
      case "TaskCreate":
      case "TaskUpdate":
      case "TaskGet":
      case "TaskList":
      case "TaskOutput":
      case "TaskStop": actionType = "task_management"; break;
      default: actionType = "other";
    }
  }

  const record = {
    timestamp,
    user,
    tool_name: toolName,
    file_path_or_mcp_endpoint: target,
    action_type: actionType,
    session_id: sessionId
  };

  process.stdout.write(JSON.stringify(record));
});
' "$TIMESTAMP" "$AUDIT_USER" <<<"$INPUT")"

if [[ -z "$LOG_LINE" ]]; then
  echo "audit_log.sh: failed to build an audit record from the hook payload — logging skipped for this call, tool proceeds unaffected" >&2
  exit 0
fi

if ! mkdir -p "$AUDIT_DIR" 2>/dev/null || ! printf '%s\n' "$LOG_LINE" >> "$LOG_FILE" 2>/dev/null; then
  echo "audit_log.sh: could not write to $LOG_FILE — logging skipped for this call, tool proceeds unaffected" >&2
fi

exit 0
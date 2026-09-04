#!/usr/bin/env bash
# parallel_extract.sh — UC4: batch-run the contract-extractor sub-agent
# (.claude/agents/contract-extractor.md) across every contract in
# extraction/input/, one `claude --agent contract-extractor` session per
# file, run concurrently. The agent definition already carries the full
# 22-field schema and output-format rules, so the per-file prompt here
# stays minimal — extend the schema/format in the agent file, not here.
#
# Per CLAUDE.md's PDF Handling rule, PDFs must be chunked first via
# contracts/chunker.sh — this script only processes .txt input.
#
# Usage: extraction/parallel_extract.sh [max_parallel_jobs]
#   max_parallel_jobs defaults to 4.
# Input:  extraction/input/*.txt
# Output: extraction/output/<stem>_extracted.json  (one per input file)
#
# A per-file failure (claude error, unparseable JSON) is reported and
# skipped — it does not abort the rest of the batch. Never silently
# swallow a parsing failure, but one bad contract shouldn't block the
# others (see CLAUDE.md Coding Conventions).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IN_DIR="$SCRIPT_DIR/input"
OUT_DIR="$SCRIPT_DIR/output"
LOG_DIR="$OUT_DIR/.logs"
AGENT_NAME="contract-extractor"
MAX_JOBS="${1:-4}"

command -v claude >/dev/null || { echo "Error: claude CLI not found — install Claude Code" >&2; exit 1; }
command -v jq >/dev/null    || { echo "Error: jq not found — install jq" >&2; exit 1; }
[[ -f "$REPO_ROOT/.claude/agents/${AGENT_NAME}.md" ]] || { echo "Error: agent definition not found at .claude/agents/${AGENT_NAME}.md" >&2; exit 1; }
[[ -d "$IN_DIR" ]] || { echo "Error: input directory not found: $IN_DIR — create it and add contract .txt files" >&2; exit 1; }
[[ "$MAX_JOBS" =~ ^[0-9]+$ && "$MAX_JOBS" -ge 1 ]] || { echo "Error: max_parallel_jobs must be a positive integer, got: $MAX_JOBS" >&2; exit 1; }

shopt -s nullglob
INPUT_FILES=("$IN_DIR"/*.txt)
shopt -u nullglob
[[ ${#INPUT_FILES[@]} -gt 0 ]] || { echo "Error: no .txt files found in $IN_DIR" >&2; exit 1; }

mkdir -p "$OUT_DIR" "$LOG_DIR"
RESULTS_DIR="$(mktemp -d)"
trap 'rm -rf "$RESULTS_DIR"' EXIT

PROMPT="Extract the 22-field hotspot schema from the contract text piped below, per your agent instructions. Output strict JSON only."

extract_one() {
  local contract_file="$1"
  local stem out_file log_file envelope result_text json_body
  stem="$(basename "$contract_file" .txt)"
  out_file="$OUT_DIR/${stem}_extracted.json"
  log_file="$LOG_DIR/${stem}.log"

  if ! envelope="$(cat "$contract_file" | claude -p "$PROMPT" --agent "$AGENT_NAME" --output-format json 2>"$log_file")"; then
    echo "FAIL  $stem — claude session errored, see $log_file" >&2
    : > "$RESULTS_DIR/${stem}.fail"
    return
  fi

  result_text="$(jq -r '.result' <<< "$envelope" 2>>"$log_file")"
  # The agent is told "strict JSON only" but doesn't always comply
  # (markdown code fences observed in practice) — strip any ```/```json
  # fence lines rather than failing on a formatting slip. Line-anchored
  # brace matching (^{ ... ^}) was tried first but breaks on minified
  # single-line JSON, where the closing brace never starts its own line.
  json_body="$(printf '%s\n' "$result_text" | sed -e '/^```/d')"

  if [[ -z "$json_body" ]] || ! jq . <<< "$json_body" > "$out_file" 2>>"$log_file"; then
    echo "FAIL  $stem — could not parse extraction result as JSON, see $log_file" >&2
    rm -f "$out_file"
    : > "$RESULTS_DIR/${stem}.fail"
    return
  fi

  echo "OK    $stem -> $out_file"
  : > "$RESULTS_DIR/${stem}.ok"
}

echo "Extracting ${#INPUT_FILES[@]} contract(s) with up to $MAX_JOBS parallel session(s)..."

for f in "${INPUT_FILES[@]}"; do
  while (( $(jobs -rp | wc -l) >= MAX_JOBS )); do
    wait -n
  done
  extract_one "$f" &
done
wait

ok_count=$(find "$RESULTS_DIR" -name '*.ok' | wc -l)
fail_count=$(find "$RESULTS_DIR" -name '*.fail' | wc -l)
total=$(( ok_count + fail_count ))

echo "---"
echo "$ok_count / $total succeeded"

[[ $fail_count -eq 0 ]]

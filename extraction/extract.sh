#!/usr/bin/env bash
# extract.sh — UC4: extract the 22-field hotspot schema (CLAUDE.md's
# "Extraction Schema" section) from a contract via `claude -p`.
#
# Per CLAUDE.md's PDF Handling rule, PDFs must be chunked first via
# contracts/chunker.sh — this script refuses .pdf input directly.
#
# Usage: extraction/extract.sh <contract_file>
# Output: extraction/output/<contract_stem>_extracted.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$SCRIPT_DIR/output"

[[ $# -ge 1 ]] || { echo "Usage: $0 <contract_file>" >&2; exit 1; }
CONTRACT_FILE="$1"

command -v claude >/dev/null || { echo "Error: claude CLI not found — install Claude Code" >&2; exit 1; }
command -v jq >/dev/null    || { echo "Error: jq not found — install jq" >&2; exit 1; }
[[ -f "$CONTRACT_FILE" ]] || { echo "Error: file not found: $CONTRACT_FILE" >&2; exit 1; }

# PDF Handling rule: never read a PDF directly, chunked or not.
shopt -s nocasematch
if [[ "$CONTRACT_FILE" == *.pdf ]]; then
  echo "Error: $CONTRACT_FILE is a PDF — run contracts/chunker.sh on it first (see CLAUDE.md PDF Handling), then pass the resulting chunk text here." >&2
  exit 1
fi
shopt -u nocasematch

mkdir -p "$OUT_DIR"

# The claude subprocess only receives the contract text via stdin, so it
# can't see CLAUDE.md unless told where to look — --allowedTools "Read"
# plus the explicit path lets it actually open the schema instead of
# guessing at what "22 hotspot fields" means.
PROMPT="Read the extraction schema defined in CLAUDE.md at $REPO_ROOT/CLAUDE.md (the 'Extraction Schema' section, 22 fields), then extract all 22 hotspot fields per that schema from the contract text piped below. Output strict JSON only - no markdown wrapper, no prose. For each field include a citation object with paragraph_number and excerpt (max 20 words). Fields not found in source document: output null. NEVER guess or infer. If the contract names two or more parties without the document itself designating which one is the counterparty (e.g. only 'Party A'/'Party B' or 'Provider'/'Client' labels with no indication of which party is the record-owner's own company), you MUST output null for counterparty_name and add a flag object for it — never pick one party as the counterparty by assumption. Every field's output object MUST include a 'flag' key: null if nothing is ambiguous about that field, or an object {type, reason} if the field is null due to unresolvable ambiguity rather than the document simply not addressing the topic. Include this 'flag' key on all 22 fields every time, not only when a flag applies."

STEM="$(basename "$CONTRACT_FILE" .txt)"
OUT_FILE="$OUT_DIR/${STEM}_extracted.json"

# --output-format json wraps the response in {type, result, ...}; .result
# is itself the JSON string the prompt asked for.
ENVELOPE="$(cat "$CONTRACT_FILE" | claude -p "$PROMPT" --allowedTools "Read" --output-format json)"
RESULT_TEXT="$(jq -r '.result' <<< "$ENVELOPE")"

# The model is told "strict JSON only - no markdown wrapper, no prose" but
# doesn't always comply (observed: ```json fences and trailing prose notes
# in practice) — strip down to the outermost {...} rather than failing on
# a formatting slip (never silently swallow a parsing failure, but don't
# be needlessly brittle about it either).
JSON_BODY="$(printf '%s\n' "$RESULT_TEXT" | sed -n '/^{/,/^}/p')"

if [[ -z "$JSON_BODY" ]] || ! jq . <<< "$JSON_BODY" > "$OUT_FILE"; then
  echo "Error: could not parse extraction result as JSON, even after stripping markdown fences/prose:" >&2
  echo "$RESULT_TEXT" >&2
  rm -f "$OUT_FILE"
  exit 1
fi

echo "Written to $OUT_FILE"

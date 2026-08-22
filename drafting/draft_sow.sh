#!/usr/bin/env bash
# draft_sow.sh — fast-path SOW drafter (UC1 prototype, SOW variant).
#
# Reads drafting/templates/sow_template.md and asks Claude to fill in the
# placeholders for the given deal parameters, producing an attorney-quality
# first-draft SOW in under 60 seconds. This is NOT the final UC1 pipeline —
# it produces markdown, not the .docx + risk_level/source-tagged output
# described in PRD.md. It is a fast prototype for a human lawyer to review
# and edit before anything is sent to a counterparty; nothing here is final
# or auto-sent (see CLAUDE.md Redline Rules).
#
# Usage: ./drafting/draft_sow.sh --party-a NAME --party-b NAME \
#          --project-scope TEXT --deliverables TEXT --milestones TEXT \
#          --acceptance-criteria TEXT --change-order-process TEXT \
#          [--stdout]
#
# Output: drafting/output/<YYYY-MM-DD>_SOW_<party-a-slug>_<party-b-slug>.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/templates/sow_template.md"
OUT_DIR="$SCRIPT_DIR/output"

usage() {
  cat >&2 <<'EOF'
Usage: draft_sow.sh --party-a NAME --party-b NAME --project-scope TEXT \
         --deliverables TEXT --milestones TEXT --acceptance-criteria TEXT \
         --change-order-process TEXT [--stdout]

  --party-a                 Legal name of the Service Provider (required)
  --party-b                 Legal name of the Client (required)
  --project-scope           Description of the project scope (required)
  --deliverables            List of deliverables (required)
  --milestones              Milestones with dates (required)
  --acceptance-criteria     Criteria for accepting a deliverable (required)
  --change-order-process    How scope/schedule changes are requested and
                             approved (required)
  --stdout                  Also print the drafted SOW to stdout
EOF
}

# --- args -----------------------------------------------------------------
PARTY_A=""
PARTY_B=""
PROJECT_SCOPE=""
DELIVERABLES=""
MILESTONES=""
ACCEPTANCE_CRITERIA=""
CHANGE_ORDER_PROCESS=""
PRINT_STDOUT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --party-a) PARTY_A="${2:-}"; shift 2 ;;
    --party-b) PARTY_B="${2:-}"; shift 2 ;;
    --project-scope) PROJECT_SCOPE="${2:-}"; shift 2 ;;
    --deliverables) DELIVERABLES="${2:-}"; shift 2 ;;
    --milestones) MILESTONES="${2:-}"; shift 2 ;;
    --acceptance-criteria) ACCEPTANCE_CRITERIA="${2:-}"; shift 2 ;;
    --change-order-process) CHANGE_ORDER_PROCESS="${2:-}"; shift 2 ;;
    --stdout) PRINT_STDOUT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

# --- validation (fail loudly before doing any real work) ------------------
command -v claude >/dev/null || { echo "Error: claude CLI not found — install Claude Code" >&2; exit 1; }
[[ -f "$TEMPLATE" ]] || { echo "Error: template not found: $TEMPLATE" >&2; exit 1; }

[[ -n "$PARTY_A" ]]               || { echo "Error: --party-a is required" >&2; usage; exit 1; }
[[ -n "$PARTY_B" ]]               || { echo "Error: --party-b is required" >&2; usage; exit 1; }
[[ -n "$PROJECT_SCOPE" ]]         || { echo "Error: --project-scope is required" >&2; usage; exit 1; }
[[ -n "$DELIVERABLES" ]]          || { echo "Error: --deliverables is required" >&2; usage; exit 1; }
[[ -n "$MILESTONES" ]]            || { echo "Error: --milestones is required" >&2; usage; exit 1; }
[[ -n "$ACCEPTANCE_CRITERIA" ]]   || { echo "Error: --acceptance-criteria is required" >&2; usage; exit 1; }
[[ -n "$CHANGE_ORDER_PROCESS" ]]  || { echo "Error: --change-order-process is required" >&2; usage; exit 1; }

# --- prompt construction ---------------------------------------------------
# Built with printf/%s substitution (not direct double-quoted interpolation)
# so party names or free-text fields containing $, `, &, or quotes can never
# be interpreted as shell syntax inside the prompt string.
PROMPT_TEMPLATE='Read %s. Draft a complete SOW replacing all placeholders for the parties and terms below. Output clean, properly formatted markdown only — no commentary, no code fences, and no explanation before or after the document.

Provider (Party A): %s
Client (Party B): %s
Project scope: %s
Deliverables: %s
Milestones (with dates): %s
Acceptance criteria: %s
Change order process: %s

Follow the placeholder-handling instructions in the template file exactly. If a value needed for a placeholder is not provided above and cannot be reasonably inferred, leave the bracketed "[... TO BE COMPLETED]" marker specified in the template rather than inventing a value. Use today'"'"'s date for the effective date, in ISO 8601 format (YYYY-MM-DD).

Do not attempt to write, save, or create any file, and do not use any tool other than reading the template. Your entire response must be only the drafted SOW text, starting with the "# Statement of Work" heading — never mention tools, permissions, file operations, or your own process anywhere in the response.'

PROMPT=$(printf "$PROMPT_TEMPLATE" "$TEMPLATE" "$PARTY_A" "$PARTY_B" "$PROJECT_SCOPE" "$DELIVERABLES" "$MILESTONES" "$ACCEPTANCE_CRITERIA" "$CHANGE_ORDER_PROCESS")

# --- invoke claude ----------------------------------------------------------
echo "Drafting SOW: $PARTY_A vs $PARTY_B ..."

if ! OUTPUT=$(claude -p "$PROMPT" --allowedTools "Read" --output-format text); then
  echo "Error: claude CLI failed — check authentication (run 'claude /login') and network access" >&2
  exit 1
fi

# --- sanity check before writing anything -----------------------------------
# Never silently save a refusal, empty response, or partial draft as if it
# were a valid SOW (see CLAUDE.md: never silently swallow parsing failures).
if [[ -z "$(tr -d '[:space:]' <<< "$OUTPUT")" ]]; then
  echo "Error: claude returned an empty response — no draft was written" >&2
  exit 2
fi
FIRST_LINE="$(grep -m1 -v '^[[:space:]]*$' <<< "$OUTPUT")"
if [[ "$FIRST_LINE" != "# Statement of Work" ]]; then
  echo "Error: claude's response has leading text before the SOW heading (likely leaked commentary about tool use, permissions, or its own process) — no draft was written" >&2
  echo "--- response start ---" >&2
  echo "$OUTPUT" >&2
  echo "--- response end ---" >&2
  exit 2
fi
if ! grep -qi 'Deliverables' <<< "$OUTPUT"; then
  echo "Error: claude's response is missing expected SOW structure (no 'Deliverables' section found) — no draft was written" >&2
  echo "--- response start ---" >&2
  echo "$OUTPUT" >&2
  echo "--- response end ---" >&2
  exit 2
fi
if ! grep -qi 'Milestone' <<< "$OUTPUT"; then
  echo "Error: claude's response is missing expected SOW structure (no 'Milestones' section found) — no draft was written" >&2
  echo "--- response start ---" >&2
  echo "$OUTPUT" >&2
  echo "--- response end ---" >&2
  exit 2
fi
if ! grep -qi 'Acceptance Criteria' <<< "$OUTPUT"; then
  echo "Error: claude's response is missing expected SOW structure (no 'Acceptance Criteria' section found) — no draft was written" >&2
  echo "--- response start ---" >&2
  echo "$OUTPUT" >&2
  echo "--- response end ---" >&2
  exit 2
fi
if ! grep -qi 'Change Order' <<< "$OUTPUT"; then
  echo "Error: claude's response is missing expected SOW structure (no 'Change Order' section found) — no draft was written" >&2
  echo "--- response start ---" >&2
  echo "$OUTPUT" >&2
  echo "--- response end ---" >&2
  exit 2
fi

# --- write output -------------------------------------------------------
# Non-Latin/non-ASCII names (e.g. CJK, Cyrillic) strip down to nothing under
# the a-z0-9 filter below. Falling back to a bare "party" for every such name
# would make different parties collide on the same output filename and
# silently overwrite each other's draft — so fall back to a short checksum
# of the original name instead, which is deterministic and distinct per name.
slugify() {
  local slug
  slug=$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g')
  if [[ -z "$slug" ]]; then
    slug="party_$(printf '%s' "$1" | cksum | cut -d' ' -f1)"
  fi
  echo "$slug"
}

mkdir -p "$OUT_DIR"
DATE_STAMP="$(date +%Y-%m-%d)"
OUT_FILE="$OUT_DIR/${DATE_STAMP}_SOW_$(slugify "$PARTY_A")_$(slugify "$PARTY_B").md"

printf '%s\n' "$OUTPUT" > "$OUT_FILE"

echo "Written to $OUT_FILE"
if (( PRINT_STDOUT )); then
  echo "---"
  echo "$OUTPUT"
fi

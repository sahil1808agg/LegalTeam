#!/usr/bin/env bash
# redline.sh — playbook-driven redline comparison (UC2/UC3 prototype).
#
# Reads an incoming counterparty contract and a firm playbook (e.g.
# redlining/playbooks/msa_playbook.md) and asks Claude to compare the
# incoming draft against the playbook's standard positions, clause by
# clause. This is NOT the final UC2/UC3 pipeline — it produces a markdown
# report, not a structured diff inserted into the database. It is a fast
# prototype for a human lawyer to review; nothing here is auto-sent to a
# counterparty and no disposition is auto-applied (see CLAUDE.md Redline
# Rules 3 and 6).
#
# For every numbered clause in the playbook, the report captures:
#   1. Standard position (from the playbook)
#   2. Counterparty position (from the incoming contract, with citation)
#   3. Deviation — YES/NO
#   4. Risk level — HIGH/MED/LOW with a one-sentence rationale
#   5. Recommended response (grounded in the playbook's fallback/floor)
#
# Usage: ./redlining/redline.sh --incoming FILE --playbook FILE [--stdout]
#
# Output: redlining/output/<YYYY-MM-DD>_redline_report_<incoming-slug>.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/output"

usage() {
  cat >&2 <<'EOF'
Usage: redline.sh --incoming FILE --playbook FILE [--stdout]

  --incoming   Path to the incoming counterparty contract (markdown/text) (required)
  --playbook   Path to the firm playbook, e.g. redlining/playbooks/msa_playbook.md (required)
  --stdout     Also print the redline report to stdout
EOF
}

# --- args -----------------------------------------------------------------
INCOMING=""
PLAYBOOK=""
PRINT_STDOUT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --incoming) INCOMING="${2:-}"; shift 2 ;;
    --playbook) PLAYBOOK="${2:-}"; shift 2 ;;
    --stdout) PRINT_STDOUT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

# --- validation (fail loudly before doing any real work) ------------------
command -v claude >/dev/null || { echo "Error: claude CLI not found — install Claude Code" >&2; exit 1; }

[[ -n "$INCOMING" ]] || { echo "Error: --incoming is required" >&2; usage; exit 1; }
[[ -n "$PLAYBOOK" ]] || { echo "Error: --playbook is required" >&2; usage; exit 1; }
[[ -f "$INCOMING" ]] || { echo "Error: incoming contract not found: $INCOMING" >&2; exit 1; }
[[ -f "$PLAYBOOK" ]] || { echo "Error: playbook not found: $PLAYBOOK" >&2; exit 1; }

# Number of numbered clause sections in the playbook (e.g. "## 1. Liability
# Cap"). Used below to fail loudly if the report silently drops a clause
# rather than flagging it as "not addressed" (never silently swallow — see
# CLAUDE.md Coding Conventions).
CLAUSE_COUNT="$(grep -cE '^## [0-9]+\.' "$PLAYBOOK")"
if [[ "$CLAUSE_COUNT" -eq 0 ]]; then
  echo "Error: no numbered clause sections (## 1., ## 2., ...) found in playbook: $PLAYBOOK" >&2
  exit 1
fi

# --- prompt construction ---------------------------------------------------
# Built with printf/%s substitution (not direct double-quoted interpolation)
# so file paths containing $, `, &, or quotes can never be interpreted as
# shell syntax inside the prompt string.
PROMPT_TEMPLATE='Read the incoming counterparty contract at %s and the firm playbook at %s.

The playbook contains %s numbered clause sections (## 1., ## 2., etc.), each with a standard opening position, a fallback range, a floor, and redline signals. For EVERY one of these %s clauses, produce one row in a single markdown table with exactly these columns, in this order:

| # | Clause | Standard Position | Counterparty Position | Deviation (YES/NO) | Risk Level | Recommended Response |

Column rules:
- "Clause": the clause name from the playbook heading (e.g. "Liability Cap").
- "Standard Position": a concise one- to two-sentence summary of the playbook opening position for that clause.
- "Counterparty Position": a concise summary of what the incoming contract actually says for that clause, with an inline citation to its location in the incoming document (e.g. "Section 7.2" or "para. 12"). If the incoming contract is silent on this clause entirely, write "Not addressed in incoming draft" — never invent counterparty language that is not actually present (see CLAUDE.md Legal Accuracy Rules: null/absent beats a fabricated value).
- "Deviation (YES/NO)": YES if the counterparty position differs from the playbook standard position (including silence on a clause that should be present), NO if it matches or falls within the playbook fallback range.
- "Risk Level": HIGH, MED, or LOW, followed by a colon and a one-sentence rationale in the same cell (e.g. "HIGH: removes the liability cap entirely, exposing uncapped exposure"). Base the level on how far the counterparty position sits from the playbook floor — at or beyond the floor is HIGH, within the fallback range but off the opening position is MED, matching the opening position is LOW. If the clause is genuinely ambiguous in the incoming draft (e.g. conflicting language, an undefined term), do not guess a resolution — say so explicitly in the rationale and flag it for human review instead of picking a risk level based on an assumed interpretation.
- "Recommended Response": a concrete, one- to two-sentence next step grounded in the playbook fallback/floor for that clause (e.g. "Counter at 2x fees per playbook opening position; floor is 1x — escalate to senior attorney if counterparty will not move off 0.5x."). Recommendations are decision support only — this table does not authorize sending anything to the counterparty without lawyer sign-off.

Output ONLY the markdown report, in exactly this structure, with no commentary before or after:

# Redline Report

**Incoming contract:** %s
**Playbook:** %s
**Generated:** today'"'"'s date in ISO 8601 (YYYY-MM-DD)

<the markdown table with %s data rows, one per playbook clause, in the same order as the playbook>

## Summary

A short bulleted list (3-6 bullets) calling out only the HIGH risk deviations, each with the clause name and a one-sentence reason they need attorney attention first.

Do not attempt to write, save, or create any file, and do not use any tool other than reading the two files above. Your entire response must be only the report text described above, starting with the "# Redline Report" heading — never mention tools, permissions, file operations, or your own process anywhere in the response.'

PROMPT=$(printf "$PROMPT_TEMPLATE" "$INCOMING" "$PLAYBOOK" "$CLAUSE_COUNT" "$CLAUSE_COUNT" "$INCOMING" "$PLAYBOOK" "$CLAUSE_COUNT")

# --- invoke claude ----------------------------------------------------------
echo "Comparing $INCOMING against $PLAYBOOK ($CLAUSE_COUNT clauses) ..."

# On any failure, print the CLI's actual message instead of guessing at the
# cause (never silently swallow parsing failures — see CLAUDE.md Coding
# Conventions). Output-token cap is set repo-wide via
# .claude/settings.json (CLAUDE_CODE_MAX_OUTPUT_TOKENS), no override needed here.
if ! OUTPUT=$(claude -p "$PROMPT" --allowedTools "Read" --output-format text < /dev/null); then
  echo "Error: claude CLI failed:" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

# --- sanity checks before writing anything ----------------------------------
# Never silently save a refusal, empty response, or partial report as if it
# were a complete redline comparison (see CLAUDE.md: never silently swallow
# parsing failures).
if [[ -z "$(tr -d '[:space:]' <<< "$OUTPUT")" ]]; then
  echo "Error: claude returned an empty response — no report was written" >&2
  exit 2
fi
FIRST_LINE="$(grep -m1 -v '^[[:space:]]*$' <<< "$OUTPUT")"
if [[ "$FIRST_LINE" != "# Redline Report" ]]; then
  echo "Error: claude's response has leading text before the report heading (likely leaked commentary about tool use, permissions, or its own process) — no report was written" >&2
  echo "--- response start ---" >&2
  echo "$OUTPUT" >&2
  echo "--- response end ---" >&2
  exit 2
fi
if ! grep -qE '^\| *# *\|' <<< "$OUTPUT"; then
  echo "Error: claude's response is missing the expected deviation table header — no report was written" >&2
  echo "--- response start ---" >&2
  echo "$OUTPUT" >&2
  echo "--- response end ---" >&2
  exit 2
fi

# Count data rows in the table (lines starting with "|" that are not the
# header row or the "---" separator row) and confirm none of the playbook's
# clauses were silently dropped — a short table is a parsing failure, not a
# valid partial result (CLAUDE.md: fail loudly, don't return best-guess
# partial output without marking it as such).
ROW_COUNT="$(grep -E '^\|' <<< "$OUTPUT" | grep -vE '^\| *# *\|' | grep -vE '^\|[-| ]+\|$' | wc -l | tr -d ' ')"
if [[ "$ROW_COUNT" -lt "$CLAUSE_COUNT" ]]; then
  echo "Error: expected $CLAUSE_COUNT clause rows but found $ROW_COUNT in the table — report is incomplete, no report was written" >&2
  echo "--- response start ---" >&2
  echo "$OUTPUT" >&2
  echo "--- response end ---" >&2
  exit 2
fi

# --- write output -------------------------------------------------------
# Falls back to a checksum slug for incoming-file names with no a-z0-9
# characters (e.g. non-Latin filenames), so distinct inputs never collide on
# the same output filename and silently overwrite each other's report.
slugify() {
  local slug
  slug=$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g')
  if [[ -z "$slug" ]]; then
    slug="contract_$(printf '%s' "$1" | cksum | cut -d' ' -f1)"
  fi
  echo "$slug"
}

mkdir -p "$OUT_DIR"
DATE_STAMP="$(date +%Y-%m-%d)"
INCOMING_BASENAME="$(basename "$INCOMING")"
INCOMING_STEM="${INCOMING_BASENAME%.*}"
OUT_FILE="$OUT_DIR/${DATE_STAMP}_redline_report_$(slugify "$INCOMING_STEM").md"

printf '%s\n' "$OUTPUT" > "$OUT_FILE"

echo "Written to $OUT_FILE"
if (( PRINT_STDOUT )); then
  echo "---"
  echo "$OUTPUT"
fi

#!/usr/bin/env bash
# install.sh — one-time setup for ContractIQ.
#
# Written for a non-technical colleague: every check prints a plain-English
# pass/fail line, and a missing prerequisite stops the script with a clear
# next step instead of a raw error. Never leaves the repo half-configured —
# each step is safe to re-run if something was missing the first time.
#
# Usage: ./install.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

MISSING=0

echo "ContractIQ setup"
echo "================"
echo ""

check_tool() {
  local name="$1" cmd="$2" install_hint="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "[OK]   $name found"
  else
    echo "[MISS] $name not found — $install_hint"
    MISSING=1
  fi
}

echo "Step 1 of 3 — checking required tools..."
check_tool "Claude Code CLI" "claude" "install it from https://claude.ai/code, then re-run this script"
check_tool "jq (JSON tool)"  "jq"     "install it from https://jqlang.org/download, then re-run this script"
check_tool "Node.js"         "node"   "install it from https://nodejs.org, then re-run this script"
echo ""

if [[ "$MISSING" -eq 1 ]]; then
  echo "One or more required tools are missing — install them using the links"
  echo "above, then run ./install.sh again. Nothing has been changed yet."
  exit 1
fi

echo "Step 2 of 3 — making pipeline scripts runnable..."
# chmod +x is silently skipped (not failed) on filesystems that don't
# support unix permission bits (e.g. some Windows setups) — those scripts
# still run fine via `bash script.sh`, they just can't be run as `./script.sh`.
for script in \
  drafting/draft_nda.sh drafting/draft_msa.sh drafting/draft_sow.sh \
  redlining/redline.sh \
  extraction/extract.sh extraction/parallel_extract.sh extraction/insert_hotspots.sh extraction/merge_portfolio.sh \
  obligations/check_deadlines.sh \
  contracts/chunker.sh \
  .claude/hooks/pre_redline.sh .claude/hooks/post_redline.sh .claude/hooks/validate_input.sh .claude/hooks/freshness_check.sh .claude/hooks/audit_log.sh \
  install.sh
do
  [[ -f "$script" ]] && chmod +x "$script" 2>/dev/null
done
echo "[OK]   scripts are runnable"
echo ""

echo "Step 3 of 3 — creating working folders (safe to run even if they already exist)..."
mkdir -p drafting/output extraction/input extraction/output extraction/output/.logs redlining/output
echo "[OK]   working folders ready"
echo ""

echo "Setup complete."
echo ""
echo "Next step: open this folder in Claude Code, type /extract-contract,"
echo "and follow the prompts."

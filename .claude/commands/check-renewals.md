---
description: Scan all extracted contracts for upcoming renewal/notice deadlines (UC6) via obligations/check_deadlines.sh
argument-hint: [--days N] [--output json|markdown|slack]
allowed-tools: Bash(./obligations/check_deadlines.sh:*), Bash(obligations/check_deadlines.sh:*)
---

You are running the UC6 obligation-tracking command. It only reports what
`obligations/check_deadlines.sh` finds in `extraction/output/*.json` — never
invent a deadline or counterparty that isn't in an extracted contract file.

## Arguments provided

$ARGUMENTS

## Step 1 — Determine parameters

- `--days N` — lookahead window in days. Default to 90 if not specified;
  don't ask the user unless they seem to want a different window.
- `--output FORMAT` — `json` (default), `markdown`, or `slack`. Prefer
  `markdown` when the user wants a readable summary; use `json` if they say
  they want to pipe/parse the result themselves.

## Step 2 — Run the script

```
./obligations/check_deadlines.sh --days <N> --output <FORMAT>
```

## Step 3 — Report

- If the result is `[]`, tell the user plainly: no renewal deadlines in the
  next N days — nothing further to do.
- Otherwise, surface the risk breakdown clearly:
  - 🔴 **CRITICAL** — ≤14 days, needs `REVIEW_REQUIRED` action now
  - 🟠 **URGENT** — 15–30 days
  - 🟡 **WARNING** — 31–90 days
- Call out any `auto_renewal: true` contracts specifically — a missed notice
  on an auto-renewing contract has real financial consequences.
- If the script errors (missing `jq`, no `extraction/output/` directory),
  surface the exact error — don't silently report an empty result as if it
  meant "no deadlines."

---
description: Scan the merged contract portfolio for upcoming renewal/expiry deadlines (UC6) and post a tiered Slack alert via obligations/check_deadlines.sh
argument-hint: [--days N] [--channel CHANNEL] [--dry-run]
allowed-tools: Bash(./obligations/check_deadlines.sh:*), Bash(obligations/check_deadlines.sh:*)
---

You are running the UC6 obligation-tracking command. It only reports what
`obligations/check_deadlines.sh` computes from
`extraction/output/master_portfolio.json` — never invent a deadline,
counterparty, or contract that isn't in that file. If the portfolio file is
missing, tell the user to run `extraction/merge_portfolio.sh` first; don't
guess at its contents.

## Arguments provided

$ARGUMENTS

## Step 1 — Determine parameters

- `--days N` — lookahead window in days, applied to both the renewal-notice
  deadline and the contract expiry date. Default to 90 if not specified;
  don't ask the user unless they seem to want a different window.
- `--channel CHANNEL` — Slack channel to post to. Default to `#legal-contracts`
  unless the user names a different one.
- `--dry-run` — use this if the user wants to preview the alert data/prompt
  without actually posting to Slack (e.g. "show me what would go out" or
  "don't post yet").

## Step 2 — Run the script

```
./obligations/check_deadlines.sh --days <N> --channel <CHANNEL> [--dry-run]
```

The script itself computes `expiry_date` (effective/execution date + term
length) and `renewal_date` (the extracted renewal notice deadline, or expiry
date minus the termination notice period) deterministically — this command
should never redo or override that math. When not run with `--dry-run`, the
script also invokes Claude with Slack MCP access to actually post the alerts.

## Step 3 — Report

- If the script reports "No deadlines within the window", tell the user
  plainly: nothing due in the next N days — nothing further to do.
- Otherwise, summarize what was posted (or would be posted, for `--dry-run`)
  by tier:
  - 🔴 **URGENT** — under 30 days
  - 🟠 **ACTION NEEDED** — 30–60 days
  - 🟡 **WATCH** — 60–90 days
- Call out any `auto_renewal: true` contracts specifically — a missed notice
  on an auto-renewing contract has real financial consequences.
- Recommended actions in the alert (renew/renegotiate/terminate/let-expire)
  are suggestions only, always requiring lawyer review — never present them
  to the user as decisions already made.
- If the script errors (missing `jq`/`claude`, missing portfolio file),
  surface the exact error — don't silently report an empty result as if it
  meant "no deadlines."

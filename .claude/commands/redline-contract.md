---
description: Run a playbook-driven redline comparison (UC2/UC3) of an incoming counterparty contract via redlining/redline.sh
argument-hint: [incoming-file] [playbook-file]
allowed-tools: Bash(./redlining/redline.sh:*), Bash(redlining/redline.sh:*), Glob(redlining/playbooks/*.md), AskUserQuestion
---

You are running the UC2/UC3 redline comparison command. This produces a
markdown report for lawyer review only — nothing here is auto-sent to a
counterparty and no disposition is auto-applied (CLAUDE.md Redline Rules 3
and 6). The incoming document must always be diffed against the canonical
playbook, never against a previous redline round (Redline Rule 1).

## Arguments provided

$ARGUMENTS

If arguments were provided above, they are in this order: incoming-file,
playbook-file.

## Step 1 — Collect inputs

1. **Incoming contract** — path to the counterparty's draft (markdown/text).
   Ask the user if not provided.
2. **Playbook** — path to the firm playbook to compare against, e.g.
   `redlining/playbooks/msa_playbook.md` or `redlining/playbooks/nda_playbook.md`.
   If not provided, glob `redlining/playbooks/*.md` and ask the user to pick
   one from the list (use AskUserQuestion if there's more than one match).

## Step 2 — Validate

- Both files must exist before calling the script.
- If the incoming file is very short (the script's own `validate_input.sh`
  hook will warn if under 500 words), don't block on it yourself — let the
  hook's warning surface and relay it to the user, since a short document
  may still be a legitimate short-form NDA.

## Step 3 — Run the script

```
./redlining/redline.sh --incoming <incoming-file> --playbook <playbook-file> --stdout
```

This produces one row per playbook clause: standard position, cited
counterparty position, deviation YES/NO, risk level (grounded in the
playbook's fallback range and floor — this is also the UC3 fallback
comparison), and a recommended response.

## Step 4 — Report

- On success, report the output path:
  `redlining/output/<YYYY-MM-DD>_redline_report_<incoming-slug>.md`, and
  call out any HIGH risk deviations from the report's Summary section first.
- On failure (empty response, missing table, dropped clause rows, leaked
  commentary before the report heading), surface the script's exact stderr
  — these are all fail-loudly cases by design, not something to retry or
  smooth over.
- Remind the user this report is decision support only — no redline is sent
  to the counterparty without explicit lawyer sign-off.

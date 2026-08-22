---
description: Interactively draft a new SOW (project scope, deliverables, milestones with dates, acceptance criteria, change order process) via drafting/draft_sow.sh
argument-hint: [party-a] [party-b] [project-scope] [deliverables] [milestones] [acceptance-criteria] [change-order-process]
allowed-tools: Bash(./drafting/draft_sow.sh:*), Bash(drafting/draft_sow.sh:*), AskUserQuestion
---

You are running the UC1 fast-path SOW drafter. Collect the required inputs,
validate them, then generate the draft by calling `drafting/draft_sow.sh`.
Never fabricate or guess a value the user didn't provide — always ask.

## Arguments provided

$ARGUMENTS

If arguments were provided above, they are in this order: party-a, party-b,
project-scope, deliverables, milestones, acceptance-criteria,
change-order-process. Treat any that are missing, empty, or clearly
placeholder text as not provided. If the arguments look misordered (e.g. a
deliverables-shaped value where a milestones value is expected), do not guess
how to remap them — tell the user what looks wrong and ask them to confirm
each affected field individually.

## Step 1 — Collect inputs

For each of the following not already supplied via arguments, ask the user
directly in chat, one at a time (don't dump all questions at once):

1. **Party A** — legal name of the Service Provider.
2. **Party B** — legal name of the Client.
3. **Project scope** — description of the work covered by this SOW.
4. **Deliverables** — the list of deliverables Provider will produce.
5. **Milestones** — milestones with dates (e.g. "Design review — 2026-09-15;
   Beta delivery — 2026-10-30"). Every milestone should have an associated
   date; if the user gives a milestone without a date, ask for the date
   rather than leaving it implicit.
6. **Acceptance criteria** — how a Deliverable is judged accepted or
   rejected.
7. **Change order process** — how scope, schedule, or fee changes are
   requested and approved.

## Step 2 — Validate

Before calling the script, check every value:

- Non-empty after trimming whitespace.
- Not a placeholder like "N/A", "TBD", or "-".
- Milestones must reference at least one date. If a milestone is given with
  no date at all, tell the user and re-ask just that field.

If any value fails validation, tell the user which field is invalid and
re-ask for that field only. Do not proceed to Step 3 until all values are
valid.

## Step 3 — Generate the draft

Run:

```
./drafting/draft_sow.sh --party-a "<party-a>" --party-b "<party-b>" \
  --project-scope "<project-scope>" \
  --deliverables "<deliverables>" \
  --milestones "<milestones>" \
  --acceptance-criteria "<acceptance-criteria>" \
  --change-order-process "<change-order-process>"
```

Quote each value exactly as given (don't reformat or "correct" names,
dollar amounts, or dates beyond what the user already stated). The script
writes the draft to:

```
drafting/output/<YYYY-MM-DD>_SOW_<party-a-slug>_<party-b-slug>.md
```

## Step 4 — Report

- If the script succeeds, tell the user the output file path it printed, and
  remind them this is a first-pass draft for lawyer review — nothing here is
  final or sent to a counterparty (see CLAUDE.md Redline Rules). Note per
  CLAUDE.md that a SOW is typically nested under an MSA, so if this
  engagement has a governing MSA, a lawyer should confirm how this SOW
  references or attaches to it.
- If the script fails (missing `claude` CLI, empty response, malformed
  response, etc.), surface its exact stderr output to the user — do not
  retry silently or paper over the failure.

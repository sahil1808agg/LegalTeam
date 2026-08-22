---
description: Interactively draft a new NDA (party names, jurisdiction, term, mutual/one-way) via drafting/draft_nda.sh
argument-hint: [party-a] [party-b] [jurisdiction] [term] [mutual|one-way]
allowed-tools: Bash(./drafting/draft_nda.sh:*), Bash(drafting/draft_nda.sh:*), AskUserQuestion
---

You are running the UC1 fast-path NDA drafter. Collect the five required
inputs, validate them, then generate the draft by calling
`drafting/draft_nda.sh`. Never fabricate or guess a value the user didn't
provide — always ask.

## Arguments provided

$ARGUMENTS

If arguments were provided above, they are in this order: party-a, party-b,
jurisdiction, term, mutual. Treat any that are missing, empty, or clearly
placeholder text as not provided.

## Step 1 — Collect inputs

For each of the five inputs not already supplied via arguments, ask the user
directly in chat, one at a time (don't dump all five questions at once):

1. **Party A** — legal name of the first party.
2. **Party B** — legal name of the counterparty.
3. **Jurisdiction** — governing law / venue (e.g. "Delaware").
4. **Term** — agreement term length (e.g. "2 years").
5. **Mutual vs one-way** — use the AskUserQuestion tool for this one, since
   it's a clean binary choice:
   - "Mutual" — both parties disclose confidential information.
   - "One-way" — only Party A discloses confidential information to Party B.

## Step 2 — Validate

Before calling the script, check every value:

- Non-empty after trimming whitespace.
- Not a placeholder like "N/A", "TBD", or "-".

If any value fails validation, tell the user which field is invalid and
re-ask for that field only. Do not proceed to Step 3 until all five values
are valid.

## Step 3 — Generate the draft

Map the mutual/one-way answer to the script's expected value: "Mutual" →
`yes`, "One-way" → `no`.

Run:

```
./drafting/draft_nda.sh --party-a "<party-a>" --party-b "<party-b>" --jurisdiction "<jurisdiction>" --term "<term>" --mutual <yes|no>
```

Quote each value exactly as given (don't reformat or "correct" names,
jurisdictions, or dates). The script writes the draft to:

```
drafting/output/<YYYY-MM-DD>_NDA_<party-a-slug>_<party-b-slug>.md
```

## Step 4 — Report

- If the script succeeds, tell the user the output file path it printed and
  remind them this is a first-pass draft for lawyer review — nothing here is
  final or sent to a counterparty (see CLAUDE.md Redline Rules).
- If the script fails (missing `claude` CLI, empty response, malformed
  response, etc.), surface its exact stderr output to the user — do not
  retry silently or paper over the failure.

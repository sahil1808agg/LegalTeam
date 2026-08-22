---
description: Interactively draft a new MSA (services, payment terms, IP ownership, liability cap, warranty disclaimers, governing law) via drafting/draft_msa.sh
argument-hint: [party-a] [party-b] [services-description] [payment-terms] [ip-ownership] [warranty-disclaimers] [governing-law] [term] [liability-cap-multiplier]
allowed-tools: Bash(./drafting/draft_msa.sh:*), Bash(drafting/draft_msa.sh:*), AskUserQuestion
---

You are running the UC1 fast-path MSA drafter. Collect the required inputs,
validate them, then generate the draft by calling `drafting/draft_msa.sh`.
Never fabricate or guess a value the user didn't provide — always ask.

## Arguments provided

$ARGUMENTS

If arguments were provided above, they are in this order: party-a, party-b,
services-description, payment-terms, ip-ownership, warranty-disclaimers,
governing-law, term, liability-cap-multiplier. Treat any that are missing,
empty, or clearly placeholder text as not provided. If the arguments look
misordered (e.g. a jurisdiction-shaped value where a payment-terms value is
expected), do not guess how to remap them — tell the user what looks wrong
and ask them to confirm each affected field individually.

## Step 1 — Collect inputs

For each of the following not already supplied via arguments, ask the user
directly in chat, one at a time (don't dump all questions at once):

1. **Party A** — legal name of the Service Provider.
2. **Party B** — legal name of the Client.
3. **Services description** — what Provider will do for Client.
4. **Payment terms** — fees, frequency, invoicing terms (e.g. "$10,000/month, Net 30").
5. **IP ownership** — who owns work product / pre-existing IP.
6. **Warranty disclaimers** — any additional disclaimer language beyond the
   template's standard "AS-IS" baseline (the user may say "none" — that is a
   valid, non-empty answer meaning no additions beyond the baseline).
7. **Governing law** — governing law / venue (e.g. "Delaware").
8. **Term** — agreement term length (e.g. "2 years").
9. **Liability cap multiplier** — optional. Ask the user whether they want to
   override the default 2x-fees liability cap. If they don't want to override
   it, do not pass `--liability-cap-multiplier` at all and let the script's
   own default (2) apply — don't hardcode "2" yourself as if the user chose it.

## Step 2 — Validate

Before calling the script, check every required value (all except the
liability cap multiplier, which is optional):

- Non-empty after trimming whitespace.
- Not a placeholder like "N/A", "TBD", or "-" (except warranty-disclaimers,
  where an explicit "none" is valid and should be passed through as-is).
- If a liability cap multiplier was given, it must be a positive number
  (e.g. "2", "1.5", "3"). If it isn't, tell the user and re-ask just that field.

If any required value fails validation, tell the user which field is invalid
and re-ask for that field only. Do not proceed to Step 3 until all required
values are valid.

## Step 3 — Generate the draft

Run:

```
./drafting/draft_msa.sh --party-a "<party-a>" --party-b "<party-b>" \
  --services-description "<services-description>" \
  --payment-terms "<payment-terms>" \
  --ip-ownership "<ip-ownership>" \
  --warranty-disclaimers "<warranty-disclaimers>" \
  --governing-law "<governing-law>" \
  --term "<term>" \
  [--liability-cap-multiplier "<multiplier>"]
```

Quote each value exactly as given (don't reformat or "correct" names,
jurisdictions, dollar amounts, or dates). Only include
`--liability-cap-multiplier` if the user explicitly chose to override the
default. The script writes the draft to:

```
drafting/output/<YYYY-MM-DD>_MSA_<party-a-slug>_<party-b-slug>.md
```

## Step 4 — Report

- If the script succeeds, tell the user the output file path it printed, note
  what liability cap multiplier was actually used (the override, or the
  script's 2x default if none was given), and remind them this is a
  first-pass draft for lawyer review — nothing here is final or sent to a
  counterparty (see CLAUDE.md Redline Rules).
- If the script fails (missing `claude` CLI, empty response, malformed
  response, etc.), surface its exact stderr output to the user — do not
  retry silently or paper over the failure.

# CLAUDE.md — ContractIQ

Guidance for any AI agent (or engineer) working in this repository. This file is the operating contract for how ContractIQ is built — read it before writing drafting, redline, extraction, or obligation-tracking logic. Source of truth for product scope is `PRD.md` in this same folder; this file governs *how* we build it.

---

## Project Overview

ContractIQ is an AI-native contract lifecycle workspace for lean in-house legal teams (2-5 lawyers) at mid-market companies. It replaces manual drafting, email-based redline tracking, manual term extraction, and missed obligation deadlines with one connected pipeline:

**draft → redline → extract hotspots → insert to database → track obligations**

Six core use cases (see `PRD.md` for full user stories and Definitions of Done):
1. Draft a new contract from the clause library
2. Ingest and diff a counterparty redline
3. Compare a counterparty ask against fallback position history
4. Extract hotspots at contract execution
5. Search the contract database
6. Receive and act on obligation/deadline alerts

This is a legal-adjacent product handling sensitive, high-stakes documents. Every design and code decision should default to caution over cleverness — a wrong answer here has real financial and legal consequences for the end customer.

---

## Folder Structure

Target structure for the codebase (scaffold as work begins; update this section as the real layout diverges):

```
/
├── CLAUDE.md                 # this file
├── PRD.md                    # product requirements, source of truth for scope
├── docs/                     # supporting specs, evaluation reports, ADRs
├── src/
│   ├── drafting/              # UC1 — clause library, draft generation
│   ├── redline/                # UC2, UC3 — diff engine, fallback comparison
│   ├── extraction/             # UC4 — hotspot detection, term extraction
│   ├── database/               # UC5 — contract repository, search/query
│   ├── obligations/            # UC6 — deadline tracking, alerting
│   └── shared/                  # shared schemas, types, clients (see Extraction Schema)
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/                # sample contracts for testing (synthetic only — see Legal Accuracy Rules)
└── config/
    └── risk_thresholds/          # per-company configurable hotspot thresholds
```

Each pipeline module (`drafting/`, `redline/`, `extraction/`, `database/`, `obligations/`) should be independently testable and should not reach into another module's internals directly — communicate through the shared schema defined below.

---

## Contract Types Supported (v1)

| Type | Definition | Notes |
|---|---|---|
| NDA | Non-Disclosure Agreement | Confidentiality-focused; extraction schema fields around survival period apply most heavily here. |
| MSA | Master Service Agreement | Core commercial terms — payment, liability, term/renewal — apply in full. |
| SOW | Statement of Work | Typically nested under an MSA; scope, deliverables, and payment schedule are primary. |
| DPA | Data Processing Agreement | Data-handling terms (processing purpose, categories, sub-processors) apply in addition to standard commercial fields. |

Anything outside these four types is out of scope for v1 (see `PRD.md` Out of Scope section — no litigation documents, no jurisdiction-specific legal advice, no contract types beyond these four without a scope update to this file and the PRD).

---

## Legal Accuracy Rules

These rules are non-negotiable and apply to every drafting, redline, and extraction code path. Any change to logic touching these rules requires legal sign-off before merge, not just engineering review.

1. **Never fabricate contract clauses or terms.** If the system cannot find a clause or value in the source document, it does not invent one — see rule 2.
2. **If a field is absent from the source document, output `null`.** Never substitute a default, a guess, or a "typical" value. A `null` is a correct, honest output; a fabricated value is not.
3. **Always cite paragraph/section number for any extracted term.** Every non-null extracted field must carry a source citation (e.g. `"Section 4.2"` or `"¶12"`). An extraction without a citation is not shippable.
4. **Flag ambiguous language instead of interpreting it.** If a clause is genuinely ambiguous (e.g. conflicting termination language, an undefined term used inconsistently), surface it as a flagged item for human review rather than resolving it silently. The system does not make judgment calls on legal ambiguity.

These four rules take precedence over any accuracy/completeness metric target — a `null` with a flag beats a plausible-sounding fabrication every time.

---

## Extraction Schema (22 fields)

Every executed contract is parsed into this schema before insertion into the database (UC4 → UC5). Fields not applicable to a given contract type, or not present in the source document, are `null` — per Legal Accuracy Rule 2. Every non-null field requires a citation per Rule 3.

| # | Field | Description | Primarily applies to |
|---|---|---|---|
| 1 | `contract_type` | NDA / MSA / SOW / DPA | All |
| 2 | `counterparty_name` | Legal name of the counterparty | All |
| 3 | `effective_date` | Date the contract becomes effective | All |
| 4 | `execution_date` | Date the contract was signed | All |
| 5 | `term_length` | Duration of the initial term | MSA, SOW, DPA |
| 6 | `termination_notice_period` | Notice required to terminate | MSA, DPA |
| 7 | `auto_renewal_flag` | Whether the contract auto-renews (boolean) | MSA, DPA |
| 8 | `renewal_notice_deadline` | Deadline by which renewal notice must be given | MSA, DPA |
| 9 | `payment_amount` | Contract value or rate | MSA, SOW |
| 10 | `payment_frequency` | e.g. monthly, quarterly, one-time | MSA, SOW |
| 11 | `payment_terms` | e.g. net-30, net-60 | MSA, SOW |
| 12 | `late_payment_penalty` | Penalty or interest for late payment | MSA, SOW |
| 13 | `limitation_of_liability_cap` | Liability cap amount or formula | MSA, DPA |
| 14 | `indemnification_clause_present` | Whether an indemnification clause exists (boolean) | MSA, DPA |
| 15 | `confidentiality_survival_period` | How long confidentiality obligations survive termination | NDA, MSA |
| 16 | `governing_law` | Governing law jurisdiction named in the contract | All |
| 17 | `jurisdiction` | Venue for disputes | All |
| 18 | `dispute_resolution_mechanism` | Arbitration, litigation, mediation | All |
| 19 | `sla_commitments` | Uptime %, response time, or other service levels | MSA, SOW |
| 20 | `sla_credit_remedy` | Remedy owed if SLA is missed (e.g. service credit) | MSA, SOW |
| 21 | `data_processing_terms` | Data categories, processing purpose, sub-processor terms | DPA |
| 22 | `assignment_clause_terms` | Whether/how the contract can be assigned to a third party | All |

`[NEED: legal team sign-off on final field list and per-field extraction confidence thresholds before this schema is locked for v1]`

---

## Redline Rules

1. Every incoming counterparty document is diffed against the canonical version — never against the previous redline round. Drift between rounds must not compound undetected.
2. The redline engine flags ambiguous or unclear changes for human review rather than auto-categorizing them as accepted/rejected (consistent with Legal Accuracy Rule 4).
3. No redline is auto-sent to a counterparty without explicit lawyer sign-off — there is no fully autonomous negotiation path in v1.
4. Every diffed change must cite its location in both the canonical and incoming document (consistent with Legal Accuracy Rule 3).
5. Full version history is retained for every contract — no version is ever overwritten or deleted, only superseded.
6. Fallback-position suggestions (UC3) are surfaced as suggestions only; the system never auto-inserts a fallback clause without lawyer action.

---

## Output Format Standards

- **Dates:** ISO 8601 (`YYYY-MM-DD`). No ambiguous formats (no `MM/DD/YYYY`).
- **Currency:** ISO 4217 currency code plus numeric amount (e.g. `{"currency": "USD", "amount": 50000}`), never a bare formatted string.
- **Citations:** consistent format `"Section X.Y"` or `"¶N"` depending on the source document's own numbering — mirror the source, don't impose a different scheme.
- **Null representation:** literal `null`, never an empty string, `"N/A"`, or `0` used to mean absent.
- **Extraction output:** structured JSON matching the 22-field schema above, one object per contract, every non-null field paired with a `citation` key.
- **Drafts:** `.docx`, clauses tagged with a `risk_level` and `source` (which playbook clause they came from).
- **Flags (ambiguous language, hotspots):** always include the flag type, the source citation, and a human-readable reason — never a bare boolean.

---

## PDF Handling

**Any PDF attached or referenced in this workspace must be chunked before reading.** Do not read a PDF directly or load it whole into context. Instead:

1. Run `contracts/chunker.sh <pdf> <output_dir>` (1-page text chunks with paragraph overlap at boundaries; optional third arg overrides pages per chunk).
2. Read the resulting `chunk_NN.txt` files sequentially, processing per chunk.
3. Text under `[OVERLAP FROM PREVIOUS CHUNK]` was already processed — use it only for clauses split across a boundary; do not double-extract.
4. Exit code `2` means no text layer (scanned PDF): stop and flag for OCR/manual review — never proceed with empty chunks (see Coding Conventions: never silently swallow parsing failures).

---

## Coding Conventions

Tech stack is not yet finalized (see `PRD.md` open questions — build vs. buy on redline diffing engine). The conventions below are stack-agnostic and apply regardless of what's chosen.

- **Never silently swallow extraction or parsing failures.** If a document can't be parsed (e.g. scanned PDF with no text layer), fail loudly and flag for manual review — do not return partial or best-guess output without marking it as such.
- **No hardcoded legal defaults.** Risk thresholds (liability cap minimums, payment term limits, etc.) are configuration per company, never hardcoded constants (see `config/risk_thresholds/`).
- **Every function touching extraction, redline diffing, or hotspot detection needs a docstring/comment stating which Legal Accuracy Rule(s) it upholds.**
- **Test fixtures must be synthetic.** Never commit real customer contracts as test data, even anonymized — construct representative synthetic examples instead.
- **PRs touching `extraction/`, `redline/`, or `drafting/` require a citation-coverage check** — any extracted field without a citation should fail CI, not just review.
- **Naming:** snake_case for schema fields and API payloads (matches the Extraction Schema above), consistent with whatever language-level convention the chosen stack uses elsewhere.
- **Commit messages:** reference the use case they implement (e.g. `UC4: add liability cap threshold check`) so changes are traceable back to `PRD.md`.
- **Audit trail:** any action that modifies a contract record (redline accepted, hotspot dismissed, obligation marked resolved) must be logged with who/what/when — this is a compliance requirement, not optional logging.

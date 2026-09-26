---
name: contractiq
description: >
  ContractIQ is an AI-native contract lifecycle workspace for lean in-house legal teams.
  It replaces manual drafting, email-based redline tracking, manual term extraction, and
  missed obligation deadlines with one connected pipeline: draft → redline → extract
  hotspots → insert to database → track obligations. Trigger this skill when a user wants
  an overview of the ContractIQ pipeline, wants to know which command to run for a given
  contract task, or asks "how do I draft/redline/extract/track a contract in this repo."
  This skill documents the six use-case commands; it does not itself draft, redline,
  extract, or track — it points to the script/agent that does.
---

## Purpose

ContractIQ exists so a 2–5 lawyer in-house team can run a whole contract's lifecycle —
from first draft to renewal alert — through one connected pipeline instead of scattered
email threads, redline copies, and spreadsheets:

```
draft → redline → extract hotspots → insert to database → track obligations
```

Every command below implements exactly one of the six core use cases (UC1–UC6) defined in
`PRD.md`. The full legal-accuracy rules, output-format standards, and folder structure that
govern all six live in `CLAUDE.md` at the repo root — read that first if you're modifying
any command's underlying logic, since every script below cites the specific rule it upholds
(never fabricate a clause, absent field → `null`, every extracted value needs a citation,
ambiguous language gets flagged not resolved).

Contract types supported in v1: **NDA, MSA, SOW, DPA** — see `CLAUDE.md` for scope notes.

---

## The Six Commands

| # | Use Case | Command | Underlying script/agent |
|---|---|---|---|
| 1 | Draft a new contract | `/draft-nda`, `/draft-msa`, `/draft-sow` | `drafting/draft_nda.sh`, `drafting/draft_msa.sh`, `drafting/draft_sow.sh` |
| 2 | Redline a counterparty draft against playbook | `redlining/redline.sh` | same script also covers UC3 (prototype) |
| 3 | Compare counterparty ask against fallback positions | `redlining/redline.sh` | driven by `redlining/playbooks/*.md` |
| 4 | Extract hotspots at execution | `extraction/extract.sh`, `extraction/parallel_extract.sh` | `.claude/agents/contract-extractor.md` |
| 5 | Insert to database / build searchable portfolio | `extraction/merge_portfolio.sh`, `extraction/insert_hotspots.sh` | Notion MCP (Contract Intelligence DB) |
| 6 | Track obligations & renewal deadlines | `obligations/check_deadlines.sh` | reads `extraction/output/*.json` |

---

### 1 — Draft a new contract (UC1)

**Slash commands:** `/draft-nda`, `/draft-msa`, `/draft-sow`
**Scripts:** `drafting/draft_nda.sh`, `drafting/draft_msa.sh`, `drafting/draft_sow.sh`

Interactively collects the required deal terms, validates them (no empty/placeholder
values), then generates a first-pass draft via the `claude` CLI. Nothing produced here is
final or auto-sent to a counterparty (`CLAUDE.md` Redline Rule 3).

**Inputs**

| Command | Required fields |
|---|---|
| `/draft-nda` | party-a, party-b, jurisdiction, term, mutual (yes/no) |
| `/draft-msa` | services, payment terms, IP ownership, liability cap, warranty disclaimers, governing law |
| `/draft-sow` | project scope, deliverables, milestones with dates, acceptance criteria, change order process |

**Output:** `drafting/output/<YYYY-MM-DD>_<TYPE>_<party-a-slug>_<party-b-slug>.md`

**Example**

```
/draft-nda
> Party A: Acme Corp
> Party B: Beta Ventures LLC
> Jurisdiction: Delaware
> Term: 2 years
> Mutual or one-way? Mutual
```
→ writes `drafting/output/2026-09-26_NDA_acme_corp_beta_ventures_llc.md`

Direct script call (non-interactive):
```bash
./drafting/draft_nda.sh --party-a "Acme Corp" --party-b "Beta Ventures LLC" \
  --jurisdiction "Delaware" --term "2 years" --mutual yes
```

---

### 2 — Redline a counterparty draft (UC2)

**Script:** `redlining/redline.sh`

Diffs an incoming counterparty contract against the **canonical version** (never against
the previous redline round — `CLAUDE.md` Redline Rule 1) using a firm playbook. Produces a
clause-by-clause markdown table: standard position, counterparty position (cited), whether
it deviates, risk level, and a recommended response. This is a fast prototype for lawyer
review — it does not write a structured diff to the database and nothing is auto-sent to
the counterparty (Redline Rules 3, 6).

**Inputs**
- `--incoming FILE` — the counterparty's contract (markdown/text), required
- `--playbook FILE` — firm playbook, e.g. `redlining/playbooks/msa_playbook.md`, required
- `--stdout` — optional, also prints the report to stdout

**Output:** `redlining/output/<YYYY-MM-DD>_redline_report_<incoming-slug>.md`

**Example**

```bash
./redlining/redline.sh \
  --incoming tests/fixtures/synthetic_counterparty_msa.md \
  --playbook redlining/playbooks/msa_playbook.md \
  --stdout
```
→ writes `redlining/output/2026-09-26_redline_report_synthetic_counterparty_msa.md`

---

### 3 — Compare against fallback positions (UC3)

**Script:** `redlining/redline.sh` (same script as UC2 — the playbook already encodes each
clause's opening position, fallback range, and floor, so the risk-level and recommended-
response columns in the report *are* the fallback comparison)

Every playbook clause carries a fallback range and a floor. The report's "Risk Level"
column classifies the counterparty's ask against that range (at/beyond floor = HIGH, within
fallback but off opening position = MED, matches opening position = LOW), and "Recommended
Response" is grounded in the same fallback/floor data. This is decision support only — the
system never auto-inserts a fallback clause (Redline Rule 6).

**Inputs / Outputs:** identical to UC2 above — the playbook file is the source of the
fallback positions.

**Example**

```bash
./redlining/redline.sh \
  --incoming tests/fixtures/synthetic_counterparty_nda.md \
  --playbook redlining/playbooks/nda_playbook.md
```
→ the resulting report's Risk Level / Recommended Response columns are the UC3 output —
e.g. "MED: within fallback range but below opening position; counter at playbook opening."

---

### 4 — Extract hotspots at execution (UC4)

**Scripts:** `extraction/extract.sh` (single file), `extraction/parallel_extract.sh` (batch)
**Agent:** `.claude/agents/contract-extractor.md`

Parses an executed contract into the 22-field hotspot schema defined in `CLAUDE.md`. Every
non-null field carries a citation; absent fields are `null`; ambiguous language is flagged,
never resolved (Legal Accuracy Rules 1–4). PDFs must be chunked first via
`contracts/chunker.sh` — both scripts refuse raw `.pdf` input.

**Inputs**
- `extraction/extract.sh <contract_file>` — one `.txt` contract
- `extraction/parallel_extract.sh [max_parallel_jobs]` — every `.txt` in `extraction/input/`, default 4 parallel jobs

**Output:** `extraction/output/<contract_stem>_extracted.json` — one JSON object with all
22 schema keys, each `{value, citation, flag}`. Unreadable/scanned PDFs produce
`{"error": "no_text_layer", "reason": "..."}` instead of the schema.

**Example**

```bash
# Single contract
./extraction/extract.sh extraction/input/acme_msa_executed.txt
# → extraction/output/acme_msa_executed_extracted.json

# Batch, 4-way parallel
./extraction/parallel_extract.sh 4
# → one *_extracted.json per file in extraction/input/, failures logged to
#   extraction/output/.logs/<stem>.log without blocking the rest of the batch
```

---

### 5 — Insert to database / search the portfolio (UC5)

**Scripts:** `extraction/merge_portfolio.sh`, `extraction/insert_hotspots.sh`

Two complementary steps: `merge_portfolio.sh` folds every completed `*_extracted.json` into
one searchable `master_portfolio.json` (adding `contract_id`, `source_filename`,
`extraction_timestamp`, `field_null_count` — never altering an extracted value, so it can't
introduce a fabrication that wasn't already in the source extraction). `insert_hotspots.sh`
upserts a single extraction into the Notion "Contract Intelligence" database, keyed on
contract name, preserving citations and flags for audit.

**Inputs**
- `extraction/merge_portfolio.sh` — no args; reads every `extraction/output/*_extracted.json`
- `extraction/insert_hotspots.sh <json_file_path> [notion_database_id]` — one extracted JSON file

**Output**
- `extraction/output/master_portfolio.json` — merged, searchable array (failed/error
  extractions are skipped and reported, never silently folded in)
- Notion database record (create or update) with a returned page URL

**Example**

```bash
./extraction/merge_portfolio.sh
# → "Merged 12 contract(s) into extraction/output/master_portfolio.json (0 skipped)"

./extraction/insert_hotspots.sh extraction/output/acme_msa_executed_extracted.json
# → prompt saved for Notion MCP insert/update; run `claude < <prompt file>` to execute
```

---

### 6 — Track obligations & renewal deadlines (UC6)

**Script:** `obligations/check_deadlines.sh`

Scans every `extraction/output/*.json` file, derives each contract's renewal notice
deadline (from an explicit `renewal_notice_deadline`, or calculated from
`effective_date` + `term_length` − `termination_notice_period`), and flags anything due
within a lookahead window with a risk level: 🔴 CRITICAL (≤14 days), 🟠 URGENT (15–30 days),
🟡 WARNING (31–90 days).

**Inputs**
- `--days N` — lookahead window, default 90
- `--output FORMAT` — `json` (default), `markdown`, or `slack`

**Output:** JSON array (or markdown table / Slack-ready JSON) to stdout — one object per
at-risk contract: `counterparty`, `contract_type`, `renewal_notice_deadline`,
`days_until_deadline`, `risk_level`, `auto_renewal`, `action` (`REVIEW_REQUIRED` or `TRACK`).

**Example**

```bash
./obligations/check_deadlines.sh --days 90 --output markdown
```
```
# Renewal Deadlines (Next 90 Days)

| Counterparty | Type | Deadline | Days Left | Risk | Auto-Renew? |
|---|---|---|---|---|---|
| Acme Corp | MSA | 2026-10-15 | 19 | URGENT | true |
```

---

## Notes for anyone extending these commands

- Every field/rule referenced above traces back to `CLAUDE.md` — if you change extraction
  schema fields, output formats, or redline rules, update `CLAUDE.md` first; it is the
  source of truth, and the `contract-extractor` agent explicitly defers to it.
- PRs touching `extraction/`, `redline/`, or `drafting/` require a citation-coverage check
  in CI — an extracted field without a citation should fail the build, not just review.
- Test fixtures are synthetic only (`tests/fixtures/synthetic_*`) — never commit a real
  customer contract, anonymized or not.

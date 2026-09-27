# ContractIQ — Security Policy

Companion to `security_audit.md` (what Claude is *permitted* to touch, tool by
tool) and `obligations/audit/access_log.jsonl` (what Claude *actually*
touched, produced by `.claude/hooks/audit_log.sh`). This document is the
policy layer above both: what data exists and how sensitive it is, who is
allowed to invoke which command, how long each artifact is kept, and what to
do if Claude accesses something it shouldn't have.

Anything in this file marked `[NEED: ...]` is a real open question requiring
legal/compliance sign-off, not a placeholder to be filled in with a
plausible-sounding guess — consistent with `CLAUDE.md`'s Legal Accuracy
Rules (never fabricate, `null`/flag over guessing).

---

## 1. Data Classification Tiers

Two tiers. The dividing line is **blast radius**: CONFIDENTIAL data
disadvantages one deal or one document if leaked; RESTRICTED data
disadvantages the whole portfolio, creates regulatory exposure, or exposes
credentials.

### CONFIDENTIAL

Internal business information, contained to a single document or deal.
Disclosure is a problem, but a bounded one.

| Data | Where it lives |
|---|---|
| In-progress drafts, pre-execution | `drafting/output/*.md` |
| Redline comparison reports | `redlining/output/*.md` |
| Single-contract extraction results | `extraction/output/<stem>_extracted.json` |
| Clause template library | `drafting/templates/*.md` |
| Deadline alert payloads | `obligations/output/deadline_alerts_*.json` |
| Chunked PDF text (pre-extraction working copy) | `contracts/chunks/**` |

### RESTRICTED

Exposure causes portfolio-wide, financial, regulatory, or credential harm —
not contained to one document.

| Data | Where it lives | Why RESTRICTED, not CONFIDENTIAL |
|---|---|---|
| Executed contracts (raw source) | `extraction/input/*.txt`, any PDF passed to `contracts/chunker.sh` | Full unredacted legal document — signature blocks, counterparty legal names, and (for DPAs) personal data categories. |
| Negotiation playbooks | `redlining/playbooks/*.md` | Contains the firm's fallback ranges and negotiating floors. A leak damages leverage on *every future deal*, not just the one being redlined — this is why `security_audit.md` §7 already treats playbook access as a sensitive read path. |
| Merged portfolio file | `extraction/output/master_portfolio.json` | Aggregates every counterparty's financial and legal terms (payment amounts, liability caps, term/renewal dates) into one file. A single-file compromise here is a portfolio-wide compromise. |
| DPA data-processing terms | `data_processing_terms` field (extraction schema #21) | May name categories of personal data and sub-processors — potential GDPR/CCPA regulatory exposure, distinct from ordinary commercial terms. |
| Credentials / secrets | `.claude/settings.local.json` (permission grants), any `.env*`, Slack/Notion tokens, `ANTHROPIC_API_KEY` if exported | Not contract data, but co-located in the repo and covered by the same access controls (see `.claude/settings.json` `permissions.deny` patterns for `.env*`, `*.pem`, `*credentials*`, etc.). |
| Compliance audit log | `obligations/audit/access_log.jsonl` | Records every tool call Claude makes, including file paths — a record of *what was accessed* is itself sensitive (tampering with it would blind incident response, see §4). |

**Not classified data (synthetic only):** `tests/fixtures/**` — per `CLAUDE.md`
Coding Conventions, test fixtures must be synthetic, never real customer
contracts even anonymized. Synthetic fixtures carry no classification.

---

## 2. Role Mapping — Who Can Run Which Command

Claude Code's permission system (`settings.json` / `settings.local.json`)
scopes **what a command can technically touch** (which files, which scripts)
— it has no concept of *which human* is allowed to type that command. The
table below is the organizational control that sits on top of the technical
one; it is enforced by process (who has a seat at the firm, who is handed
the repo), not by a config file.

| Command | Touches | Minimum role | Why |
|---|---|---|---|
| `/draft-nda`, `/draft-msa`, `/draft-sow` | `drafting/templates/**` (read), `drafting/output/**` (write) — CONFIDENTIAL | Licensed attorney, or paralegal drafting **under** attorney review | Output is explicitly a first-pass draft (each command's Step 4 says so), but the inputs collected — liability caps, IP ownership, warranty disclaimers — require legal judgment to set correctly even in draft form. |
| `/redline-contract` | `redlining/playbooks/**` (RESTRICTED, read), incoming counterparty file, `redlining/output/**` (write) | Licensed attorney only | Reads the firm's negotiating floor/fallback positions (RESTRICTED) and produces a negotiating stance recommendation. Per `CLAUDE.md` Redline Rule 3, no redline is ever sent without lawyer sign-off — the same judgment threshold should gate who can even *run* the comparison, not just who approves sending it. |
| `/extract-contract` | `extraction/input/**` (RESTRICTED, read), `extraction/output/**` (write) | Attorney or designated contracts-ops/paralegal | Mechanical term extraction from an already-executed contract — lower legal-judgment requirement than drafting or redlining, but still touches RESTRICTED source documents, so requires a named, need-to-know assignment, not open access. |
| `/check-renewals` | `extraction/output/master_portfolio.json` (RESTRICTED, read-only), posts via Slack MCP | Attorney, paralegal, or an authorized business stakeholder who owns the renewal decision (e.g. procurement/finance) | Read-only reporting off already-extracted data; this is the one command whose audience should be *broader* than "attorney only," since its job is alerting whoever needs to act on a deadline — but it still only reads RESTRICTED data, never writes or edits it. |
| CI (`claude -p` in `.github/workflows/*.yml`) | Whatever `--allowedTools` grants it (see `security_audit.md` §8) | Not a human role — a separate trust boundary. Runs with `ANTHROPIC_API_KEY`/`GH_TOKEN` from repo secrets, with `.claude/settings.json` explicitly disabled for the run. | Anyone who can merge a workflow-file change controls what CI's `claude -p` calls are allowed to touch — treat workflow-file PRs touching `.github/workflows/` with the same review bar as a permissions change, not as routine code. |

**Enforcement gap, stated plainly:** nothing today stops an unauthorized
person who has repo access from typing `/redline-contract` themselves — the
`allowed-tools` frontmatter on each command scopes the *tool surface*, not
the *invoker*. `[NEED: decide whether role enforcement should live outside
Claude Code entirely — e.g. repo-level access control (who gets a seat in
this repo at all) — or whether a future PreToolUse hook should check an
identity signal before allowing `/redline-contract` and `/draft-*` to run.]`

---

## 3. Data Retention Policy

### Regenerable / scratch output (CONFIDENTIAL tier, gitignored)

`drafting/output/`, `redlining/output/`, `extraction/output/`,
`obligations/output/`, `contracts/chunks/` are all gitignored — per the
`.gitignore` comments, "regenerable, never commit." These are working
copies, not the system of record. Retention: delete freely once superseded
or once the pipeline step that follows them has run (e.g. a chunk directory
can be deleted once its extraction JSON exists) — there is no obligation to
keep scratch output, and keeping it longer than necessary only expands the
CONFIDENTIAL-tier footprint on disk for no benefit.

### System of record (RESTRICTED tier)

The eventual home for executed-contract data is the Notion "Contract
Intelligence" database targeted by `extraction/insert_hotspots.sh`
(`NOTION_DATABASE_ID` constant in that script). `CLAUDE.md` Redline Rule 5
already states the retention principle for this store: **"Full version
history is retained for every contract — no version is ever overwritten or
deleted, only superseded."** This policy extends that same rule to the
retention *duration*, not just the versioning behavior:

- Executed contracts and their extracted terms are retained for the life of
  the contractual relationship, plus a post-termination window.
  `[NEED: legal team to set the post-termination retention window —
  typically driven by the applicable statute of limitations for contract
  claims in the governing-law jurisdiction (extraction schema field #16),
  which varies by jurisdiction and contract type and should not be
  hardcoded as one number across the whole portfolio.]`
- No automated deletion job exists or should be built against this store
  without that sign-off — silently expiring a contract record early is a
  legal-accuracy failure of the same kind `CLAUDE.md` already prohibits for
  fabricated values (a missing record you can no longer produce on request
  is as bad as a wrong one).

### Compliance audit log (`obligations/audit/access_log.jsonl`)

Append-only by construction (`.claude/hooks/audit_log.sh` only ever appends,
never truncates or rewrites the file). Retention: keep for at least as long
as the longest-retained contract record it could need to help investigate
— practically, this means the audit log should never be pruned on a
shorter cycle than the contract data retention window above.
`[NEED: legal/compliance to confirm a minimum retention period — 1 year is
a common baseline for access logs but has not been confirmed for this
repo.]`

### Credentials / secrets

Not retained on a schedule — rotated. `[NEED: set a rotation cadence for
the Slack/Notion MCP tokens and `ANTHROPIC_API_KEY`; none is defined today.]`
In the meantime, `.claude/settings.json`'s `permissions.deny` list already
blocks `Read`/reads of `.env*`, `*.pem`, `*credentials*`, etc., and blocks
`Write`/`Edit` on `.claude/settings.json` and `.claude/settings.local.json`
themselves, so Claude cannot read or silently escalate its own credential
grants.

---

## 4. Incident Response — Claude Accessed the Wrong File

Steps to follow the moment a wrong-file access is discovered (via user
observation, an unexpected value appearing in output, or a manual review of
the audit log). Do not silently patch and move on — every incident gets a
written record, the same "never silently swallow a failure" standard
`CLAUDE.md` already sets for extraction/parsing errors.

1. **Stop the session.** Do not let the current session continue running or
   issue further tool calls until the scope of the access is understood.
   If the wrong-file content already fed a downstream action — a draft, a
   Slack post, a Notion write — pause that artifact next: don't let a draft
   go to a counterparty, and if a message already posted via
   `mcp__claude_ai_Slack__slack_send_message`, address it in the same
   channel rather than leaving it unacknowledged.

2. **Reconstruct the timeline.** Every tool call in the session is already
   recorded in `obligations/audit/access_log.jsonl` with
   `timestamp`, `user`, `tool_name`, `file_path_or_mcp_endpoint`,
   `action_type`, and `session_id`. Filter that file for the `session_id` in
   question to get an ordered, complete list of what was touched and when
   — this is exactly what the hook was built for (see `audit_log.sh`'s own
   header comment: "no standing record of what Claude actually accessed").

3. **Classify what was touched.** Look up the accessed file/path against
   §1 above. RESTRICTED-tier access (an executed contract, a playbook, the
   master portfolio file, or anything containing DPA personal-data terms)
   is a materially different severity than a CONFIDENTIAL-tier scratch
   file, and may carry its own notification obligation — see step 5.

4. **Identify the control that should have caught it.** Check whether the
   access should have been blocked by an existing control and wasn't:
   - `permissions.blockReadsOutsideWorkingDirectories` (should block any
     read outside the repo root, in every mode)
   - a `permissions.deny` pattern (should block credential/secret paths
     regardless of what else grants access — deny always wins over allow,
     confirmed against Claude Code's rule evaluation order)
   - a command's own `allowed-tools` frontmatter scoping
   - `freshness_check.sh` / `pre_redline.sh` / `validate_input.sh` (the
     existing Bash/Read-scoped hooks)
   If none of these should have caught it (a genuinely new gap), that gap
   is the finding to fix in step 6.

5. **Notify.** Internally: the lawyer who owns the session, plus a
   designated security contact. Externally: if RESTRICTED data belonging
   to a specific counterparty reached an unintended recipient (wrong Slack
   channel, wrong draft recipient), check that counterparty's own contract
   for a breach-notification clause before assuming a deadline —
   `dispute_resolution_mechanism` and the contract's own notice provisions
   (not a generic policy default) govern here. `[NEED: legal team to
   confirm whether a wrong-file-access incident involving a DPA
   counterparty's data triggers a regulatory notification obligation
   (e.g. GDPR Article 33) separate from the counterparty notice above —
   this depends on facts of the specific incident and should not be
   pre-answered generically.]`

6. **Remediate the control gap**, not just the symptom: add or tighten the
   specific `permissions.deny` pattern, hook check, or command scoping that
   would have prevented this exact access. Prefer the narrowest fix that
   closes the actual gap over a broad new restriction that blocks
   legitimate work.

7. **Verify the fix** by reproducing the same steps (or a safe dry-run of
   them) and confirming the access is now blocked or correctly scoped
   before resuming normal use of the affected command.

8. **Write it down.** Record what happened, what was accessed, its
   classification tier, what allowed it, what changed, and who verified the
   fix — a short dated entry is sufficient, but it must exist. This is the
   same audit-trail requirement `CLAUDE.md` already imposes on redline
   acceptance, hotspot dismissal, and obligation resolution, applied here
   to security incidents themselves.

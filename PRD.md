# ContractIQ — Product Requirements Document

**Author:** Sahil Aggarwal
**Date:** 2026-07-29

---

## Product Vision

ContractIQ replaces the disconnected, manual contract workflow — blank-page drafting, redlines tracked over email, manual re-reading of signed PDFs, and deadlines discovered too late — with a single connected pipeline: **draft → redline → extract hotspots → insert to database → track obligations**. It gives lean in-house legal teams (2-5 lawyers) at mid-market SaaS companies the leverage of a much larger team by automating the four biggest time sinks in the contract lifecycle, without requiring the headcount or implementation timeline of a full enterprise CLM.

---

## Use Cases

### UC1: Draft a new contract from the clause library

**User story:** As an in-house counsel, I want to generate a first draft of an NDA/MSA/SOW from our governed clause library by specifying deal type and counterparty, so that I don't start from a blank page or hunt through old Word docs.

**Inputs:** Contract type (NDA/MSA/SOW), counterparty name, deal parameters (value, term length, key business terms), applicable clause library/playbook version.

**Outputs:** Draft contract document (.docx) with clauses tagged by risk/negotiability level, ready to send to counterparty.

**Definition of done:** Draft generated in under 2 minutes. Every clause traceable to a playbook source. Lawyer can approve or edit before send with zero manual retyping of boilerplate.

---

### UC2: Ingest and diff a counterparty redline

**User story:** As an in-house counsel, I want incoming counterparty redlines (received as email attachments or shared links) automatically diffed against our canonical version, so that I don't have to manually compare "v3_FINAL_v2.docx" against our original.

**Inputs:** Counterparty-returned document (.docx/PDF via email or upload), canonical version reference.

**Outputs:** Structured diff view showing added, removed, and modified clauses, mapped to canonical document sections.

**Definition of done:** 100% of substantive text changes detected (no silent misses). Diff available within 5 minutes of document receipt. False-diff rate (flagging unchanged text as changed) under 5%.

---

### UC3: Compare a counterparty ask against fallback position history

**User story:** As an in-house counsel, I want to see how we've handled a similar clause ask in past negotiations, so that I can respond with our established fallback position instead of re-litigating it from scratch.

**Inputs:** The specific clause/redline in question, historical negotiated contract database.

**Outputs:** Ranked list of past instances of this or a similar clause type, with what was ultimately accepted and how often.

**Definition of done:** For any clause type with 3+ historical instances, the system surfaces at least one comparable precedent. Lawyer can accept or reject the suggested fallback in one click.

---

### UC4: Extract hotspots at contract execution

**User story:** As an in-house counsel, I want the system to automatically flag missing standard protections and risk-threshold terms the moment a contract is executed, so that risk exposure doesn't go unnoticed until a dispute.

**Inputs:** Fully executed contract document, company-configured risk thresholds and required-protections list.

**Outputs:** Hotspot report listing (a) missing standard protections and (b) terms outside configured thresholds, each linked to its specific contract location.

**Definition of done:** Hotspot flagging precision >90% (confirmed real issue on lawyer review). Every flagged item links to the exact clause. Zero contracts execute without a hotspot pass completing.

---

### UC5: Search the contract database

**User story:** As an in-house counsel or legal ops lead, I want to search and filter across all executed contracts by extracted terms, so that I can answer questions like "show me every contract with net-60 payment terms" without opening files one by one.

**Inputs:** Search/filter query (term type, value range, date range, counterparty, contract type).

**Outputs:** Filtered list of matching contracts with the relevant extracted field highlighted, exportable as a table.

**Definition of done:** Every executed contract queryable within 24 hours of execution. Search returns results in under 3 seconds. Results are 100% traceable back to the source contract.

---

### UC6: Receive and act on an obligation/deadline alert

**User story:** As an in-house counsel, I want to be proactively notified ahead of renewal notice windows, SLA commitments, and other contractual deadlines, so that I never miss an obligation because no one was tracking it manually.

**Inputs:** Extracted obligation/deadline data per contract, configurable alert lead times (e.g. 60/30/14 days).

**Outputs:** Alert (email/in-app) naming the contract, the obligation, and the deadline; an obligation dashboard showing all upcoming items.

**Definition of done:** Zero missed deadlines during the pilot period. Every obligation with a date field generates at least one alert. Alerts are deliverable to a configurable owner, not just the original drafting lawyer.

---

## Out of Scope (v1)

- E-signature — integrates with DocuSign/Adobe Sign, does not replace them.
- Full enterprise CLM features: approval routing, vendor risk management, spend analytics.
- Open-ended "unusual language" hotspot detection — v1 is limited to missing-protection and risk-threshold rules only.
- Jurisdiction-specific legal advice — output is a drafting/tracking aid reviewed by licensed counsel, not legal advice.
- Law firm / solo practitioner use cases — buyer is in-house legal/legal ops at a single company.
- Litigation and dispute management workflows.

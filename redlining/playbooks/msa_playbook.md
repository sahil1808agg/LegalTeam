# MSA Negotiation Playbook

Firm standard positions for Master Service Agreement (MSA) redlines. This playbook drives UC2 (ingest and diff a counterparty redline) and UC3 (compare a counterparty ask against fallback position history) — see `PRD.md`. It is a decision aid for lawyers reviewing flagged clauses; it does not authorize any auto-inserted or auto-sent language (Redline Rules 3 and 6 in `CLAUDE.md`).

Each entry below defines: the firm's **opening (ideal) position**, the **fallback range** we can accept without escalation, the **floor** below which a clause must escalate to a senior attorney, and **redline signals** — language patterns in an incoming draft that should be flagged for review rather than silently auto-categorized (Redline Rule 2).

Risk thresholds referenced here (e.g. liability cap multiplier, audit notice period) are **defaults for this playbook only** — per-company overrides live in `config/risk_thresholds/`, never hardcoded into extraction or redline logic itself.

---

## 1. Liability Cap

- **Opening position:** Aggregate liability capped at 2x total fees paid or payable in the 12 months preceding the claim, mutual (applies equally to both parties). Carve-outs only for confidentiality breach, indemnification obligations, and gross negligence/willful misconduct.
- **Fallback range:** 1x–3x fees paid in the preceding 12 months. Below 1x requires escalation; above 3x should be pushed back but is not itself a blocker if other terms favor us.
- **Floor:** Never accept an uncapped liability clause, and never accept a cap denominated as a fixed dollar figure with no reference to fees actually paid (a fixed-dollar cap can decouple from deal size over time).
- **Redline signals:** cap applies to only one party (unilateral); cap carve-outs expanded beyond confidentiality/indemnification/gross negligence (e.g. broad "breach of any provision" carve-out that swallows the cap); cap measured against a lump sum or contract-life total instead of trailing-12-months fees.

## 2. Intellectual Property Ownership

- **Opening position:** Customer (Client) owns all work product, deliverables, and custom developments created under the Agreement, effective upon full payment. Provider retains ownership of pre-existing IP, background IP, and general methodologies/know-how, and grants Client a license to use any Provider background IP embedded in deliverables as needed to use the deliverables.
- **Fallback range:** Client ownership contingent on payment is acceptable to negotiate to "ownership upon delivery" (rather than full payment) if the counterparty pushes back, provided Provider retains a broad license-back for reuse of general components/methodologies that are not Client-specific.
- **Floor:** Never accept Provider retaining ownership of Client-specific custom deliverables; never accept an assignment clause without a corresponding license-back for Provider's pre-existing IP.
- **Redline signals:** "Provider owns all deliverables" or joint-ownership language; ownership triggered by an undefined or vague event; no carve-out preserving Provider's pre-existing/background IP; moral rights not waived where waivable.

## 3. Termination for Convenience

- **Opening position:** Either party may terminate for convenience upon 30 days' prior written notice, with Client obligated to pay for Services performed and non-cancelable costs incurred through the effective termination date.
- **Fallback range:** 30–60 days' notice. Asymmetric convenience-termination rights (e.g. only Client may terminate for convenience) are acceptable only if Provider is compensated for a minimum committed term or wind-down costs.
- **Floor:** Never accept a convenience-termination right shorter than 15 days, and never accept convenience termination with no payment obligation for work already performed or committed non-cancelable costs.
- **Redline signals:** immediate termination for convenience (0-day notice); termination right granted to only one party without compensating consideration; no carve-out preserving accrued payment obligations upon termination.

## 4. Governing Law

- **Opening position:** Delaware, without regard to conflict-of-laws principles; exclusive jurisdiction and venue in Delaware state or federal courts.
- **Fallback range:** New York or the State/jurisdiction where the Provider is headquartered. Acceptable to concede on venue (e.g. neutral venue) if governing law remains Delaware or another mutually-agreeable business-friendly jurisdiction.
- **Floor:** Escalate any request for the counterparty's home jurisdiction if that jurisdiction lacks well-developed commercial contract case law, or if the clause pairs unfavorable governing law with mandatory arbitration in a forum inconvenient to Provider.
- **Redline signals:** governing law and venue split across inconsistent jurisdictions within the same document; silent removal of "exclusive" jurisdiction language (opens door to parallel litigation); governing law tied to a jurisdiction not previously discussed in negotiation.

## 5. Indemnification

- **Opening position:** Mutual indemnification — each party indemnifies the other for third-party claims arising from its own breach, negligence, willful misconduct, or (for Provider) IP infringement claims regarding deliverables. Indemnification obligations are capped at the same multiplier as the general liability cap (Section 1), except IP infringement indemnification, which is uncapped.
- **Fallback range:** Cap on IP infringement indemnification acceptable at a higher multiplier (e.g. total contract value) if counterparty insists on a cap; general indemnification cap may float with the liability cap fallback range in Section 1.
- **Floor:** Never accept one-sided (unilateral) indemnification running only from Provider to Client; never accept indemnification with no cap on ordinary breach claims tied to the same cap structure as general liability.
- **Redline signals:** indemnification triggers expanded to include ordinary contract breach generally (not tied to specific enumerated triggers); defense obligation (duty to defend) added without corresponding control-of-defense rights; indemnification cap silently removed or carved out from the general liability cap section.

## 6. Audit Rights

- **Opening position:** Client may audit Provider's records relevant to fees charged and SLA compliance no more than once per 12-month period, upon 30 days' prior written notice, during normal business hours, at Client's expense unless the audit reveals a discrepancy exceeding 5% of fees paid, in which case Provider bears the audit cost.
- **Fallback range:** Audit frequency up to twice per 12-month period; notice period negotiable down to 15 days if counterparty requires shorter lead time for compliance reasons.
- **Floor:** Never accept unlimited audit frequency or on-demand/no-notice audit rights; never accept audit rights extending to Provider systems, data, or clients unrelated to the Agreement.
- **Redline signals:** audit right with no notice period or no frequency cap; audit scope expanded to "any records" rather than records relevant to fees/SLA; no confidentiality restriction on the auditor or audit findings.

## 7. Term and Renewal

- **Opening position:** Initial term of 12–24 months as negotiated, auto-renewing for successive 12-month terms unless either party gives written notice of non-renewal at least 60 days before the then-current term ends.
- **Fallback range:** Auto-renewal notice window of 30–90 days is acceptable; a fixed (non-auto-renewing) term with a separate renewal negotiation is acceptable if the counterparty prefers it.
- **Floor:** Never accept auto-renewal with a notice window shorter than 30 days, and never accept auto-renewal terms longer than the initial term without an explicit price re-negotiation right.
- **Redline signals:** renewal notice deadline silently shortened between drafting rounds (must be diffed against canonical, not prior redline, per Redline Rule 1); auto-renewal term length exceeds initial term; no mechanism for either party to adjust pricing at renewal.

## 8. Payment Terms

- **Opening position:** Net 30 from invoice date; invoices not disputed in good faith within 15 days of receipt are deemed accepted; late payments accrue interest at the lesser of 1.5%/month or the maximum rate permitted by law.
- **Fallback range:** Net 45 acceptable if counterparty has an established, low-risk payment history; interest rate on late payment negotiable down to statutory minimum but never waived entirely.
- **Floor:** Never accept payment terms beyond Net 60; never accept a clause that waives interest/penalties on late payment with no alternative remedy (e.g. suspension of services right).
- **Redline signals:** payment terms extended without a corresponding suspension-of-services right for non-payment; invoice dispute window removed (creates indefinite dispute exposure); late payment penalty deleted with no replacement remedy.

## 9. Limitation of Liability — Carve-Outs

- **Opening position:** Standard carve-outs from the liability cap limited to: confidentiality breach, indemnification obligations, and gross negligence/willful misconduct. No consequential/indirect damages for either party outside these carve-outs.
- **Fallback range:** Willing to add a carve-out for a party's payment obligations (i.e., the cap does not excuse Client from paying amounts actually owed) since this is not really a "liability" carve-out but a payment-obligation clarification.
- **Floor:** Never accept a carve-out list that includes "any breach of this Agreement" (this nullifies the cap entirely) or an open-ended "applicable law" carve-out without specifying which law.
- **Redline signals:** carve-out list expanded clause-by-clause across negotiation rounds (classic cap-erosion pattern — flag for review even if each individual addition looks reasonable in isolation).

## 10. Confidentiality Survival

- **Opening position:** Confidentiality obligations survive termination or expiration of the Agreement for 3 years, except for trade secrets, which survive for as long as the information retains trade secret status under applicable law.
- **Fallback range:** Survival period of 2–5 years for general confidential information is acceptable.
- **Floor:** Never accept a confidentiality survival period shorter than 1 year for general confidential information, and never accept language that caps trade secret protection to a fixed term (trade secret protection must track applicable law, not an arbitrary clock).
- **Redline signals:** survival period removed entirely (confidentiality obligations that terminate with the agreement); trade secret carve-out from the fixed survival term deleted; definition of "confidential information" narrowed in a way that would exclude information the parties clearly intend to protect (e.g. carve-out for "publicly known" information defined too broadly).

## 11. Assignment

- **Opening position:** Neither party may assign the Agreement without the other's prior written consent, except either party may assign without consent in connection with a merger, acquisition, or sale of all or substantially all of its assets.
- **Fallback range:** Consent requirement can be softened to "consent not to be unreasonably withheld" if counterparty requests more flexibility for internal reorganizations.
- **Floor:** Never accept unrestricted assignment rights for the counterparty with no consent mechanism, and never accept a one-sided assignment right that lets the counterparty assign freely while restricting Provider.
- **Redline signals:** assignment right granted asymmetrically favoring the counterparty; M&A carve-out removed (forces a consent negotiation mid-transaction, which is a deal risk); assignment permitted to a competitor of the other party without restriction.

## 12. Warranty Disclaimers

- **Opening position:** Services and deliverables provided "AS IS" beyond any warranties expressly stated in the Agreement; disclaims implied warranties of merchantability, fitness for a particular purpose, and non-infringement, subject to any express SLA commitments.
- **Fallback range:** Willing to add a limited express warranty that Services will be performed in a professional and workmanlike manner, consistent with industry standards, for a defined cure period.
- **Floor:** Never accept open-ended warranty language with no disclaimer of implied warranties at all; never accept warranty terms that are inconsistent with or contradict the SLA commitments elsewhere in the Agreement (flag as ambiguous per Legal Accuracy Rule 4 rather than resolving silently).
- **Redline signals:** disclaimer language deleted or narrowed without a corresponding express warranty added; warranty period left undefined ("Provider warrants the Services will perform as expected" with no duration or remedy).

## 13. Data Processing / Sub-processor Terms (where applicable)

- **Opening position:** Where the MSA scope includes data processing, Provider will process Client data only for the purposes described in the Agreement or an incorporated DPA, will not engage sub-processors without notifying Client, and Client may object to a new sub-processor on reasonable data-protection grounds.
- **Fallback range:** Notice-only regime (no consent right, notice + objection right) is acceptable in place of prior written consent for each sub-processor if counterparty needs operational flexibility.
- **Floor:** Never accept unrestricted sub-processing rights with no notice mechanism; if the MSA touches personal data processing without a DPA referenced or incorporated, escalate — this contract type gap should be flagged rather than resolved by inference (see `CLAUDE.md` Contract Types Supported).
- **Redline signals:** data processing terms present in an MSA with no reference to a companion DPA; sub-processor notice/objection mechanism silently removed; data processing purpose defined more broadly than the Services described in Section 2.

## 14. SLA Commitments and Credit Remedy

- **Opening position:** Where the engagement includes ongoing services with measurable performance (uptime, response time), SLA commitments are stated as specific, numeric targets, with a defined service-credit remedy as the sole and exclusive remedy for a missed SLA (except where the miss also constitutes a material breach entitling the aggrieved party to terminate).
- **Fallback range:** Service credit percentages and thresholds are negotiable case-by-case; acceptable to add a chronic-failure termination right (e.g. 3 consecutive missed months) as an escalation path beyond credits alone.
- **Floor:** Never accept SLA commitments stated in vague, non-numeric terms ("commercially reasonable uptime") with a credit remedy tied to it — an unmeasurable SLA is not enforceable and should be flagged, not accepted as boilerplate.
- **Redline signals:** SLA target present but credit remedy section deleted or left blank; "sole and exclusive remedy" language removed (reopens SLA misses to unbounded damages claims, interacts with Section 1 liability cap); SLA measurement methodology undefined or left to one party's sole discretion.

## 15. Dispute Resolution Mechanism

- **Opening position:** Litigation in the courts of the governing-law jurisdiction (Section 4), no mandatory arbitration, with a mutual waiver of jury trial where enforceable.
- **Fallback range:** Binding arbitration (e.g. AAA or JAMS commercial rules) in the governing-law jurisdiction is acceptable if the counterparty requires it, provided each party bears its own costs absent a fee-shifting prevailing-party clause negotiated separately.
- **Floor:** Never accept a dispute resolution clause that requires arbitration in a jurisdiction other than the agreed governing-law venue, and never accept a clause silent on whether arbitration is binding (ambiguous binding/non-binding language must be flagged per Legal Accuracy Rule 4, not assumed).
- **Redline signals:** dispute resolution venue inconsistent with the governing law clause (Section 4) — a classic drafting drift signal, especially significant if introduced between redline rounds; mediation/arbitration tiering added without clear escalation triggers or timelines; class action waiver added without assessing enforceability in the governing jurisdiction.

---

## Using This Playbook in the Redline Pipeline (UC2/UC3)

- Every clause identified as touching one of the 15 areas above must be diffed against the **canonical playbook position**, not against a prior negotiation round (Redline Rule 1) — drift compounds silently otherwise.
- A clause falling within the **fallback range** may be surfaced as auto-suggested acceptable but still requires lawyer sign-off before any redline is sent back to the counterparty (Redline Rule 3).
- A clause at or beyond the **floor** must be flagged for senior attorney escalation, not auto-rejected or auto-countered.
- Any redline signal listed above that appears in an incoming draft must be flagged for human review, with a citation to its location in the incoming document and (if applicable) the corresponding canonical section, per Legal Accuracy Rule 3 and Redline Rule 4.
- This playbook does not itself resolve ambiguous language — if a clause could plausibly fall into more than one category above, or the intent is unclear, flag it rather than guessing which position applies (Legal Accuracy Rule 4).

`[NEED: legal team sign-off on floor values above (liability cap floor, indemnification cap structure, audit frequency/notice) before this playbook is used to auto-suggest accept/reject dispositions in production.]`

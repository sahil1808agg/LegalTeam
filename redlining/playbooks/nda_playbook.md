# NDA Negotiation Playbook

Firm standard positions for Non-Disclosure Agreement (NDA) redlines. This playbook drives UC2 (ingest and diff a counterparty redline) and UC3 (compare a counterparty ask against fallback position history) — see `PRD.md`. It is a decision aid for lawyers reviewing flagged clauses; it does not authorize any auto-inserted or auto-sent language (Redline Rules 3 and 6 in `CLAUDE.md`).

Each entry below defines: the firm's **opening (ideal) position**, the **fallback range** we can accept without escalation, the **floor** below which a clause must escalate to a senior attorney, and **redline signals** — language patterns in an incoming draft that should be flagged for review rather than silently auto-categorized (Redline Rule 2).

Risk thresholds referenced here are **defaults for this playbook only** — per-company overrides live in `config/risk_thresholds/`, never hardcoded into extraction or redline logic itself.

---

## 1. Structure — Mutual vs. One-Way

- **Opening position:** Mutual NDA — both parties may act as Discloser and Recipient at different times, with symmetric obligations on both sides (matches the MUTUAL branch of `drafting/templates/nda_template.md`).
- **Fallback range:** One-way NDA is acceptable where the underlying business relationship is genuinely one-directional (e.g. a vendor being given access to our confidential information for evaluation only, with no reciprocal disclosure expected).
- **Floor:** Never accept a one-way NDA where our side is the sole Receiving Party but the actual information flow will be, or is likely to become, bidirectional — this leaves our own disclosures unprotected. Escalate if the counterparty insists on one-way in a deal shape that looks two-directional.
- **Redline signals:** counterparty converts a mutual draft to one-way (or vice versa) without a corresponding change to the Recitals and Definition of Confidential Information sections — check for label drift (Discloser/Recipient vs. Disclosing Party/Receiving Party) left inconsistent across clauses, which is itself a drafting-quality flag independent of the substantive ask.

## 2. Term

- **Opening position:** 3-year term from the Effective Date (agreement stays in effect for 3 years, independent of the confidentiality survival period in Section 3 below).
- **Fallback range:** 1–5 years, depending on the expected duration of the underlying business relationship or evaluation.
- **Floor:** Never accept an indefinite/perpetual term for the agreement itself (as distinct from the survival obligations, which may run longer — see Section 3). An indefinite term with no end date should be flagged even if the substantive confidentiality terms are otherwise standard.
- **Redline signals:** term length silently extended or shortened between negotiation rounds (diff against the canonical draft, not the prior round, per Redline Rule 1); term tied to an undefined triggering event ("until the Purpose is completed") with no outside date.

## 3. Confidentiality Survival Period

- **Opening position:** Confidentiality and non-use obligations survive termination or expiration of the Agreement for 3 years from the date of disclosure or termination, whichever is later — matching `{{SURVIVAL_PERIOD}}` in the drafting template.
- **Fallback range:** 2–5 years for general confidential information.
- **Floor:** Never accept a survival period shorter than 1 year, and never accept a survival period that terminates automatically with the Agreement's term (Section 2) with no independent survival clause at all — confidentiality obligations must outlive the agreement itself to have any value.
- **Redline signals:** survival period removed or merged into the general term (i.e., confidentiality obligations expire the moment the agreement expires); no distinction drawn between the agreement's term and the survival period, which is a common drafting error that silently weakens protection — flag as ambiguous rather than assume the longer period controls (Legal Accuracy Rule 4).

## 4. Carve-Out — Publicly Known Information

- **Opening position:** Confidential Information excludes information that is or becomes publicly available through no fault of the Recipient (standard Exclusion (b) in `nda_template.md` Section 4).
- **Fallback range:** None needed — this is a standard, non-negotiable-in-substance carve-out. Acceptable to negotiate only the drafting mechanics (e.g. requiring the Recipient to "demonstrate by written evidence" the information's public availability, which is procedurally more protective of the Discloser).
- **Floor:** Never accept language that broadens this carve-out to cover information that is publicly known in part, or that removes the "through no fault of the Recipient" qualifier — without that qualifier, a Recipient's own unauthorized disclosure could retroactively excuse its own breach.
- **Redline signals:** carve-out reworded to "is or becomes generally known in the industry" (broader and vaguer than "publicly available"); "through no fault of the Recipient" qualifier deleted; carve-out applied to information that is only partially public (e.g. a subset of data points published, but the compiled dataset itself is not).

## 5. Carve-Out — Independent Development

- **Opening position:** Confidential Information excludes information independently developed by the Recipient without use of or reference to the Discloser's Confidential Information (standard Exclusion (c) in `nda_template.md` Section 4).
- **Fallback range:** Acceptable to add a documentation/evidentiary requirement (e.g. contemporaneous records showing independent development) if either party requests it — this strengthens rather than weakens the clause.
- **Floor:** Never accept removal of the "without use of or reference to" qualifier — a bare "independently developed" carve-out with no non-reliance requirement effectively guts confidentiality protection, since it becomes unfalsifiable.
- **Redline signals:** qualifier narrowed or removed ("developed independently" with no non-reliance language); burden of proof shifted from the Recipient (who must demonstrate independent development) to the Discloser (who would have to prove reliance) — this inversion should always be flagged, since it reverses the standard evidentiary posture.

## 6. Carve-Out — Compelled Disclosure

- **Opening position:** Recipient may disclose Confidential Information to the extent required by law, regulation, or a valid order of a court or governmental authority, provided that, where legally permitted, Recipient gives Discloser prompt prior written notice so the Discloser may seek a protective order (standard Section 5 language in `nda_template.md`).
- **Fallback range:** Acceptable to add a requirement that the Recipient disclose only the minimum portion of Confidential Information legally required and use reasonable efforts to obtain confidential treatment for anything disclosed.
- **Floor:** Never accept a compelled-disclosure carve-out with no notice obligation at all, and never accept language that excuses notice under a broadly-defined "confidentiality of the legal process" exception that could apply to routine subpoenas — the "where legally permitted" qualifier must be narrow (e.g. gag orders), not a general escape hatch.
- **Redline signals:** prior-notice requirement deleted or made "reasonable efforts" only with no specificity on timing; "prompt" notice weakened to "notice within a reasonable time" with no outer bound; minimum-necessary-disclosure limitation absent from an otherwise broadened compelled-disclosure clause.

## 7. Carve-Out — Prior Knowledge

- **Opening position:** Confidential Information excludes information already known to the Recipient without an obligation of confidentiality prior to disclosure by the Discloser (standard Exclusion (a) in `nda_template.md` Section 4).
- **Fallback range:** Acceptable to require the Recipient to substantiate prior knowledge with contemporaneous written records at the time of disclosure.
- **Floor:** Never accept a version of this carve-out with no "without an obligation of confidentiality" qualifier — otherwise information the Recipient already held under a separate NDA with a third party could be improperly disclosed under this one.
- **Redline signals:** qualifier "without an obligation of confidentiality" removed; carve-out silently combined with the third-party-receipt carve-out (Section 8 below) in a way that blurs the two distinct evidentiary standards.

## 8. Carve-Out — Third-Party Receipt

- **Opening position:** Confidential Information excludes information rightfully received by the Recipient from a third party without breach of any obligation of confidentiality owed to the Discloser (standard Exclusion (d) in `nda_template.md` Section 4).
- **Fallback range:** None needed — standard, non-negotiable-in-substance carve-out.
- **Floor:** Never accept removal of "rightfully" or "without breach of any obligation of confidentiality" — without these qualifiers, information obtained by the third party through its own breach of a separate NDA could be laundered through this carve-out.
- **Redline signals:** "rightfully" qualifier dropped; carve-out broadened to any third-party source regardless of how that third party obtained the information.

## 9. Remedies / Injunctive Relief

- **Opening position:** Each Party acknowledges unauthorized use or disclosure may cause irreparable harm, and the Discloser is entitled to seek injunctive or other equitable relief without the necessity of posting a bond, in addition to other available remedies (standard Section 8 in `nda_template.md`).
- **Fallback range:** Acceptable to negotiate away the no-bond language if a court in the governing jurisdiction would not enforce it anyway (jurisdiction-dependent — flag for local counsel review rather than resolve unilaterally).
- **Floor:** Never accept removal of injunctive relief entirely in favor of monetary damages only — confidentiality breaches are frequently unquantifiable in damages, so equitable relief availability is a floor term.
- **Redline signals:** injunctive relief clause narrowed to require proof of actual damages first; irreparable harm acknowledgment deleted (weakens the evidentiary basis for seeking an injunction later).

## 10. Non-Solicitation / Non-Compete Riders

- **Opening position:** Standard NDA contains no non-solicitation or non-compete obligations — those are out of scope for a confidentiality agreement and should be handled, if needed, in a separate agreement.
- **Fallback range:** A narrow non-solicitation-of-employees clause (e.g. 12 months, limited to employees with direct knowledge of the negotiation) is acceptable if the counterparty insists, but should be added as a distinct section, not blended into the confidentiality obligations.
- **Floor:** Never accept a non-compete provision embedded in an NDA — this is a floor issue requiring escalation regardless of scope, since non-competes carry separate enforceability and consideration requirements the NDA process is not built to evaluate.
- **Redline signals:** any non-solicitation, non-compete, non-circumvention, or exclusivity language appearing in an incoming NDA draft — flag immediately as out-of-scope-for-document-type rather than evaluating it against confidentiality standards.

## 11. Governing Law

- **Opening position:** Delaware, without regard to conflict-of-laws principles; exclusive jurisdiction and venue in Delaware state or federal courts (consistent with `redlining/playbooks/msa_playbook.md` Section 4, for consistency across the firm's standard paper).
- **Fallback range:** New York or the jurisdiction where the counterparty is headquartered, if Delaware is a sticking point on an otherwise low-risk NDA.
- **Floor:** Escalate any request for a jurisdiction with underdeveloped commercial contract case law, or a jurisdiction inconsistent with the venue named elsewhere in the same document.
- **Redline signals:** governing law and venue clauses naming different jurisdictions within the same document; governing law silently changed between negotiation rounds.

## 12. Definition of Confidential Information — Scope

- **Opening position:** Broad, non-exhaustive definition covering information disclosed orally, in writing, electronically, or by any other means, whether or not marked confidential, including the existence and terms of the Agreement and the Parties' discussions (standard Section 2 in `nda_template.md`).
- **Fallback range:** Acceptable to require that orally-disclosed information be confirmed in writing within a set period (e.g. 30 days) to qualify for protection, if the counterparty requests a "marking" requirement for administrability.
- **Floor:** Never accept a definition limited only to information marked "Confidential" in writing with no catch-all for orally disclosed or unmarked information — this creates large, easily-exploited gaps in coverage. If a marking requirement is accepted, it must include a written-confirmation cure period, not an outright exclusion of unmarked information.
- **Redline signals:** definition narrowed to written-and-marked information only, with no oral-disclosure or unmarked-information catch-all; "existence and terms of this Agreement" confidentiality removed (this is often itself sensitive, e.g. in M&A diligence contexts); definition scope changed asymmetrically (broader for one party's disclosures than the other) in a document otherwise structured as mutual — flag as inconsistent with Section 1 above.

---

## Using This Playbook in the Redline Pipeline (UC2/UC3)

- Every clause identified as touching one of the 12 areas above must be diffed against the **canonical playbook position**, not against a prior negotiation round (Redline Rule 1) — drift compounds silently otherwise.
- A clause falling within the **fallback range** may be surfaced as auto-suggested acceptable but still requires lawyer sign-off before any redline is sent back to the counterparty (Redline Rule 3).
- A clause at or beyond the **floor** must be flagged for senior attorney escalation, not auto-rejected or auto-countered.
- Any redline signal listed above that appears in an incoming draft must be flagged for human review, with a citation to its location in the incoming document and (if applicable) the corresponding canonical section, per Legal Accuracy Rule 3 and Redline Rule 4.
- This playbook does not itself resolve ambiguous language — if a clause could plausibly fall into more than one category above, or the intent is unclear, flag it rather than guessing which position applies (Legal Accuracy Rule 4).

`[NEED: legal team sign-off on floor values above (survival period floor, carve-out qualifier language, non-solicitation fallback scope) before this playbook is used to auto-suggest accept/reject dispositions in production.]`

<!--
  SOW TEMPLATE — ContractIQ fast-draft path (UC1 prototype, SOW variant)

  This file is read directly by an LLM drafting agent (see drafting/draft_sow.sh).
  It is NOT meant to be rendered/shown to a counterparty as-is — it is filled in,
  then reviewed by a licensed attorney before it goes anywhere near a counterparty.
  Per CLAUDE.md, a SOW is typically nested under an MSA; this fast-path drafts the
  SOW as a standalone document for attorney review, who will confirm how it should
  reference or attach to any governing MSA.

  PLACEHOLDER TOKENS (replace every occurrence, do not leave any {{TOKEN}} in output):
    {{PARTY_A_NAME}}            - from --party-a (the Service Provider).
    {{PARTY_A_ENTITY_TYPE}}     - not supplied by the caller. If it cannot be
                                   reasonably inferred, write the literal marker
                                   "[ENTITY TYPE TO BE COMPLETED]" — never invent a
                                   jurisdiction of incorporation or entity type.
    {{PARTY_A_ADDRESS}}         - not supplied. If unknown, write
                                   "[ADDRESS TO BE COMPLETED]".
    {{PARTY_B_NAME}}            - from --party-b (the Client).
    {{PARTY_B_ENTITY_TYPE}}     - same handling as {{PARTY_A_ENTITY_TYPE}}.
    {{PARTY_B_ADDRESS}}         - same handling as {{PARTY_A_ADDRESS}}.
    {{EFFECTIVE_DATE}}          - the one exception to "never guess": fill with
                                   today's date in ISO 8601 (YYYY-MM-DD). This is a
                                   procedural default (execution date), not a
                                   fabricated legal term.
    {{PROJECT_SCOPE}}           - from --project-scope. Never paraphrase away
                                   specificity the caller provided; never add scope
                                   the caller did not state.
    {{DELIVERABLES}}            - from --deliverables. Render as a list if the
                                   caller's input contains natural list separators
                                   (commas, semicolons, line breaks); otherwise
                                   render as-is. Never invent additional deliverables.
    {{MILESTONES}}              - from --milestones. Must preserve every date the
                                   caller supplied exactly as given, converted to
                                   ISO 8601 (YYYY-MM-DD) only if the caller's format
                                   is unambiguous (e.g. "March 1, 2027" -> "2027-03-01").
                                   If a milestone date is ambiguous or missing, leave
                                   the literal marker "[DATE TO BE COMPLETED]" next to
                                   that milestone rather than guessing a date.
    {{ACCEPTANCE_CRITERIA}}     - from --acceptance-criteria. Never soften or
                                   generalize caller-supplied acceptance conditions.
    {{CHANGE_ORDER_PROCESS}}    - from --change-order-process. If not supplied and
                                   cannot be reasonably inferred, leave the literal
                                   marker "[CHANGE ORDER PROCESS TO BE COMPLETED]"
                                   rather than inventing an approval workflow.

  NEVER GUESS: if any of the fields above the {{EFFECTIVE_DATE}} exception were not
  supplied by the caller and cannot be reasonably inferred from what was supplied,
  leave the literal bracketed marker "[<FIELD NAME> TO BE COMPLETED]" in place
  rather than inventing content. This mirrors CLAUDE.md's Legal Accuracy Rules
  (never fabricate a term; null/placeholder beats a plausible-sounding guess).

  OUTPUT: clean, properly formatted markdown only. No commentary before or after
  the document. No unresolved {{TOKEN}} placeholders.
-->

# Statement of Work

## 1. Recitals

This Statement of Work ("**SOW**") is entered into as of {{EFFECTIVE_DATE}} ("**Effective Date**") by and between {{PARTY_A_NAME}}, {{PARTY_A_ENTITY_TYPE}}, with a principal place of business at {{PARTY_A_ADDRESS}} ("**Provider**"), and {{PARTY_B_NAME}}, {{PARTY_B_ENTITY_TYPE}}, with a principal place of business at {{PARTY_B_ADDRESS}} ("**Client**") (each a "**Party**" and together the "**Parties**").

This SOW describes the project scope, deliverables, milestones, and acceptance criteria for the engagement between the Parties. Where this SOW is executed under a separately executed master services agreement between the Parties, the terms of that agreement govern in the event of any conflict with this SOW, except as this SOW expressly states otherwise.

## 2. Project Scope

{{PROJECT_SCOPE}}

## 3. Deliverables

Provider shall provide the Client with the following deliverables (the "**Deliverables**"):

{{DELIVERABLES}}

## 4. Milestones and Schedule

The Deliverables shall be completed according to the following milestone schedule:

{{MILESTONES}}

Dates above are subject to adjustment only through the Change Order process described in Section 6.

## 5. Acceptance Criteria

A Deliverable shall be deemed accepted by Client upon satisfaction of the following criteria: {{ACCEPTANCE_CRITERIA}}. Client shall notify Provider in writing of acceptance or rejection of a Deliverable within ten (10) business days of delivery; any Deliverable not affirmatively rejected in writing within that period shall be deemed accepted. If Client rejects a Deliverable, Client shall specify in writing the respects in which the Deliverable fails to meet the acceptance criteria stated above, and Provider shall have a reasonable opportunity to cure before re-submission.

## 6. Change Order Process

{{CHANGE_ORDER_PROCESS}}

No change to the scope, Deliverables, milestones, or fees described in this SOW shall be effective unless documented in a written change order signed by authorized representatives of both Parties.

## 7. Entire Agreement

This SOW, together with any master services agreement it is executed under, constitutes the entire agreement between the Parties with respect to its subject matter and supersedes all prior or contemporaneous agreements, understandings, and communications, whether written or oral, relating to such subject matter.

---

**{{PARTY_A_NAME}}**

By: _______________________
Name:
Title:
Date:

**{{PARTY_B_NAME}}**

By: _______________________
Name:
Title:
Date:

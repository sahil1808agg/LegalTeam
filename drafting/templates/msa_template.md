<!--
  MSA TEMPLATE — ContractIQ fast-draft path (UC1 prototype, MSA variant)

  This file is read directly by an LLM drafting agent (see drafting/draft_msa.sh).
  It is NOT meant to be rendered/shown to a counterparty as-is — it is filled in,
  then reviewed by a licensed attorney before it goes anywhere near a counterparty.

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
    {{TERM_LENGTH}}             - from --term, e.g. "2 years".
    {{SERVICES_DESCRIPTION}}    - from --services-description. Never paraphrase away
                                   specificity the caller provided; never add scope
                                   the caller did not state.
    {{PAYMENT_TERMS}}           - from --payment-terms, e.g. "$10,000/month, Net 30".
    {{IP_OWNERSHIP}}            - from --ip-ownership, e.g. "client owns all
                                   work product upon full payment" or "provider
                                   retains pre-existing IP; client owns deliverables".
                                   Drop this clause language in verbatim substance —
                                   do not soften or reinterpret the ownership split.
    {{WARRANTY_DISCLAIMERS}}    - from --warranty-disclaimers. Insert as additional
                                   disclaimer language alongside the template's
                                   standard "AS-IS" baseline in Section 6 — do not
                                   let caller-supplied text remove the baseline
                                   disclaimer, only supplement it.
    {{LIABILITY_CAP_MULTIPLIER}} - from --liability-cap-multiplier (defaults to "2"
                                   if the caller did not override it). The cap is
                                   always expressed as this multiplier times fees
                                   paid, per Section 7 below.
    {{GOVERNING_LAW}}           - from --governing-law. Used for governing law and
                                   venue.

  NEVER GUESS: if any of the fields above the {{EFFECTIVE_DATE}} exception were not
  supplied by the caller and cannot be reasonably inferred from what was supplied,
  leave the literal bracketed marker "[<FIELD NAME> TO BE COMPLETED]" in place
  rather than inventing content. This mirrors CLAUDE.md's Legal Accuracy Rules
  (never fabricate a term; null/placeholder beats a plausible-sounding guess).

  OUTPUT: clean, properly formatted markdown only. No commentary before or after
  the document. No unresolved {{TOKEN}} placeholders.
-->

# Master Service Agreement

## 1. Recitals

This Master Service Agreement ("**Agreement**") is entered into as of {{EFFECTIVE_DATE}} ("**Effective Date**") by and between {{PARTY_A_NAME}}, {{PARTY_A_ENTITY_TYPE}}, with a principal place of business at {{PARTY_A_ADDRESS}} ("**Provider**"), and {{PARTY_B_NAME}}, {{PARTY_B_ENTITY_TYPE}}, with a principal place of business at {{PARTY_B_ADDRESS}} ("**Client**") (each a "**Party**" and together the "**Parties**").

The Parties wish to enter into this Agreement to govern the provision of services by Provider to Client as described herein, including any statements of work executed under it from time to time.

## 2. Services

Provider shall perform the following services for Client (the "**Services**"): {{SERVICES_DESCRIPTION}}. Additional or modified scope may be documented in a separately executed statement of work referencing this Agreement, which shall be incorporated herein by reference upon execution by both Parties.

## 3. Payment Terms

Client shall pay Provider for the Services as follows: {{PAYMENT_TERMS}}. Invoices not disputed in good faith within fifteen (15) days of receipt shall be deemed accepted. Amounts not paid when due shall accrue interest at the lesser of 1.5% per month or the maximum rate permitted by applicable law.

## 4. Intellectual Property Ownership

{{IP_OWNERSHIP}}. Except as expressly set forth in this Section, each Party retains all right, title, and interest in and to its own pre-existing intellectual property, and no license is granted by either Party to the other except as necessary to perform this Agreement or as expressly stated above.

## 5. Term and Termination

This Agreement shall commence on the Effective Date and continue for {{TERM_LENGTH}}, unless earlier terminated as provided herein. Either Party may terminate this Agreement for material breach by the other Party that remains uncured thirty (30) days after written notice describing the breach. Termination of this Agreement shall not relieve either Party of obligations accrued prior to termination, including payment obligations for Services already performed.

## 6. Warranty Disclaimers

EXCEPT AS EXPRESSLY STATED IN THIS AGREEMENT, THE SERVICES AND ANY DELIVERABLES ARE PROVIDED "AS IS," AND PROVIDER DISCLAIMS ALL OTHER WARRANTIES, WHETHER EXPRESS, IMPLIED, OR STATUTORY, INCLUDING THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. {{WARRANTY_DISCLAIMERS}}

## 7. Limitation of Liability

EXCEPT FOR BREACHES OF CONFIDENTIALITY OBLIGATIONS, INDEMNIFICATION OBLIGATIONS, OR A PARTY'S GROSS NEGLIGENCE OR WILLFUL MISCONDUCT, EACH PARTY'S TOTAL AGGREGATE LIABILITY ARISING OUT OF OR RELATING TO THIS AGREEMENT SHALL NOT EXCEED {{LIABILITY_CAP_MULTIPLIER}} TIMES THE TOTAL FEES PAID OR PAYABLE BY CLIENT TO PROVIDER UNDER THIS AGREEMENT IN THE TWELVE (12) MONTHS PRECEDING THE EVENT GIVING RISE TO THE CLAIM. NEITHER PARTY SHALL BE LIABLE FOR ANY INDIRECT, INCIDENTAL, CONSEQUENTIAL, SPECIAL, OR PUNITIVE DAMAGES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

## 8. Confidentiality

Each Party may disclose confidential or proprietary information to the other in connection with this Agreement. The receiving Party shall use such information solely to perform its obligations under this Agreement, protect it with at least a reasonable degree of care, and not disclose it to third parties except as necessary to perform this Agreement or as required by law. This Section survives termination of this Agreement.

## 9. Independent Contractor

Provider is an independent contractor, and nothing in this Agreement shall be construed to create a partnership, joint venture, agency, or employment relationship between the Parties.

## 10. Governing Law

This Agreement shall be governed by and construed in accordance with the laws of {{GOVERNING_LAW}}, without regard to its conflict of laws principles. Each Party irrevocably submits to the exclusive jurisdiction and venue of the courts located in {{GOVERNING_LAW}} for any action arising out of or relating to this Agreement.

## 11. Assignment

Neither Party may assign this Agreement without the prior written consent of the other Party, except that either Party may assign this Agreement without consent in connection with a merger, acquisition, or sale of all or substantially all of its assets.

## 12. Entire Agreement

This Agreement, together with any statements of work executed under it, constitutes the entire agreement between the Parties with respect to its subject matter and supersedes all prior or contemporaneous agreements, understandings, and communications, whether written or oral, relating to such subject matter.

## 13. Amendment

This Agreement may be amended or modified only by a written instrument signed by authorized representatives of both Parties. No waiver of any provision of this Agreement shall be effective unless in writing and signed by the Party against whom the waiver is sought to be enforced.

## 14. Counterparts

This Agreement may be executed in one or more counterparts, each of which shall be deemed an original, and all of which together shall constitute one and the same instrument. A signature delivered by electronic means (including PDF or electronic signature platform) shall be deemed an original signature for all purposes.

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

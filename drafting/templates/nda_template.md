<!--
  NDA TEMPLATE — ContractIQ fast-draft path (UC1 prototype)

  This file is read directly by an LLM drafting agent (see drafting/draft_nda.sh).
  It is NOT meant to be rendered/shown to a counterparty as-is — it is filled in,
  then reviewed by a licensed attorney before it goes anywhere near a counterparty.

  PLACEHOLDER TOKENS (replace every occurrence, do not leave any {{TOKEN}} in output):
    {{PARTY_A_NAME}}          - from --party-a
    {{PARTY_A_ENTITY_TYPE}}   - not supplied by the caller. If it cannot be reasonably
                                 inferred, write the literal marker
                                 "[ENTITY TYPE TO BE COMPLETED]" — never invent a
                                 jurisdiction of incorporation or entity type.
    {{PARTY_A_ADDRESS}}       - not supplied. If unknown, write
                                 "[ADDRESS TO BE COMPLETED]".
    {{PARTY_B_NAME}}          - from --party-b
    {{PARTY_B_ENTITY_TYPE}}   - same handling as {{PARTY_A_ENTITY_TYPE}}.
    {{PARTY_B_ADDRESS}}       - same handling as {{PARTY_A_ADDRESS}}.
    {{PURPOSE}}                - not supplied. Purpose materially narrows or broadens
                                 the scope of confidentiality, so it must never be
                                 guessed. If unknown, write
                                 "[PURPOSE TO BE COMPLETED — specify evaluation purpose]".
    {{EFFECTIVE_DATE}}         - the one exception to "never guess": fill with
                                 today's date in ISO 8601 (YYYY-MM-DD). This is a
                                 procedural default (execution date), not a fabricated
                                 legal term.
    {{JURISDICTION}}           - from --jurisdiction. Used for governing law and venue.
    {{TERM_LENGTH}}            - from --term, e.g. "2 years".
    {{SURVIVAL_PERIOD}}        - fixed template default: "three (3) years from the date
                                 of disclosure or termination of this Agreement,
                                 whichever is later", regardless of {{TERM_LENGTH}}.
                                 This is a template default for attorney review, not an
                                 extracted fact — flag it as such if asked.

  MUTUAL vs. ONE-WAY (driven by --mutual yes/no, not a literal token):
    - ONE-WAY (--mutual no): {{PARTY_A_NAME}} is the Disclosing Party,
      {{PARTY_B_NAME}} is the Receiving Party, for the life of the document. Use
      those fixed labels throughout.
    - MUTUAL (--mutual yes): both parties may act as Discloser and Recipient at
      different times. Use party-neutral language ("each Party," "the Receiving
      Party" without a fixed name-to-role mapping) and make every obligation bind
      both parties symmetrically.
    - Clauses 1, 2, 3, 5, 7, 8 below need this branching — each has its own short
      reminder. Clauses 6, 9, 10, 11, 12 have no mutual/one-way variation at all
      (substance and labels both stay the same). Clause 4's substantive rule
      doesn't vary, but it still uses role labels ("Discloser"/"Recipient") in
      its body text — see its own reminder for how to handle that.
    - WHOLE-DOCUMENT CONSISTENCY: once you pick the pair of role labels for this
      draft (e.g. "Disclosing Party"/"Receiving Party" for ONE-WAY, or
      "Discloser"/"Recipient" for MUTUAL) in Recitals and the Definition of
      Confidential Information, use that exact same pair in every remaining
      clause. Never let a clause fall back to the other pair, even where a
      clause's underlying rule doesn't otherwise change between MUTUAL and
      ONE-WAY.

  OUTPUT: clean, properly formatted markdown only. No commentary before or after
  the document. No unresolved {{TOKEN}} placeholders.
-->

# Non-Disclosure Agreement

## 1. Recitals

<!-- Identify both parties and state the purpose of disclosure. ONE-WAY: designate
     {{PARTY_A_NAME}} as Disclosing Party and {{PARTY_B_NAME}} as Receiving Party
     and keep that designation consistent below. MUTUAL: describe both parties as
     potentially disclosing and receiving information from each other. -->

This Non-Disclosure Agreement ("**Agreement**") is entered into as of {{EFFECTIVE_DATE}} ("**Effective Date**") by and between {{PARTY_A_NAME}}, {{PARTY_A_ENTITY_TYPE}}, with a principal place of business at {{PARTY_A_ADDRESS}} ("**Party A**"), and {{PARTY_B_NAME}}, {{PARTY_B_ENTITY_TYPE}}, with a principal place of business at {{PARTY_B_ADDRESS}} ("**Party B**") (each a "**Party**" and together the "**Parties**").

The Parties wish to explore and evaluate {{PURPOSE}} (the "**Purpose**"), during which each Party may disclose certain confidential and proprietary information to the other. This Agreement sets forth the terms under which such information will be protected.

## 2. Definition of Confidential Information

<!-- ONE-WAY: define confidential information as belonging only to the Disclosing
     Party. MUTUAL: define symmetrically — either Party's information qualifies
     when disclosed to the other, using "Discloser"/"Recipient" generically rather
     than fixed party names. -->

"**Confidential Information**" means any non-public, proprietary, or confidential information disclosed by one Party (the "**Discloser**") to the other Party (the "**Recipient**") in connection with the Purpose, whether disclosed orally, in writing, electronically, or by any other means, and whether or not marked or identified as confidential, including but not limited to business plans, financial information, technical data, product designs, customer and vendor information, and the existence and terms of this Agreement and the Parties' discussions.

## 3. Obligations of Receiving Party

<!-- Core confidentiality/non-use covenant. ONE-WAY: obligations bind only
     {{PARTY_B_NAME}} as Receiving Party with respect to {{PARTY_A_NAME}}'s
     Confidential Information. MUTUAL: obligations bind each Party symmetrically
     with respect to Confidential Information it receives from the other — use
     "the Recipient" / "each Party," not fixed names. -->

The Recipient shall: (a) use the Discloser's Confidential Information solely for the Purpose; (b) protect the Confidential Information using at least the same degree of care it uses to protect its own confidential information of similar nature, and in no event less than a reasonable degree of care; (c) not disclose the Confidential Information to any third party except as expressly permitted under Section 5; and (d) not reproduce or retain the Confidential Information beyond what is reasonably necessary for the Purpose.

## 4. Exclusions

<!-- The underlying carve-out rules are identical for MUTUAL and ONE-WAY. However,
     the labels "Recipient" and "Discloser" below are placeholders for whichever
     defined terms this draft actually uses — substitute them for "Receiving
     Party"/"Disclosing Party" in a ONE-WAY draft, or leave as "Recipient"/
     "Discloser" in a MUTUAL draft. Do not mix labels: every clause in the
     finished document must use the exact same pair of role labels introduced
     in Recitals/Definition of Confidential Information above. -->

Confidential Information does not include information that the Recipient can demonstrate: (a) was already known to the Recipient without an obligation of confidentiality prior to disclosure by the Discloser; (b) is or becomes publicly available through no fault of the Recipient; (c) is independently developed by the Recipient without use of or reference to the Discloser's Confidential Information; or (d) is rightfully received by the Recipient from a third party without breach of any obligation of confidentiality owed to the Discloser.

## 5. Permitted Disclosures

<!-- Permits disclosure to representatives and legally-compelled disclosure with
     notice. ONE-WAY: applies to Party B's (Receiving Party's) representatives only.
     MUTUAL: applies to either Party's representatives when it is acting as
     Recipient. -->

The Recipient may disclose Confidential Information to its officers, employees, contractors, and professional advisors who have a need to know such information for the Purpose and who are bound by confidentiality obligations at least as protective as those in this Agreement. The Recipient may also disclose Confidential Information to the extent required by law, regulation, or a valid order of a court or other governmental authority, provided that, where legally permitted, the Recipient gives the Discloser prompt prior written notice of such requirement so that the Discloser may seek a protective order or other appropriate remedy.

## 6. Term

<!-- No mutual/one-way variation. -->

This Agreement shall commence on the Effective Date and shall remain in effect for {{TERM_LENGTH}}, unless earlier terminated by either Party upon written notice to the other Party. Termination of this Agreement shall not relieve either Party of its obligations with respect to Confidential Information disclosed prior to termination.

## 7. Return of Materials

<!-- Obligation to return/destroy materials, plus confidentiality survival period.
     ONE-WAY: binds only the Receiving Party. MUTUAL: binds each Party reciprocally
     with respect to Confidential Information it received. -->

Upon the Discloser's written request, or upon termination or expiration of this Agreement, the Recipient shall promptly return or destroy all Confidential Information in its possession, including all copies, and, upon request, certify such destruction in writing, except that the Recipient may retain one archival copy solely to the extent required to comply with applicable law or bona fide document-retention policies, subject to the continuing confidentiality obligations of this Agreement. The obligations of confidentiality and non-use set forth in this Agreement shall survive termination or expiration of this Agreement for {{SURVIVAL_PERIOD}}.

## 8. Remedies

<!-- ONE-WAY: remedies run to the Disclosing Party only. MUTUAL: remedies are
     available to either Party as an aggrieved Discloser. -->

Each Party acknowledges that unauthorized use or disclosure of Confidential Information may cause irreparable harm for which monetary damages alone would be an inadequate remedy. Accordingly, in addition to any other remedies available at law or in equity, the Discloser shall be entitled to seek injunctive or other equitable relief to prevent or restrain any actual or threatened breach of this Agreement, without the necessity of posting a bond.

## 9. Governing Law

<!-- No mutual/one-way variation. -->

This Agreement shall be governed by and construed in accordance with the laws of {{JURISDICTION}}, without regard to its conflict of laws principles. Each Party irrevocably submits to the exclusive jurisdiction and venue of the courts located in {{JURISDICTION}} for any action arising out of or relating to this Agreement.

## 10. Entire Agreement

<!-- No mutual/one-way variation. -->

This Agreement constitutes the entire agreement between the Parties with respect to its subject matter and supersedes all prior or contemporaneous agreements, understandings, and communications, whether written or oral, relating to such subject matter.

## 11. Amendment

<!-- No mutual/one-way variation. -->

This Agreement may be amended or modified only by a written instrument signed by authorized representatives of both Parties. No waiver of any provision of this Agreement shall be effective unless in writing and signed by the Party against whom the waiver is sought to be enforced.

## 12. Counterparts

<!-- No mutual/one-way variation. -->

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

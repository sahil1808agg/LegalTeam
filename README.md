# ContractIQ — AI-Native Contract Lifecycle Workspace

An intelligent contract management system for lean legal teams. **Draft → Redline → Extract → Track.**

---

## 📊 Contract Intelligence Database

**[Open Contract Intelligence Notion Database](https://app.notion.com/p/3d3558f40a4580668857efd2482b1f2d?v=3d3558f40a4580f480df000c1613fc8f)**

All extracted contracts are stored here with the 22-field hotspot schema:
- contract_type, counterparty_name, effective_date, execution_date
- term_length, termination_notice_period, auto_renewal_flag, renewal_notice_deadline
- payment_amount, payment_frequency, payment_terms, late_payment_penalty
- limitation_of_liability_cap, indemnification_clause_present, confidentiality_survival_period
- governing_law, jurisdiction, dispute_resolution_mechanism
- sla_commitments, sla_credit_remedy, data_processing_terms, assignment_clause_terms

---

## 🚀 Quick Start

### Extract Contract Hotspots
```bash
./extraction/extract.sh path/to/contract.pdf
# Outputs: extraction/output/contract_extracted.json
```

### Insert Into Notion Database
```bash
./extraction/insert_hotspots.sh extraction/output/contract_extracted.json
# Creates or updates record in Contract Intelligence database
```

### Batch Process Multiple Contracts
```bash
for file in extraction/output/*.json; do
  ./extraction/insert_hotspots.sh "$file"
done
```

---

## 📁 Project Structure

```
/
├── CLAUDE.md                 # Operating contract & legal accuracy rules
├── PRD.md                    # Product requirements & use cases
├── README.md                 # This file
│
├── src/
│   ├── drafting/             # UC1: Clause library & draft generation
│   ├── redline/              # UC2/UC3: Diff engine & fallback comparison
│   ├── extraction/           # UC4: Hotspot detection & term extraction
│   ├── database/             # UC5: Contract repository & search
│   ├── obligations/          # UC6: Deadline tracking & alerting
│   └── shared/               # Shared schemas, types, clients
│
├── extraction/
│   ├── extract.sh            # Contract extraction pipeline
│   ├── insert_hotspots.sh    # Insert/update records in Notion
│   ├── input/                # PDF contracts to process
│   └── output/               # Extracted JSON & processing logs
│
├── contracts/                # Contract repository (PDFs)
├── redlining/                # Redline comparison & history
├── drafting/                 # Draft templates & playbooks
├── tests/                    # Unit, integration, E2E tests
│
└── .claude/
    ├── settings.json         # Claude Code configuration
    └── hooks/                # Pre/post tool execution hooks
```

---

## 🔧 Core Scripts

### `extraction/extract.sh`
**Extracts contract hotspots into the 22-field schema**

```bash
./extraction/extract.sh contracts/sample.pdf
```

Outputs JSON with:
- **value:** extracted term (null if not found)
- **citation:** source location (Section X, ¶N)
- **flag:** ambiguity or data quality issues (if any)

### `extraction/insert_hotspots.sh`
**Inserts/updates contracts in the Notion database**

```bash
./extraction/insert_hotspots.sh extraction/output/contract_extracted.json
./extraction/insert_hotspots.sh extraction/output/contract_extracted.json 3d3558f40a4580668857efd2482b1f2d
```

Reports:
- Notion record URL
- CREATE vs UPDATE operation
- Null fields skipped

---

## 📋 Use Cases (Implemented)

| UC | Scenario | Status |
|----|-----------| --------|
| UC1 | Draft a contract from the clause library | Planned |
| UC2 | Ingest and diff a counterparty redline | Planned |
| UC3 | Compare ask against fallback position | Planned |
| UC4 | Extract hotspots at execution | ✅ Complete |
| UC5 | Search the contract database | ✅ Notion DB live |
| UC6 | Track obligations & deadlines | Planned |

---

## 🛠️ Tech Stack

- **Extraction:** Claude API with vision (PDF parsing)
- **Database:** Notion with MCP (Model Context Protocol)
- **Diff Engine:** TBD (pending evaluation)
- **Orchestration:** Bash scripts + Claude integration
- **Testing:** Synthetic test contracts (no real customer data)

---

## ⚖️ Legal Accuracy

Every extraction follows four non-negotiable rules:

1. **Never fabricate.** If a field is absent, output `null`.
2. **Always cite.** Every non-null field includes its source (Section X, ¶N).
3. **Flag ambiguity.** Unclear language is flagged for human review, not silently resolved.
4. **Schema compliance.** All data conforms to the 22-field hotspot schema.

See `CLAUDE.md` for full legal accuracy rules.

---

## 📖 Documentation

- **[CLAUDE.md](CLAUDE.md)** — Operating contract, coding conventions, extraction rules
- **[PRD.md](PRD.md)** — Product requirements, use cases, success criteria
- **[Notion Database](https://app.notion.com/p/3d3558f40a4580668857efd2482b1f2d)** — Live contract repository

---

## 🤝 Contributing

All changes to extraction, redline, and drafting logic require legal sign-off before merge.

Commit message format:
```
UC4: add liability cap threshold check

Checks extracted liability_of_liability_cap against configured minimums.

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
```

---

## 📞 Support

- **Questions about extraction?** See `CLAUDE.md` → Extraction Schema
- **Need to add a contract type?** Update `CLAUDE.md` → Contract Types Supported
- **Notion database issues?** Check settings.json → Notion MCP configuration

---

**Last updated:** 2026-09-06  
**Notion Database ID:** `3d3558f40a4580668857efd2482b1f2d`  
**Status:** Extraction & Database Pipeline Live ✅

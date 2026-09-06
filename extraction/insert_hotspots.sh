#!/bin/bash
set -euo pipefail

# extraction/insert_hotspots.sh
# Reads an extracted contract JSON file from extraction/output/
# Calls Claude with Notion MCP to insert all 22 fields into the Contract Intelligence Notion database
# Uses contract_name as the unique key — updates existing record if it exists, creates new if not

NOTION_DATABASE_ID="3d3558f40a4580668857efd2482b1f2d"

usage() {
  echo "Usage: $0 <json_file_path> [notion_database_id]"
  echo "Example: $0 extraction/output/contract_1_msa_extracted.json"
  echo "         $0 extraction/output/contract_1_msa_extracted.json 3d3558f40a4580668857efd2482b1f2d"
  exit 1
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
fi

JSON_FILE="$1"
if [[ $# -eq 2 ]]; then
  NOTION_DATABASE_ID="$2"
fi

# Validate file exists
if [[ ! -f "$JSON_FILE" ]]; then
  echo "Error: JSON file not found: $JSON_FILE"
  exit 1
fi

# Derive contract_name from filename (remove path and .json extension)
CONTRACT_NAME=$(basename "$JSON_FILE" .json)

# Read JSON content
JSON_CONTENT=$(cat "$JSON_FILE")

# Build the Claude prompt with Notion MCP instructions
CLAUDE_PROMPT=$(cat <<'PROMPT_END'
You are the Contract Intelligence assistant. You have access to the Notion MCP to manage contracts in the ContractIQ database.

Your task:
1. Read the JSON extracted contract data provided below
2. Insert all 22 fields into the Contract Intelligence Notion database
3. Use the contract_name field as the unique key:
   - If a record with this contract_name already exists, UPDATE it with the new values
   - If no record exists, CREATE a new one
4. After inserting/updating, report:
   - The Notion record URL
   - Whether the operation was CREATE or UPDATE
   - A list of any null fields that were skipped

JSON Extracted Contract Data:
PROMPT_END
)

CLAUDE_PROMPT+=$'\n'"CONTRACT_NAME: $CONTRACT_NAME"$'\n'"$JSON_CONTENT"

# Additional instructions for Notion operations
CLAUDE_PROMPT+=$(cat <<PROMPT_END

**NOTION DATABASE ID: $NOTION_DATABASE_ID**

Use this database ID with the Notion MCP tools to query and update records.

Notion Database Structure:
The Contract Intelligence database has the following properties (corresponding to the 22 hotspot schema fields):
1. contract_type (select: NDA, MSA, SOW, DPA)
2. counterparty_name (text)
3. effective_date (date)
4. execution_date (date)
5. term_length (text)
6. termination_notice_period (text)
7. auto_renewal_flag (checkbox)
8. renewal_notice_deadline (date)
9. payment_amount (number or text)
10. payment_frequency (text)
11. payment_terms (text)
12. late_payment_penalty (text)
13. limitation_of_liability_cap (text)
14. indemnification_clause_present (checkbox)
15. confidentiality_survival_period (text)
16. governing_law (text)
17. jurisdiction (text)
18. dispute_resolution_mechanism (text)
19. sla_commitments (text)
20. sla_credit_remedy (text)
21. data_processing_terms (text)
22. assignment_clause_terms (text)

Instructions:
- For each non-null field in the extracted data, insert or update the corresponding Notion property
- Skip null fields (do not overwrite with empty values)
- Preserve citations in a dedicated "citations" text property for audit trail
- Preserve any flags (ambiguities) in a dedicated "flags" text property for human review
- Use contract_name as the database lookup key for upsert operations
- Return the Notion page URL after the operation completes
PROMPT_END
)

echo "Inserting contract hotspots from: $JSON_FILE"
echo "Contract name: $CONTRACT_NAME"
echo "Database ID: $NOTION_DATABASE_ID"
echo "---"

# Save prompt to a temp file for user reference
PROMPT_FILE="/tmp/claude_insert_hotspots_$CONTRACT_NAME.txt"
echo "$CLAUDE_PROMPT" > "$PROMPT_FILE"

echo "✓ Ready to insert into Notion"
echo ""
echo "To insert this contract into Notion, you have two options:"
echo ""
echo "OPTION 1 — Interactive (Recommended for first-time setup):"
echo "  1. Copy the prompt from: $PROMPT_FILE"
echo "  2. Open Claude Code and paste it"
echo "  3. Approve the Notion MCP permission when prompted"
echo "  4. Claude will handle the insert/update and report the Notion record URL"
echo ""
echo "OPTION 2 — CLI (requires MCP authentication):"
echo "  claude < $PROMPT_FILE"
echo ""
echo "Prompt saved to: $PROMPT_FILE"
echo "---"
echo "Contract name: $CONTRACT_NAME"
echo "Database ID: $NOTION_DATABASE_ID"
echo "Fields: 22 hotspot schema fields (all non-null values will be inserted)"

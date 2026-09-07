# GitHub Actions Workflows for ContractIQ

Two powerful CI/CD workflows have been created to automate contract review and renewal tracking using Claude AI analysis.

---

## Workflow 1: Contract Review Pipeline

**File:** `.github/workflows/contract_review.yml`  
**Trigger:** `push` to `contracts/**` directory  
**Runs on:** Ubuntu latest

### Pipeline Flow

```
Detect new contracts (.txt/.pdf)
  ↓
For each contract:
  1. Chunk PDF if needed (contracts/chunker.sh)
  2. Extract hotspots → extraction/extract.sh
  3. Redline comparison → redline.sh (text only)
  4. AI Risk Analysis via Claude (NEW)
  5. Parse structured JSON output
  ↓
Create GitHub issues with:
  - Contract metadata
  - Extraction completeness %
  - Flagged fields
  - Deviation table (redline)
  - AI risk assessment
```

### Claude AI Analysis Added

Each reviewed contract triggers `claude -p "Analyze contract..." --output-format json` which:
- Returns structured JSON in envelope format
- Extracts `.result` field containing AI analysis
- Provides:
  - `overall_risk_rating`: LOW/MEDIUM/HIGH/CRITICAL
  - `key_risks`: Top 3 concerns (array)
  - `recommended_actions`: Next steps (array)
  - `liability_exposure`: Financial risk summary
  - `escalation_required`: Boolean flag

### Issue Template

```
## 📋 Contract Details
| Filename | Type | Completeness % | Flagged Fields | Deviations |

## ⚠️ AI Risk Assessment
**Overall Risk Rating:** [CRITICAL/HIGH/MEDIUM/LOW]

### Key Risks
- Risk 1
- Risk 2
- Risk 3

### Recommended Actions
- Action 1
- Action 2

### Liability Exposure
[AI Summary]

## 📊 Extraction Results
[22-field table]

## 🔄 Deviation Analysis
[Redline deviation table]
```

### Environment Requirements

```bash
ANTHROPIC_API_KEY  # GitHub secret for Claude API access
```

### Workflow Outputs

- ✅ `extraction/output/{stem}_extracted.json` — 22-field hotspot schema
- ✅ `redlining/output/{DATE}_redline_report_{stem}.md` — Deviation analysis
- ✅ GitHub issue per contract with full analysis
- ✅ Slack notification (MCP integration point)

---

## Workflow 2: Daily Renewal Deadlines

**File:** `.github/workflows/daily_renewals.yml`  
**Trigger:** `schedule` (daily at 9am PT / 4pm UTC)  
**Runs on:** Ubuntu latest  
**Also supports:** Manual trigger via `workflow_dispatch`

### Cron Schedule

```yaml
- cron: '0 16 * * *'  # 9am PT = 4pm UTC (16:00 UTC)
```

### Pipeline Flow

```
Daily at 9am PT
  ↓
Run check_deadlines.sh --days 90
  ↓
Scan all extracted contracts for renewal dates
  ↓
AI Analysis via Claude (NEW)
  ↓
Generate Markdown digest
  ↓
Post Slack notification (MCP integration point)
  ↓
Save artifact for audit trail (30-day retention)
```

### Claude AI Analysis Added

For contracts due in next 90 days, triggers:
```bash
echo "$deadlines_json" | claude -p "Analyze renewals..." --output-format json
```

Returns structured JSON with:
- `summary`: Brief overview of renewal situation
- `critical_actions`: Immediate actions needed (array)
- `risk_patterns`: Recurring risks or patterns
- `recommended_process_improvements`: How to prevent future misses
- `priority_focus`: Which items need immediate attention

### check_deadlines.sh Script

**Location:** `obligations/check_deadlines.sh`

Scans `extraction/output/*.json` files and identifies renewals by:
1. Reading `effective_date` + `term_length`
2. Subtracting `renewal_notice_period` to get deadline
3. OR using explicit `renewal_notice_deadline` if present
4. Filtering for contracts due within N days (default: 90)
5. Assigning risk levels:
   - 🔴 **CRITICAL** — ≤14 days (immediate action required)
   - 🟠 **URGENT** — 15-30 days (needs attention)
   - 🟡 **WARNING** — 31-90 days (track/prepare)

**Usage:**
```bash
obligations/check_deadlines.sh [--days 90] [--output json|markdown|slack]
```

**Output Formats:**
- `json` — Structured array, one object per contract
- `markdown` — Formatted table with renewal details
- `slack` — JSON ready for Slack message formatting

### Daily Digest Output

**If all clear:**
```
✅ No renewal deadlines in next 90 days
All contracts are on track. Check back tomorrow.
```

**If contracts due:**
```
🔔 Renewal Deadlines — 5 contracts due in next 90 days

## 🤖 AI Analysis Summary
[Claude's summary of renewal situation]

### Critical Actions Required
- File non-renewal notice for Acme Corp by 2025-11-15
- Review auto-renewal language for Beta Inc

### Priority Focus
[Claude's assessment of what needs immediate attention]

## 📋 Upcoming Deadlines
| Counterparty | Type | Deadline | Days Left | Risk | Action |

## 🚨 Critical/Urgent Items
- Acme Corp (MSA): Notice due 2025-11-15 (in 7 days)
- Beta Inc (NDA): Notice due 2025-11-20 (in 12 days)

## 🔄 Auto-Renewal Alert
The following contracts auto-renew — ensure notices are filed:
- Acme Corp — 2025-11-15
- Gamma LLC — 2025-12-01

## 💡 Process Improvements
[Claude's recommendations to avoid future deadline misses]
```

### Slack Message Format

**Color-coded by risk:**
- 🔴 Red (danger) — if any CRITICAL/URGENT items
- 🟡 Yellow (warning) — otherwise

**Includes:**
- AI analysis summary
- Critical/Urgent items
- Auto-renewal warnings
- Priority focus areas
- Process improvement suggestions

### Workflow Outputs

- ✅ `renewal-reports/renewals_{DATE}.json` — Daily digest (artifact)
- ✅ Markdown summary logged to workflow
- ✅ Slack notification (MCP integration)
- ✅ 30-day artifact retention for compliance

### Environment Requirements

```bash
ANTHROPIC_API_KEY  # GitHub secret for Claude API access
```

---

## Setup Checklist

### 1. GitHub Secrets

Add `ANTHROPIC_API_KEY` to your GitHub repository secrets:
```
Settings → Secrets and variables → Actions → New repository secret
Name: ANTHROPIC_API_KEY
Value: [your-anthropic-api-key]
```

### 2. Workflow Permissions

Ensure the following permissions are granted:
- `contents: read` — Read repository
- `issues: write` — Create issues (contract_review)
- (No secrets needed for daily_renewals if using artifacts)

### 3. MCP Integration

To enable Slack notifications via MCP:

**Option A: With Claude Code MCP**
```bash
# In your CI/CD pipeline that supports MCP:
echo "$SLACK_MESSAGE" | mcp__claude_ai_Slack__slack_send_message \
  --channel "#legal-contracts" \
  --payload-json
```

**Option B: With Slack Webhook** (alternative)
```yaml
- name: Post to Slack
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
  run: |
    curl -X POST -H 'Content-type: application/json' \
      --data "@slack_payload.json" \
      $SLACK_WEBHOOK_URL
```

**Option C: GitHub Actions App**
```yaml
- uses: slackapi/slack-github-action@v1
  with:
    channel-id: ${{ secrets.SLACK_CHANNEL_ID }}
    slack-message: ${{ env.SLACK_MESSAGE }}
```

### 4. Test Runs

**Contract Review Pipeline:**
```bash
# Push a test contract to contracts/ directory
git add contracts/test_contract.txt
git commit -m "Test: add sample contract for review"
git push origin main

# Workflow runs automatically, creates GitHub issue
```

**Daily Renewals:**
```bash
# Manually trigger via GitHub UI:
# Actions → Daily Renewal Deadlines → Run workflow → Run workflow
# Or via GitHub CLI:
gh workflow run daily_renewals.yml
```

---

## Claude AI Analysis Details

Both workflows use Claude with `--output-format json` which wraps responses in a structured envelope:

```json
{
  "type": "text",
  "result": "{...actual analysis...}",
  "model": "claude-sonnet-5",
  "usage": {...}
}
```

The workflows extract `.result` field and parse it as JSON for structured data access.

### Analysis Prompts

**Contract Review:**
```
Analyze this contract review report and extraction data.
Provide JSON with:
1) overall_risk_rating (LOW/MEDIUM/HIGH/CRITICAL)
2) key_risks (top 3 concerns)
3) recommended_actions (next steps)
4) liability_exposure (summary)
5) escalation_required (boolean)
```

**Daily Renewals:**
```
Analyze this JSON array of contract renewal deadlines.
Provide JSON with:
1) summary (brief overview)
2) critical_actions (immediate actions for CRITICAL items)
3) risk_patterns (recurring risks)
4) recommended_process_improvements (prevent future misses)
5) priority_focus (immediate attention items)
```

---

## Troubleshooting

### Claude API Key Issues

```
Error: claude CLI not found
→ Verify ANTHROPIC_API_KEY secret is set
→ Check CLI installation: curl -sSL https://claude.ai/install.sh | bash
```

### Extraction/Redline Failures

```
Error: PDF chunking failed
→ Run contracts/chunker.sh manually to test
→ Check PDF has text layer (not scanned image)

Error: extraction failed
→ Verify contract file is .txt (PDFs must be chunked first)
→ Check Claude API access: claude --version
```

### Slack Notification Issues

```
No message posted to Slack
→ MCP integration not yet available in GitHub Actions
→ Implement alternative via webhook or GitHub Actions Slack app
→ See "Setup Checklist → MCP Integration" section
```

---

## Performance Notes

- **Contract Review:** ~2-3 minutes per contract (extraction + redline + Claude analysis)
- **Daily Renewals:** ~1-2 minutes for full scan (depends on contract count)
- **Claude API calls:** 1 per contract (review) + 1 per run (renewals)

## Cost Optimization

- Contract review only runs on new commits to `contracts/`
- Daily renewals runs once per day (not on every push)
- Artifacts retained for 30 days (configurable)
- No paid GitHub Actions minutes — everything runs in standard timeouts

---

## Future Enhancements

- [ ] Integrate Slack webhook for notifications (until MCP support)
- [ ] Add custom threshold configuration for risk levels
- [ ] Implement retry logic for transient API failures
- [ ] Add GitHub PR comments with analysis summaries
- [ ] Parallel contract processing for batch uploads
- [ ] Webhook integration for external legal systems
- [ ] Email digest as alternative to Slack
- [ ] Custom report formatting per contract type

---

**Last Updated:** 2026-09-07  
**Created by:** Claude Code  
**Status:** Ready for deployment ✅

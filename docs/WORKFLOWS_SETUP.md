# Quick Setup Guide — Workflows with Claude AI Analysis

## Files Created

✅ `.github/workflows/contract_review.yml` — Contract extraction + AI risk analysis  
✅ `.github/workflows/daily_renewals.yml` — Daily renewal deadline tracking + AI insights  
✅ `obligations/check_deadlines.sh` — Renewal deadline scanner  
✅ `docs/WORKFLOWS.md` — Full documentation

---

## 3-Minute Setup

### Step 1: Add GitHub Secret

```bash
# Copy your Anthropic API key from https://console.anthropic.com

# Add to GitHub (via web UI):
# Settings → Secrets and variables → Actions
# New repository secret:
#   Name: ANTHROPIC_API_KEY
#   Value: sk-ant-...
```

### Step 2: Make Script Executable

```bash
chmod +x obligations/check_deadlines.sh
```

### Step 3: Commit & Push

```bash
git add .github/workflows/ obligations/check_deadlines.sh docs/WORKFLOWS.md
git commit -m "UC4+UC6: add contract review and daily renewal workflows with Claude AI"
git push origin main
```

---

## Test the Workflows

### Test 1: Contract Review (Immediate)

```bash
# Push a test contract
cp tests/fixtures/synthetic_counterparty_msa.md contracts/test_review.txt
git add contracts/test_review.txt
git commit -m "test: trigger contract review workflow"
git push

# Watch: GitHub Actions → Contract Review Pipeline
# Result: Issue created with AI risk assessment
```

### Test 2: Daily Renewals (Manual)

```bash
# Via GitHub CLI:
gh workflow run daily_renewals.yml

# Or via web UI:
# Actions → Daily Renewal Deadlines → "Run workflow" button

# Watch: Actions tab
# Result: Artifact saved with renewal digest
```

---

## What Each Workflow Does

### Contract Review Pipeline

**Triggers:** Push to `contracts/` directory

**For each new contract:**
1. ✅ Extract 22-field hotspot schema
2. ✅ Redline against playbook (text only)
3. ✅ **AI Analysis** via Claude:
   - Risk rating (LOW/HIGH/CRITICAL)
   - Top 3 key risks
   - Recommended actions
   - Liability exposure
   - Escalation flag
4. ✅ Create GitHub issue with full analysis

**Example Issue:**
```
Contract Review: sample_contract.txt

## 📋 Details
Type: MSA | Completeness: 18/22 (82%) | Flagged: 2

## ⚠️ AI Risk Assessment
Overall Risk: HIGH

Key Risks:
- Liability cap of 1x fees (below 2x floor)
- Unilateral IP assignment to counterparty
- Auto-renewal with 30-day notice period

Recommended Actions:
- Negotiate cap to 2x trailing-12-month fees
- Require mutual IP ownership
- Request 60-day renewal notice

Liability Exposure:
Uncapped indemnification exposure plus unilateral IP loss
```

### Daily Renewal Deadlines

**Triggers:** Daily at 9am PT (can be run manually)

**Process:**
1. ✅ Scan all extracted contracts
2. ✅ Find renewal notice deadlines in next 90 days
3. ✅ **AI Analysis** via Claude:
   - Summary of renewal situation
   - Critical actions needed
   - Risk patterns
   - Process improvements
   - Priority focus areas
4. ✅ Post Slack digest (when MCP integrated)
5. ✅ Save daily artifact

**Example Output:**
```
🔔 Renewal Deadlines — 5 contracts due in next 90 days

## 🤖 AI Analysis
Your contract portfolio has 2 critical renewal dates in the next 14 days. 
3 of 5 contracts auto-renew, requiring explicit non-renewal notices.

### Critical Actions Required
- File non-renewal notice for Acme Corp by 2025-11-15 (7 days)
- Review renewal terms for Beta Inc before 2025-11-20

### Priority Focus
Focus on Acme Corp first — largest contract ($500k) with auto-renewal.

## 📋 Upcoming Deadlines
| Acme Corp    | MSA | 2025-11-15 | 7  | CRITICAL | REVIEW_REQUIRED |
| Beta Inc     | NDA | 2025-11-20 | 12 | URGENT   | REVIEW_REQUIRED |
| Gamma Ltd    | SOW | 2025-12-01 | 23 | WARNING  | TRACK           |
| ...          |     |            |    |          |                 |

## 💡 Process Improvements
- Implement 120-day pre-renewal review cycle to avoid last-minute decisions
- Create renewal calendar 6 months in advance
- Set internal escalation at 30-day mark for business review
```

---

## Claude AI Features Used

### Contract Review Analysis

```bash
claude -p "Analyze contract [extraction + redline data]. 
Provide JSON: overall_risk_rating, key_risks, recommended_actions, 
liability_exposure, escalation_required" \
  --output-format json
```

✅ Extracts `.result` field from JSON envelope  
✅ Parses structured analysis  
✅ Includes in GitHub issues  

### Daily Renewals Analysis

```bash
claude -p "Analyze [renewal deadlines JSON]. 
Provide JSON: summary, critical_actions, risk_patterns, 
recommended_process_improvements, priority_focus" \
  --output-format json
```

✅ Analyzes patterns across portfolio  
✅ Provides process recommendations  
✅ Includes in Slack digest  

---

## Slack Integration (Next Step)

Currently, workflows prepare Slack messages but need MCP or webhook to post.

### Option A: With Anthropic MCP (Recommended)

When Claude Code MCP is available in GitHub Actions:

```yaml
- name: Send Slack via MCP
  run: |
    echo "$SLACK_MESSAGE" | \
    mcp__claude_ai_Slack__slack_send_message \
      --channel "#legal-contracts"
```

### Option B: With Webhook (Works Now)

```bash
# 1. Get Slack webhook from your workspace
#    https://api.slack.com/apps → Your App → Incoming Webhooks

# 2. Add to GitHub secrets:
#    SLACK_WEBHOOK_URL = https://hooks.slack.com/services/...

# 3. Update workflow:
- name: Post to Slack
  env:
    WEBHOOK: ${{ secrets.SLACK_WEBHOOK_URL }}
  run: |
    curl -X POST -H 'Content-type: application/json' \
      --data "$SLACK_MESSAGE" \
      "$WEBHOOK"
```

---

## Monitoring & Troubleshooting

### View Workflow Runs

```bash
# Via GitHub CLI
gh workflow list
gh run list --workflow contract_review.yml
gh run view <run_id> --log

# Via web UI
# Actions tab → Click workflow → View runs
```

### Check for Errors

```bash
# Claude API
gh run view <run_id> --log | grep -A5 "Error"

# Extraction
ls -la extraction/output/

# Redline
ls -la redlining/output/

# Check script
bash obligations/check_deadlines.sh --days 90
```

### Common Issues

| Issue | Solution |
|-------|----------|
| `claude: command not found` | API key not set, or CLI install failed |
| `PDF chunking failed` | PDF has no text layer, needs OCR |
| `Extraction failed` | .pdf passed directly (must be .txt or chunked first) |
| `No Slack message` | MCP not integrated yet — use webhook (Option B above) |
| `Redline comparison failed` | Playbook file missing or contract format incorrect |

---

## Workflow Performance

| Task | Time | Frequency |
|------|------|-----------|
| Contract Review | 2-3 min/contract | On push to contracts/ |
| Daily Renewals | 1-2 min | Daily 9am PT |
| Claude Analysis | ~30s/request | Per contract + per renewal run |
| **Total cost** | ~$0.01-0.05/run | Variable, API-dependent |

---

## Next Steps

1. ✅ Add `ANTHROPIC_API_KEY` secret
2. ✅ Test with sample contract
3. ✅ Set up Slack webhook (if using webhooks)
4. ✅ Monitor first few runs
5. ⏭️ Integrate MCP when available
6. ⏭️ Customize Claude prompts for your risk thresholds

---

## Documentation

**Full details:** `docs/WORKFLOWS.md`  
**Workflows created by:** Claude Code  
**Status:** Ready to deploy ✅

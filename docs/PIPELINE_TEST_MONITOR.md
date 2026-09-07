# Live Pipeline Test Monitoring Guide

**Test Contract Pushed:** `contracts/test_workflow_demo.txt` (NDA)  
**Time:** Just now  
**Expected Duration:** ~3-4 minutes  
**Status:** RUNNING NOW 🟢

---

## 📺 Watch in Real-Time

### GitHub Actions Dashboard (Live Updates)

**Direct Link:**
```
https://github.com/sahil1808agg/LegalTeam/actions
```

**Steps:**
1. Click "Contract Review Pipeline" (top of list)
2. Click the latest run (should show your test contract name)
3. Watch steps complete in real-time:
   - ✓ Checkout repository
   - ✓ Install Claude Code CLI
   - ✓ Install dependencies
   - ✓ Detect new contracts → `contracts/test_workflow_demo.txt`
   - ✓ Process contracts
     - ✓ Running extraction...
     - ✓ Running redline comparison...
     - ✓ AI Risk Assessment...
   - ✓ Create GitHub issues
   - ✓ Send to Slack (if webhook set)

**Color codes:**
- 🟡 Yellow dot = Running
- 🟢 Green checkmark = Success
- 🔴 Red X = Failed

### GitHub CLI (Command Line)

Watch live:
```bash
gh run watch
```

View latest run:
```bash
gh run list --limit 1
```

View detailed logs:
```bash
gh run view -L 2000
```

View specific step:
```bash
gh run view --step "Process contracts" -L 500
```

---

## ⏱️ Expected Timeline

| Time | What Happens |
|------|-------------|
| 0 sec | Push detected → Workflow starts |
| 10 sec | Checkout completes |
| 30 sec | Claude CLI installed |
| 45 sec | Dependencies installed |
| 1 min | New contracts detected (test_workflow_demo.txt) |
| 1-2 min | **Extraction running** |
| 2-3 min | **Redline comparison running** |
| 2-3 min | **Claude AI analysis running** |
| 3-4 min | **GitHub issue created** |
| 3.5-4 min | **Slack message posted** (if webhook set) |
| 4 min | ✅ Workflow completes (green checkmark) |

---

## 📋 What to Expect in GitHub Actions

### Workflow Run Status

```
✅ Contract Review Pipeline

Started: 2026-09-07 at 16:45:XX
Duration: ~4 minutes
Status: COMPLETED ✓

Logs:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Detect new contracts
  → 1 new contract detected: contracts/test_workflow_demo.txt
  → Processing...

Process contracts
  → Extraction running...
    ✓ Extracted 22 fields
    ✓ 16/22 fields with values (73%)
    ✓ 2 flagged fields
  → Redline comparison running...
    ✓ Deviations: HIGH: 4, MED: 1, LOW: 2
  → AI Risk Assessment...
    ✓ Risk Rating: MEDIUM
    ✓ Key Risks identified
    ✓ Recommendations provided
  → Saving review data...
  
Create GitHub issues
  → Creating issue for: test_workflow_demo
  → ✓ Issue created

Send to Slack (if webhook set)
  → Checking SLACK_WEBHOOK_URL...
  → ✓ Posted to Slack
```

---

## 📌 GitHub Issue

**Expected Appearance Time:** ~3-4 minutes after push

**Location:** GitHub Issues tab  
**Search:** "Contract Review: test_workflow_demo.txt"

**What the Issue Contains:**

```markdown
# Contract Review: test_workflow_demo.txt

## 📋 Contract Details

| Field | Value |
|---|---|
| Filename | test_workflow_demo.txt |
| Type | NDA |
| Extraction Completeness | 73% (16/22 fields) |
| Flagged Fields | 2 |
| Deviations | HIGH: 4, MED: 1, LOW: 2 |

## ⚠️ AI Risk Assessment

**Overall Risk Rating:** MEDIUM

### Key Risks
- Confidentiality survival period is indefinite (may be excessive)
- No explicit carve-outs for independently developed information
- Return of information clause could be clearer

### Recommended Actions
- Review if indefinite survival is truly needed
- Add standard carve-outs for independent development
- Clarify what constitutes "destruction" of information

### Liability Exposure
Indefinite confidentiality obligations could create long-term restrictions on information use. Consider negotiating finite survival period (e.g., 5-7 years).

## 📊 Extraction Results

| Field | Value | Citation | Flag |
|---|---|---|---|
| contract_type | NDA | Section 1 | ✓ |
| counterparty_name | SecureData LLC | Section 1 | ✓ |
| effective_date | 2026-09-07 | Section 1 | ✓ |
| term_length | 3 years | Section 4 | ✓ |
| confidentiality_survival_period | Indefinite (trade secrets) | Section 4 | ⚠️ FLAG |
| governing_law | California | Section 7 | ✓ |
| jurisdiction | Not specified | — | ⚠️ FLAG |
... (16 more fields)

## 🔄 Deviation Analysis

| Clause | Standard | Counterparty | Deviation | Risk |
|--------|----------|-------------|-----------|------|
| Survival Period | 3-5 years | Indefinite | YES | HIGH |
| Carve-Outs | Explicit list | Implied standard | YES | MED |
| Return Clause | Clear destruction terms | Generic "return/destroy" | YES | LOW |
... (more deviations)

---
Generated: 2026-09-07T16:45:XX  
Analysis: Claude AI
```

**Labels:** `contract-review`, `NDA`

---

## 💬 Slack Message

**Expected Appearance Time:** ~3-4 minutes after push (if webhook set)

**Channel:** `#legal-contracts`

### Via Webhook (Basic Message)

```
🔍 Contract Review Summary — 1 contracts processed

📋 Contract Review Results

• test_workflow_demo.txt (NDA) — 73% complete
  ├─ Flagged: 2 fields
  └─ Deviations: HIGH: 4, MED: 1, LOW: 2
```

### Via MCP (Rich Message)

Run after workflow completes:
```bash
scripts/post_to_slack_mcp.sh --type contract --file extraction/output/test_workflow_demo_extracted.json
```

Posts rich message:
```
📄 Contract Review: test_workflow_demo.txt (NDA)

Completeness: ███████░░░░ 73% (16/22 fields)
Flagged: 2  |  Risk: 🟡 MEDIUM

⚠️ Key Risks:
  • Confidentiality survival indefinite (may be excessive)
  • No explicit carve-outs for independent development
  • Return clause could be clearer

✓ Recommended Actions:
  • Review if indefinite survival needed
  • Add standard carve-outs
  • Clarify "destruction" definition

Deviations: HIGH: 4 | MED: 1 | LOW: 2
```

---

## 📁 Output Files

After workflow completes, check for:

**Extraction JSON:**
```bash
ls -la extraction/output/test_workflow_demo_extracted.json
# Should contain 22 fields (contract_type, counterparty_name, etc.)
```

**Redline Report:**
```bash
ls -la redlining/output/*test_workflow_demo*.md
# Should show deviation table with HIGH/MED/LOW risk items
```

**GitHub Issue:**
```bash
gh issue list --search "Contract Review"
# Should show latest issue for test_workflow_demo.txt
```

---

## 🔍 Verify Each Component

### 1. Extraction Completed

```bash
# Check extraction JSON exists
test -f extraction/output/test_workflow_demo_extracted.json && echo "✓ Extraction JSON exists"

# Verify it's valid JSON
jq . extraction/output/test_workflow_demo_extracted.json > /dev/null && echo "✓ Valid JSON"

# Check all 22 fields present
jq 'keys | length' extraction/output/test_workflow_demo_extracted.json
# Should output: 22
```

### 2. Redline Completed

```bash
# Check redline report exists
ls redlining/output/*test_workflow_demo*.md

# Check for deviation counts
grep "Deviation counts:" redlining/output/*test_workflow_demo*.md
# Should show: HIGH: X, MED: Y, LOW: Z
```

### 3. GitHub Issue Created

```bash
# List recent contract review issues
gh issue list --search "Contract Review" --limit 3

# View the latest issue
gh issue view <issue_number>

# Check issue contains AI analysis
gh issue view <issue_number> | grep -A 5 "AI Risk Assessment"
```

### 4. Slack Message Posted

**Webhook:**
- Check `#legal-contracts` channel
- Should see basic message with contract summary

**MCP:**
- Run: `scripts/post_to_slack_mcp.sh --type contract --file extraction/output/test_workflow_demo_extracted.json`
- Check Slack for rich formatted message

---

## ✅ Success Checklist

- [ ] GitHub Actions workflow shows "Completed" (green checkmark)
- [ ] All steps show successful (no red X's)
- [ ] Extraction JSON created: `extraction/output/test_workflow_demo_extracted.json`
- [ ] Redline report created: `redlining/output/*test_workflow_demo*.md`
- [ ] GitHub issue created: "Contract Review: test_workflow_demo.txt"
- [ ] Issue body includes AI risk assessment
- [ ] Issue shows extraction completeness (73%)
- [ ] Issue shows deviations (HIGH: 4, MED: 1, LOW: 2)
- [ ] Slack message posted (webhook or MCP)

---

## 🐛 Troubleshooting

### Workflow Shows "Failed"

1. Click the failed step
2. Read the error message
3. Common issues:
   - `claude: command not found` → Missing ANTHROPIC_API_KEY secret
   - `extraction result as JSON` → Claude API error
   - `jq not found` → Dependency installation failed

**Fix:**
```bash
# View full logs
gh run view <run-id> --log | head -200  # First 200 lines
gh run view <run-id> --log | tail -100  # Last 100 lines
```

### GitHub Issue Not Created

```bash
# Check workflow logs for issue creation step
gh run view --step "Create GitHub issues" -L 500

# Verify GitHub token has write access
gh issue list  # Should work if you have permission
```

### Slack Message Not Posted

**If using webhook:**
- Check `SLACK_WEBHOOK_URL` secret is set
- Verify webhook URL is valid
- Check `#legal-contracts` channel exists

**If using MCP:**
```bash
# Test script
scripts/post_to_slack_mcp.sh --type contract \
  --file extraction/output/test_workflow_demo_extracted.json --verbose
```

---

## 📊 Pipeline Output Files

After workflow completes, repository will contain:

```
extraction/
  └── output/
      └── test_workflow_demo_extracted.json    ← 22-field extraction
redlining/
  └── output/
      └── 2026-09-07_redline_report_test_workflow_demo.md  ← Deviation analysis
contracts/
  └── test_workflow_demo.txt                   ← Original contract
```

Plus:
- **GitHub Issue** with full analysis
- **Slack message** (if configured)
- **Workflow run logs** in GitHub Actions

---

## 🎯 Next Steps After Successful Test

1. ✅ Verify all outputs exist
2. ✅ Review GitHub issue quality
3. ✅ Check extraction accuracy (compare to actual contract)
4. ✅ Review AI risk assessment
5. ✅ Optional: Post rich message via MCP
6. ✅ Optional: Add SLACK_WEBHOOK_URL for automation
7. ✅ Optional: Customize Claude prompts for your risk profile

---

## 📞 Support

If anything fails:
1. Check GitHub Actions logs first
2. See troubleshooting section above
3. Check `docs/WORKFLOWS_TEST_GUIDE.md` for detailed guide
4. Check `docs/WORKFLOWS.md` for reference

---

## 🚀 You're Watching a Complete AI Contract Review Pipeline!

The workflow demonstrates:
- ✅ Contract extraction (22-field hotspot schema)
- ✅ Playbook comparison (redline against NDA standard)
- ✅ Claude AI analysis (risk assessment)
- ✅ GitHub issue creation (for tracking)
- ✅ Slack notification (for team awareness)

All happening automatically in ~4 minutes! 🎉

---

**Status:** Workflow running now  
**Expected completion:** 4 minutes from push  
**Monitor at:** https://github.com/sahil1808agg/LegalTeam/actions

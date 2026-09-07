# 🚀 Full Pipeline Test: Live Monitoring

**Test Contract Pushed:** `contracts/test_workflow_demo.txt` (NDA)  
**Status:** WORKFLOW RUNNING NOW 🟢  
**Expected Duration:** 3-4 minutes  
**Time Pushed:** Just now

---

## 📺 Watch Live in Real-Time

### GitHub Actions Dashboard
```
🔗 https://github.com/sahil1808agg/LegalTeam/actions
```

**Steps:**
1. Click "Contract Review Pipeline" (top workflow)
2. Click the latest run (should show "test_workflow_demo")
3. Watch steps complete with green checkmarks ✅

### GitHub CLI
```bash
gh run watch          # Live updates
gh run list --limit 1 # Latest run status
gh run view -L 2000   # Full logs
```

---

## ⏱️ Expected Timeline

| Time | What Happens |
|------|------------|
| 0 min | 🟢 Workflow starts (push detected) |
| 0.5 min | ✅ Dependencies installed |
| 1 min | ✅ New contract detected: test_workflow_demo.txt |
| 1-2 min | 🔄 Extraction running |
| 2-3 min | 🔄 Redline comparison + Claude AI |
| 3-4 min | ✅ GitHub issue created |
| 3.5-4 min | ✅ Slack message posted |
| 4 min | ✅ COMPLETE (green checkmark) |

---

## ✅ Success Checklist

After ~4 minutes, verify all of these:

1. **GitHub Actions**
   - [ ] Workflow shows green checkmark ✅
   - [ ] All steps successful (no red X's)

2. **Extraction Output**
   - [ ] File exists: `extraction/output/test_workflow_demo_extracted.json`
   - [ ] Contains all 22 fields
   ```bash
   jq 'keys | length' extraction/output/test_workflow_demo_extracted.json
   # Should output: 22
   ```

3. **Redline Report**
   - [ ] File exists: `redlining/output/*test_workflow_demo*.md`
   - [ ] Shows deviations (HIGH/MED/LOW)
   ```bash
   grep "Deviation counts:" redlining/output/*test_workflow_demo*.md
   # Should show: HIGH: 4, MED: 1, LOW: 2
   ```

4. **GitHub Issue**
   - [ ] Issue created: "Contract Review: test_workflow_demo.txt"
   - [ ] Issue has labels: `contract-review`, `NDA`
   - [ ] Issue body includes:
     - Contract Details (type, completeness %)
     - AI Risk Assessment (risk rating, key risks)
     - Extraction Results (22-field table)
     - Deviation Analysis (redline table)
   ```bash
   gh issue list --search "Contract Review" --limit 1
   gh issue view <issue_number>
   ```

5. **Slack Message**
   - [ ] Message posted to `#legal-contracts` channel
   - [ ] Shows contract name, type, completeness %
   - [ ] If using MCP: Run script for rich message
   ```bash
   scripts/post_to_slack_mcp.sh --type contract --file extraction/output/test_workflow_demo_extracted.json
   ```

---

## 📋 What to Expect

### GitHub Actions Logs
```
Detect new contracts
  → contracts/test_workflow_demo.txt detected ✓

Process contracts
  → Extraction running...
    ✓ Extracted 22 fields
    ✓ 16/22 fields with values (73%)
    ✓ 2 flagged fields
  → Redline comparison running...
    ✓ Deviations: HIGH: 4, MED: 1, LOW: 2
  → Claude AI analysis...
    ✓ Risk Rating: MEDIUM
    ✓ Key Risks identified
    ✓ Recommendations provided

Create GitHub issues
  → ✓ Issue created: Contract Review: test_workflow_demo.txt
```

### GitHub Issue Content
```
## Contract Details
Type: NDA
Completeness: 73% (16/22)
Flagged Fields: 2
Deviations: HIGH: 4, MED: 1, LOW: 2

## AI Risk Assessment
Overall Risk Rating: MEDIUM
Key Risks:
  • Indefinite confidentiality survival
  • Missing carve-outs for independent development
  • Unclear return/destruction clause

## Extraction Results
[22-field table with values, citations, flags]

## Deviation Analysis
[Clause-by-clause comparison vs NDA playbook]
```

### Slack Message (Webhook)
```
🔍 Contract Review Summary — 1 contracts processed

📋 Contract Review Results

• test_workflow_demo.txt (NDA) — 73% complete
  ├─ Flagged: 2 fields
  └─ Deviations: HIGH: 4, MED: 1, LOW: 2
```

### Slack Message (MCP - Rich)
```
📄 Contract Review: test_workflow_demo.txt (NDA)

Completeness: ███████░░░░ 73% (16/22)
Flagged: 2  |  Risk: 🟡 MEDIUM

⚠️ Key Risks:
  • Indefinite confidentiality survival
  • No explicit carve-outs
  • Unclear destruction clause

✓ Recommended Actions:
  • Review if indefinite survival needed
  • Add standard carve-outs
  • Clarify destruction definition

Deviations: HIGH: 4 | MED: 1 | LOW: 2
```

---

## 🔧 Troubleshooting

### Workflow Shows "Failed"
```bash
# Check the error
gh run view --step "Process contracts" -L 500

# Common errors:
# "claude: command not found" → Missing ANTHROPIC_API_KEY secret
# "extraction result as JSON" → Claude API error
# "jq not found" → Dependency installation failed
```

### GitHub Issue Not Created
```bash
# Check issue creation step
gh run view --step "Create GitHub issues" -L 500

# Verify you can create issues
gh issue list
```

### Slack Message Not Posted
- **Webhook:** Check `SLACK_WEBHOOK_URL` secret is set
- **MCP:** Run: `scripts/post_to_slack_mcp.sh --type contract --file extraction/output/test_workflow_demo_extracted.json --verbose`

---

## 📚 Detailed Guide

For complete step-by-step monitoring with troubleshooting:
→ `docs/PIPELINE_TEST_MONITOR.md`

---

## 🎯 Next Steps (After Test Passes)

1. ✅ Verify all outputs (see checklist above)
2. ✅ Review GitHub issue quality and accuracy
3. ✅ Check extraction against actual contract
4. ✅ Review AI risk assessment
5. ⏭️ Optional: Add SLACK_WEBHOOK_URL for automation
6. ⏭️ Optional: Customize Claude prompts for your risk profile
7. ⏭️ Optional: Push real contracts to test with production data

---

## 🚀 Ready?

**Monitor at:** https://github.com/sahil1808agg/LegalTeam/actions

**Watch for:** Contract Review Pipeline → Latest run → Green checkmark ✅

**Expected:** ~3-4 minutes from push

Go! 🎉

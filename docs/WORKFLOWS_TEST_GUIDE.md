# Workflow Testing Guide

Test pushed! Contract Review Pipeline is now running. Follow this guide to verify the full pipeline execution.

---

## 📋 What Should Happen (Expected Timeline)

### Immediately (Next 30 seconds)
- ✅ GitHub Actions tab shows workflow starting
- ✅ Status: "In progress" (yellow dot)

### Minutes 1-2
- ✅ Step: "Detect new contracts" completes
- ✅ Shows test contract file detected
- ✅ Step: "Install Claude Code CLI" runs

### Minutes 2-3
- ✅ Step: "Process contracts" runs
- ✅ Extraction starts (creates JSON in extraction/output/)
- ✅ Redline comparison starts (compares vs playbook)
- ✅ Claude AI analysis invoked

### Minutes 3-4
- ✅ GitHub issues created with full analysis
- ✅ Slack notification prepared (status will show result)

### Final
- ✅ Workflow status: "Completed" (green checkmark)
- ✅ All artifacts generated

---

## 🔍 How to Monitor

### Option 1: GitHub Web UI (Easiest)

1. Go to: https://github.com/sahil1808agg/LegalTeam/actions
2. Click "Contract Review Pipeline" workflow
3. Click the latest run (should be at top)
4. Watch each step complete in real-time
5. Click each step to see detailed logs

### Option 2: GitHub CLI

```bash
# List recent runs
gh run list --limit 3

# Watch latest run in real-time
gh run watch

# View detailed logs for latest run
gh run view -L 1000  # 1000 lines of output

# View specific step
gh run view --step "Process contracts" -L 500
```

### Option 3: Local Verification

```bash
# After workflow completes, check outputs
ls -la extraction/output/test_nimbusforge_msa_extracted.json
ls -la redlining/output/*nimbusforge*.md
git log --oneline | grep "Contract Review" # GitHub issue link
```

---

## ✅ Expected Outputs

### 1. Extraction JSON

**Location:** `extraction/output/test_nimbusforge_msa_extracted.json`

Should contain:
```json
{
  "contract_type": {
    "value": "MSA",
    "citation": {"paragraph_number": "...", "excerpt": "..."},
    "flag": null
  },
  "counterparty_name": {
    "value": "Quarrystone Logistics Group LLC",
    "citation": {...},
    "flag": null
  },
  // ... 20 more fields (term_length, payment_terms, liability_cap, etc.)
}
```

**Verify:**
- All 22 fields present (even if value is null)
- Each field has: `value`, `citation`, `flag`
- Non-null values include source citations
- Flagged fields have `type` and `reason`

### 2. Redline Report

**Location:** `redlining/output/YYYY-MM-DD_redline_report_test_nimbusforge_msa.md`

Should contain:
```markdown
# Redline Report

**Incoming contract:** contracts/test_nimbusforge_msa.txt
**Playbook:** redlining/playbooks/msa_playbook.md
**Generated:** 2026-09-07

| # | Clause | Standard Position | Counterparty Position | Deviation | Risk Level | Recommended Response |
|---|---|---|---|---|---|---|
| 1 | Liability Cap | ... | Client's cap at 1 month... | YES | HIGH | Counter with 2x annual fees... |
| 2 | IP Ownership | ... | Provider retains sole ownership... | YES | HIGH | Reject; counter for Client ownership... |
| ... | ... | ... | ... | ... | ... | ... |

## Summary

- **HIGH Deviations:** 11+ items needing attention
  - Liability cap one-sided and capped low
  - IP ownership retained by Provider (floor violation)
  - Termination for convenience one-sided
  - ... (more high-risk deviations)
```

**Verify:**
- Table with all ~15 clauses from playbook
- Deviation counts in footer (HIGH: X, MED: Y, LOW: Z)
- Each row cites specific sections
- Summary highlights top HIGH risks

### 3. GitHub Issue

**Title:** `Contract Review: test_nimbusforge_msa.txt`

**Body should include:**

```markdown
## 📋 Contract Details

| Field | Value |
|---|---|
| **Filename** | test_nimbusforge_msa.txt |
| **Type** | MSA |
| **Extraction Completeness** | 82% (18/22 fields) |
| **Flagged Fields** | 2 |
| **Deviations** | HIGH: 11, MED: 2, LOW: 2 |

## ⚠️ AI Risk Assessment

**Overall Risk Rating:** HIGH

### Key Risks
- Liability cap of 1x monthly fees (below 2x minimum)
- Unilateral indemnification with no cap
- One-sided termination for convenience clause
- IP assignment favors counterparty

### Recommended Actions
- Negotiate liability cap to 2x trailing-12-month fees
- Make indemnification mutual with cap at liability limit
- Require mutual termination for convenience rights
- Change IP ownership to Client with license-back

### Liability Exposure
Uncapped indemnification coupled with IP retained by Provider creates significant financial exposure. Client bears all third-party claim costs plus loss of custom IP developed for $216k annually ($18k/mo × 12).

## 📊 Extraction Results

| Field | Value | Citation | Flag |
|---|---|---|---|
| contract_type | MSA | Section 1 | ✓ |
| counterparty_name | Quarrystone Logistics... | Section 1 | ✓ |
| effective_date | 2026-08-20 | Section 1 | ✓ |
| ...

## 🔄 Deviation Analysis

| # | Clause | Standard | Counterparty | Deviation | Risk | Recommendation |
|---|---|---|---|---|---|---|
| 1 | Liability Cap | Mutual 2x | Client 1x; Provider uncapped | YES | HIGH | Reject unilateral; counter mutual 2x |
| ... | ... | ... | ... | ... | ... | ... |
```

**Verify:**
- Issue links to the specific contract pushed
- AI analysis includes risk rating and key findings
- Extraction table shows all 22 fields
- Deviation table matches redline report

### 4. Slack Notification (When MCP Integrated)

Expected format:
```
🔔 Renewal Deadlines — 5 contracts due in next 90 days

Channel: #legal-contracts
Attachments:
- Contract summary with completeness %
- AI risk assessment
- Recommended actions
- Link to GitHub issue
```

---

## 🛠️ Troubleshooting

### Issue: Workflow Marked as "Failed"

**Check these in order:**

1. **Look at workflow logs** (GitHub Actions tab → click workflow → step logs)

2. **Common Errors:**

```
Error: claude CLI not found
→ ANTHROPIC_API_KEY secret not set
→ Fix: Go to Settings → Secrets → Add ANTHROPIC_API_KEY

Error: PDF chunking failed
→ Test contract is PDF without text layer
→ Fix: Use .txt files for testing

Error: jq not found
→ Dependencies not installed properly
→ Fix: Check "Install dependencies" step logs

Error: File not found: extraction/output/...
→ Extraction step failed silently
→ Check previous step for errors

Error: extraction result as JSON
→ Claude response not properly formatted
→ Check Claude API is accessible
```

3. **Check full log output:**

```bash
# View complete workflow log
gh run view <run-id> --log | head -200  # First 200 lines
gh run view <run-id> --log | tail -200  # Last 200 lines
```

### Issue: Extraction Not Running

**Verify:**
```bash
# Check file was detected
git diff HEAD~1 --name-only | grep "contracts/"

# Check contract path is correct
ls -la contracts/test_nimbusforge_msa.txt

# Check file is .txt not .pdf
file contracts/test_nimbusforge_msa.txt
# Should output: "text file" not "PDF"
```

### Issue: No GitHub Issue Created

**Check:**
1. Extraction succeeded (look for extraction/output/*.json)
2. GitHub token has `issues: write` permission
3. Repository has issues enabled
4. Check workflow logs for issue creation step

```bash
# Search for "Creating issue" in logs
gh run view <run-id> --log | grep -i "issue"
```

### Issue: Slack Message Not Posting

**Note:** Currently Slack requires MCP integration or webhook setup. The workflow prepares the message but doesn't post without additional configuration.

**To enable Slack:**
1. Set `SLACK_WEBHOOK_URL` secret, OR
2. Wait for MCP support in GitHub Actions, OR
3. Use GitHub Actions Slack integration app

See `docs/WORKFLOWS_SETUP.md` for integration options.

---

## 📊 Performance Metrics

Expected timing for test contract:
- Detect: ~5 seconds
- Extract: ~30-45 seconds
- Redline: ~30-45 seconds
- AI Analysis: ~30-60 seconds
- Issue Creation: ~10-15 seconds
- **Total: 2-4 minutes**

Logs show step-by-step progress:
```
→ Running extraction...
→ Running redline comparison...
→ AI Risk Assessment...
✓ Extraction: 18/22 fields
✓ Deviations: HIGH: 11, MED: 2, LOW: 2
✓ Risk Assessment: HIGH
✓ Issue created
```

---

## 🎯 Success Criteria

Workflow successfully ran if ALL of these exist:

- [ ] GitHub issue created with title "Contract Review: test_nimbusforge_msa.txt"
- [ ] Issue body includes AI risk assessment section
- [ ] `extraction/output/test_nimbusforge_msa_extracted.json` exists and has 22 fields
- [ ] `redlining/output/` contains redline report markdown
- [ ] Workflow status is "Completed" (green checkmark)
- [ ] No "failed" steps in action logs
- [ ] Claude analysis provided risk rating (HIGH/MEDIUM/LOW/CRITICAL)

---

## 🔍 Validation Checklist

After workflow completes, verify:

```bash
# 1. Check extraction JSON exists and is valid
jq . extraction/output/test_nimbusforge_msa_extracted.json | wc -l
# Should output 300+ lines (full 22-field structure)

# 2. Check all 22 fields present
jq 'keys | length' extraction/output/test_nimbusforge_msa_extracted.json
# Should output: 22

# 3. Check redline report exists
ls -la redlining/output/*nimbusforge*.md
# Should show file created today

# 4. Check redline has deviation counts
grep "Deviation counts:" redlining/output/*nimbusforge*.md
# Should show: HIGH: X, MED: Y, LOW: Z

# 5. Verify GitHub issue via CLI
gh issue list --search "Contract Review" --limit 1
# Should show recent issue created
```

---

## 📝 Next Steps After Successful Test

1. ✅ **Celebrate!** — Full pipeline working end-to-end
2. ✅ **Set SLACK_WEBHOOK_URL secret** for Slack notifications (optional)
3. ✅ **Push real contracts** to `contracts/` to test with actual data
4. ✅ **Review GitHub issues** created to verify analysis quality
5. ✅ **Test daily renewal workflow** (manual trigger or wait until tomorrow)
6. ✅ **Monitor first week** of production runs
7. ✅ **Tune Claude analysis prompts** if needed for your legal risk profile

---

## 📞 Support

If workflow fails:

1. **Check logs** first (always in GitHub Actions tab)
2. **Verify secrets** are set (Settings → Secrets)
3. **Review troubleshooting** section above
4. **Check Claude API** status at https://status.anthropic.com
5. **Verify contract format** (.txt files, valid markdown)

See `docs/WORKFLOWS.md` for complete reference documentation.

---

**Test Contract:** `contracts/test_nimbusforge_msa.txt`  
**Expected to complete:** ~3 minutes from push  
**Status:** Watch at https://github.com/sahil1808agg/LegalTeam/actions  

Good luck! 🚀

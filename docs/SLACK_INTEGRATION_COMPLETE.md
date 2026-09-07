# Complete Slack Integration Guide

Three ways to post contract reviews and renewal digests to Slack.

---

## Overview

| Method | Setup | Formatting | Automation | Best For |
|--------|-------|-----------|-----------|----------|
| **Webhook** | 2 min | Basic | GitHub Actions native | Quick CI/CD integration |
| **MCP** | 1 min | Rich | Local runner | Beautiful messages, full control |
| **GitHub App** | 5 min | Basic | Native to GitHub | Tight GitHub/Slack integration |

**Our Recommendation:** Use **MCP for manual posting** + **Webhook as fallback**

---

## Method 1: Slack MCP (Rich Messages) ⭐ RECOMMENDED

Post rich, formatted messages using Claude Code Slack MCP.

### Setup (1 minute)

```bash
# Just needs Claude Code with Slack MCP enabled
# Check: .claude/settings.json has "slack@anthropic-tools" configured
```

### Usage

```bash
# Post contract review
scripts/post_to_slack_mcp.sh --type contract --file extraction/output/contract.json

# Post renewal digest
scripts/post_to_slack_mcp.sh --type renewals --file renewal-reports/renewals.json

# With verbose output
scripts/post_to_slack_mcp.sh --type contract --file extraction/output/contract.json --verbose
```

### How It Works

```
1. You run local script
2. Script calls Claude: claude -p "Post to Slack..." --allowedTools "mcp__claude_ai_Slack__slack_send_message"
3. Claude formats message with Slack MCP
4. MCP posts rich message to #legal-contracts
```

### Example Message

```
📋 Contract Review: nimbusforge_msa.txt (MSA)

Completeness: ████████░░ 82% (18/22)
Flagged: 2  |  Risk: 🔴 HIGH

⚠️ Key Risks:
  • Liability cap at 1x monthly (floor violation)
  • Unilateral indemnification with no cap
  • One-sided termination rights

✓ Recommended Actions:
  • Negotiate to 2x annual fees
  • Make indemnification mutual
  • Require mutual termination
```

### Advantages

✅ Beautiful formatting with emoji  
✅ Full Slack API access  
✅ Customizable prompt  
✅ No webhook secrets to manage  
✅ Works locally with Claude Code  
✅ Complete control over message format  

### Limitations

❌ Requires Claude Code running locally  
❌ Can't be automated in GitHub Actions (yet)  
❌ Manual trigger required  

### Documentation

→ `docs/SLACK_MCP_SETUP.md` (complete guide)  
→ `scripts/post_to_slack_mcp.sh` (implementation)

---

## Method 2: Slack Webhook (Simple Automation) ⚡ FALLBACK

Post simple messages directly from GitHub Actions using webhook.

### Setup (2 minutes)

**Step 1:** Get Slack webhook URL
```bash
https://api.slack.com/apps
# Create new app → Incoming Webhooks → Select #legal-contracts
# Copy webhook URL (https://hooks.slack.com/services/...)
```

**Step 2:** Add GitHub secret
```bash
Settings → Secrets and variables → Actions
Name: SLACK_WEBHOOK_URL
Value: [paste webhook URL]
```

### Usage

Automatic! Workflows check for the secret and post when available.

After contract review completes:
- ✅ GitHub issue created
- ✅ If SLACK_WEBHOOK_URL set → Slack message posted

After renewal scan:
- ✅ Daily artifact saved
- ✅ If SLACK_WEBHOOK_URL set → Slack digest posted

### Example Message

```
🔍 Contract Review Summary — 1 contracts processed

📋 Contract Review Results

• test_nimbusforge_msa.txt (MSA) — 82% complete
  ├─ Flagged: 2 fields
  └─ Deviations: HIGH: 11, MED: 2, LOW: 2
```

### Advantages

✅ Fully automated in GitHub Actions  
✅ No manual steps required  
✅ Works in CI/CD pipeline  
✅ Simple curl POST  
✅ Reliable  

### Limitations

❌ Basic formatting (just text)  
❌ No emoji or rich formatting  
❌ No interactive elements  
❌ Requires webhook URL secret management  
❌ Limited customization  

### Documentation

→ `docs/SLACK_SETUP.md` (webhook setup guide)

---

## Method 3: GitHub Slack App (Official)

Use official GitHub app to post workflow updates to Slack.

### Setup (5 minutes)

```bash
# Install GitHub app
https://github.com/apps/github/

# In workflow YAML:
- uses: slackapi/slack-github-action@v1
  with:
    channel-id: ${{ secrets.SLACK_CHANNEL_ID }}
    slack-message: "Message text"
```

### Advantages

✅ Official GitHub + Slack integration  
✅ Native GitHub Actions support  
✅ Workflow status updates  
✅ Pull request notifications  

### Limitations

❌ Limited customization  
❌ More GitHub-focused than legal-focused  
❌ Requires app installation  

---

## Recommended Approach: Use Both!

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Workflow Runs                      │
└─────────────────────────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────────────────────┐
│         ✅ GitHub Issue Created (Always)                     │
│         ✅ Artifacts Saved (Always)                          │
│         ✅ Slack via Webhook (If secret set)                │
└─────────────────────────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────────────────────┐
│    You Read Issue + Want Rich Slack Message?                │
│    Run Locally (When MCP Available):                         │
│                                                               │
│    scripts/post_to_slack_mcp.sh --type contract \           │
│      --file extraction/output/latest.json                   │
└─────────────────────────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────────────────────┐
│    ✅ Beautiful, Rich Message Posted to Slack               │
└─────────────────────────────────────────────────────────────┘
```

**Result:**
- ✅ Guaranteed GitHub issue always created
- ✅ Basic Slack notification via webhook (if configured)
- ✅ Rich Slack message via MCP (if you want it)
- ✅ Best of all worlds!

---

## Comparison Table

| Feature | Webhook | MCP | GitHub App |
|---------|---------|-----|-----------|
| **Automation** | ✅ GitHub Actions native | ❌ Local only | ✅ Native |
| **Rich Formatting** | ❌ Text only | ✅ Blocks, emoji, colors | ❌ Basic |
| **Setup Time** | 2 min | 1 min | 5 min |
| **Customization** | ❌ Limited | ✅ Full | ❌ Limited |
| **Manual Posting** | ❌ No | ✅ Yes | ❌ No |
| **GitHub Integration** | ❌ No | ❌ No | ✅ Tight |
| **Cost** | Free | Free | Free |

---

## Implementation Status

### ✅ Completed

- [x] Contract Review Pipeline (GitHub Actions)
- [x] Daily Renewal Deadlines (GitHub Actions)
- [x] Extraction + Redline + Claude AI
- [x] GitHub Issues Creation
- [x] Slack Webhook Support (Method 2)
- [x] Slack MCP Support (Method 1)
- [x] Documentation for all methods

### 📋 Ready to Use

- [x] `scripts/post_to_slack_mcp.sh` — MCP posting script
- [x] `.github/workflows/contract_review.yml` — Webhook support
- [x] `.github/workflows/daily_renewals.yml` — Webhook support
- [x] Documentation guides for all methods

### 🚀 Next Steps (User)

1. **Try MCP First** (rich messages):
   ```bash
   scripts/post_to_slack_mcp.sh --type contract --file extraction/output/latest.json --verbose
   ```

2. **Optional: Add Webhook** (automated fallback):
   ```bash
   # Add SLACK_WEBHOOK_URL secret to GitHub
   # Workflows will auto-post if set
   ```

3. **Optional: Add GitHub App** (workflow updates):
   ```bash
   # Install GitHub app for additional workflow notifications
   ```

---

## Workflows: Where Slack Posts

### Contract Review Workflow

**Saves:**
- Extraction JSON → `extraction/output/`
- Redline report → `redlining/output/`
- GitHub issue (always)

**Slack Posts (if configured):**
- Webhook: Summary of extraction + deviations
- MCP: (you run locally) Rich formatted review

### Daily Renewal Workflow

**Saves:**
- Daily digest JSON → `renewal-reports/`
- Daily artifact (always)

**Slack Posts (if configured):**
- Webhook: Deadline summary
- MCP: (you run locally) Rich formatted digest

---

## Troubleshooting

### Webhook Not Posting

```bash
# Check secret is set
gh secret list | grep SLACK_WEBHOOK_URL

# Test webhook manually
curl -X POST -H 'Content-type: application/json' \
  -d '{"text":"Test"}' \
  YOUR_WEBHOOK_URL
```

### MCP Not Working

```bash
# Verify Claude Code is running
claude --version

# Verify Slack MCP is enabled
cat .claude/settings.json | grep -A 5 slack

# Test MCP directly
scripts/post_to_slack_mcp.sh --type contract --file extraction/output/test.json --verbose
```

### GitHub App Issues

```bash
# Check app is installed
https://github.com/apps/github/

# Verify channel ID in secrets
gh secret list | grep SLACK_CHANNEL_ID
```

---

## Customization

### Webhook Messages

Edit workflows to customize:
- `.github/workflows/contract_review.yml` (line ~349)
- `.github/workflows/daily_renewals.yml` (line ~290)

Add more fields, emoji, formatting to the jq command.

### MCP Messages

Edit script to customize:
- `scripts/post_to_slack_mcp.sh` (lines ~50-80)

Modify `build_contract_message_prompt()` or `build_renewals_message_prompt()` functions.

---

## FAQ

**Q: Which should I use?**  
A: Start with **MCP** for beautiful messages. Add **Webhook** if you want automation.

**Q: Can I use both?**  
A: Yes! Webhook will auto-post basic message. You manually post rich message via MCP.

**Q: Do I need to set up Slack app?**  
A: No, MCP + Webhook work fine alone. GitHub App is optional.

**Q: Will Slack be updated automatically?**  
A: Only with Webhook. MCP requires you to run script manually.

**Q: Can I schedule MCP posting?**  
A: Yes - create a cron job to run the script daily.

**Q: What if I don't want Slack?**  
A: GitHub issues are always created. You can ignore Slack entirely.

---

## Summary

| Method | When to Use |
|--------|-----------|
| **MCP** | You want beautiful, rich messages right now. You have Claude Code with MCP. |
| **Webhook** | You want automated messages from workflows. You're okay with simple formatting. |
| **Both** | You want both automated basic messages AND manual rich messages. (Recommended) |
| **GitHub App** | You want tight GitHub ↔ Slack integration for workflow status. |
| **None** | GitHub issues only. No Slack notifications. (Still works fine) |

---

## Getting Started

**Option 1: Just MCP** (Recommended for MVP)
```bash
# After workflow completes
scripts/post_to_slack_mcp.sh --type contract --file extraction/output/latest.json
```

**Option 2: Just Webhook** (Recommended for automation)
```bash
# Add SLACK_WEBHOOK_URL secret to GitHub
# Workflows auto-post
```

**Option 3: Both** (Recommended for production)
```bash
# Add SLACK_WEBHOOK_URL secret (auto-post basic messages)
# Use MCP script locally (post rich messages when needed)
```

---

## Documentation Files

- `docs/SLACK_MCP_SETUP.md` — Complete MCP guide
- `docs/SLACK_SETUP.md` — Complete Webhook guide  
- `scripts/post_to_slack_mcp.sh` — MCP script implementation
- `.github/workflows/contract_review.yml` — Webhook support
- `.github/workflows/daily_renewals.yml` — Webhook support

---

**Ready?** Pick your method above and follow the setup instructions! 🚀

Or mix and match for maximum flexibility. All three methods work together perfectly.

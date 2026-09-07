# Slack Integration Setup

The workflows now support **Slack webhook integration**. When you add the `SLACK_WEBHOOK_URL` secret, workflow messages will post automatically to your Slack workspace.

---

## Quick Setup (2 minutes)

### Step 1: Get Slack Webhook URL

1. Go to your Slack workspace: https://api.slack.com/apps
2. Click "Create New App" → "From scratch"
   - App name: `ContractIQ`
   - Workspace: Select your workspace
3. Go to "Incoming Webhooks" (left sidebar)
4. Click "Add New Webhook to Workspace"
5. Select channel: `#legal-contracts` (or create it)
6. Click "Allow"
7. **Copy the Webhook URL** (starts with `https://hooks.slack.com/services/...`)

### Step 2: Add GitHub Secret

1. Go to: https://github.com/sahil1808agg/LegalTeam/settings/secrets/actions
2. Click "New repository secret"
3. Name: `SLACK_WEBHOOK_URL`
4. Value: Paste the webhook URL from Step 1
5. Click "Add secret"

### Step 3: Test

Push a contract or manually trigger the renewal workflow:

```bash
# Push a new contract to trigger contract review
git push origin main

# Or manually trigger daily renewals
gh workflow run daily_renewals.yml
```

Watch Slack for message:
```
🔍 Contract Review Summary — 1 contracts processed

📋 Contract Review Results

• test_nimbusforge_msa.txt (MSA) — 82% complete
  ├─ Flagged: 2 fields
  └─ Deviations: HIGH: 11, MED: 2, LOW: 2
```

---

## What Gets Posted

### Contract Review Pipeline

**To:** `#legal-contracts` (or your configured channel)

**Message includes:**
- Contract filename and type
- Extraction completeness %
- Number of flagged fields
- Deviation summary (HIGH/MED/LOW counts)

**Appears:** ~3-4 minutes after push

### Daily Renewal Deadlines

**To:** `#legal-contracts`

**Message includes:**
- AI summary of renewal situation
- Critical actions needed
- Critical/Urgent contracts list
- Auto-renewal warnings
- Process improvement suggestions

**Appears:** Daily 9am PT (or manually triggered)

---

## Troubleshooting

### Message Not Posting

**Check #1: Secret is set**
```bash
# Verify secret exists
gh secret list | grep SLACK_WEBHOOK_URL
# Should output: SLACK_WEBHOOK_URL
```

**Check #2: Webhook URL is valid**
- Test it manually:
```bash
curl -X POST -H 'Content-type: application/json' \
  -d '{"text":"Test message"}' \
  YOUR_WEBHOOK_URL
```

**Check #3: Workflow logs**
- Go to GitHub Actions → Click workflow run
- Look for "Post to Slack via Webhook" step
- Check for error messages

### Common Errors

| Error | Fix |
|-------|-----|
| `curl: (3) URL rejected` | Webhook URL syntax error — check for copy/paste issues |
| `404 Not Found` | Webhook URL is expired — regenerate from Slack |
| `Missing scope` | Reinstall app to workspace with current permissions |
| `Channel not found` | Webhook is for wrong channel — recreate for `#legal-contracts` |

---

## Advanced Options

### Option A: Custom Channel

Create workflow for different channel:

```yaml
- name: Post to Slack
  run: |
    curl -X POST -H 'Content-type: application/json' \
      --data '{"channel":"#your-channel","text":"..."}' \
      ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Option B: Slack App (Advanced)

Instead of webhook, use official Slack GitHub app:

1. Install GitHub app to your Slack: https://github.com/apps/github/
2. Subscribe to workflow runs
3. Set annotations in workflow:
```yaml
- uses: slackapi/slack-github-action@v1
  with:
    channel-id: ${{ secrets.SLACK_CHANNEL_ID }}
    slack-message: "Your message"
```

### Option C: MCP Integration (Future)

When Claude Code MCP is available in GitHub Actions:

```yaml
- name: Post to Slack via MCP
  run: |
    echo "$SLACK_MESSAGE" | \
    mcp__claude_ai_Slack__slack_send_message \
      --channel "#legal-contracts"
```

---

## Channel Setup (Optional)

If you don't have `#legal-contracts` channel yet:

1. In Slack, click "+" next to "Channels"
2. Name: `legal-contracts`
3. Description: `Contract review automation & renewal deadlines`
4. Privacy: Public (or Private if preferred)
5. Click "Create"

---

## Slack Message Examples

### Contract Review Posted

```
🔍 Contract Review Summary — 1 contracts processed

📋 Contract Review Results

• test_nimbusforge_msa.txt (MSA) — 82% complete
  ├─ Flagged: 2 fields
  └─ Deviations: HIGH: 11, MED: 2, LOW: 2

• important_agreement.txt (NDA) — 90% complete
  ├─ Flagged: 1 field
  └─ Deviations: HIGH: 2, MED: 1, LOW: 0
```

### Renewal Deadlines Posted

```
🔔 Renewal Deadlines — 5 contracts due in next 90 days

Critical (Due ≤14 days)
• Acme Corp (MSA): 2025-11-15
• Beta Inc (NDA): 2025-11-20

Urgent (Due 15-30 days)
• Gamma Ltd: 2025-12-01

Auto-Renewing Contracts
⚠️ Acme Corp — renews unless notice filed by 2025-11-15
```

---

## FAQ

**Q: Can I send to multiple channels?**  
A: Create multiple webhooks (one per channel) and add multiple secrets.

**Q: Can I customize the message format?**  
A: Yes — edit the workflow to modify the message. Update the jq formatting in the "Prepare Slack notification" step.

**Q: Will old messages get updated?**  
A: No — each run posts a new message. To update messages, use Slack API (more complex).

**Q: Can I post to a private channel?**  
A: Yes — if the webhook is generated for a private channel, it will post there.

**Q: What if I don't want Slack?**  
A: Leave `SLACK_WEBHOOK_URL` unset. The workflows will skip Slack posting and still create GitHub issues.

---

## Disabling Slack

To stop posting to Slack without removing the secret:

**Option 1:** Remove the secret
```bash
gh secret delete SLACK_WEBHOOK_URL
```

**Option 2:** Edit workflow to remove Slack step
```yaml
- name: Post to Slack via Webhook
  if: 'false'  # Disable this step
  ...
```

---

## Status

- [x] Workflows updated with Slack webhook support
- [x] Contract review posts contract summaries
- [x] Daily renewals posts deadline digest
- [ ] User adds SLACK_WEBHOOK_URL secret
- [ ] First message appears in Slack
- [ ] Optional: Customize message format

---

**Ready?** Add the secret and push a test contract! Message should appear in Slack ~3 minutes later. 🚀

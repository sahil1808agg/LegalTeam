# Slack MCP Integration Guide

Use Slack MCP (Model Context Protocol) to post rich, formatted messages from your workflows. This guide explains how to set up Claude Code with Slack MCP.

---

## Why Slack MCP?

**Webhook approach** (previous):
- Simple curl POST
- Limited formatting
- No interactive elements
- No emoji reactions or threads

**MCP approach** (this guide):
- ✅ Rich formatted messages
- ✅ Interactive Slack blocks
- ✅ Reactions, threads, mentions
- ✅ Programmatic control via Claude
- ✅ Full Slack API access
- ✅ Works with Claude Code locally

---

## Architecture

```
GitHub Actions Workflow
    ↓
Saves output: extraction/output/*.json
    ↓
Your Local Machine (Claude Code)
    ↓
Reads output files
    ↓
Claude AI + Slack MCP
    ↓
Posts to #legal-contracts
```

**Key point:** Workflows save data. You post via Claude Code locally.

---

## Setup (3 Steps)

### Step 1: Verify Slack MCP Available

Check that Slack MCP is configured in Claude Code:

```bash
# In Claude Code settings, confirm Slack MCP is enabled:
# Settings → MCP Servers → Slack (should show connected)

# Or check in terminal:
claude --version
# Should show: claude with MCP support enabled
```

### Step 2: Make Scripts Executable

```bash
chmod +x scripts/post_to_slack_mcp.sh
```

### Step 3: Post Contract Review

After a contract review workflow completes:

```bash
# Get the latest extraction JSON
ls -la extraction/output/*_extracted.json | tail -1

# Post to Slack
scripts/post_to_slack_mcp.sh \
  --type contract \
  --file extraction/output/test_nimbusforge_msa_extracted.json \
  --channel "#legal-contracts"

# With verbose output
scripts/post_to_slack_mcp.sh \
  --type contract \
  --file extraction/output/test_nimbusforge_msa_extracted.json \
  --verbose
```

---

## Usage Examples

### Post Contract Review

```bash
scripts/post_to_slack_mcp.sh --type contract --file extraction/output/contract_extracted.json
```

**Posts to Slack:**
```
📋 Contract Review: test_nimbusforge_msa.txt (MSA)

Completeness: ████████░░ 82% (18/22 fields)
Flagged Fields: 2
Risk Rating: 🔴 HIGH

Key Risks:
⚠️ Liability cap at 1x monthly (below 2x minimum)
⚠️ Unilateral indemnification with no cap
⚠️ One-sided termination rights

Recommended Actions:
✓ Negotiate cap to 2x trailing-12-month fees
✓ Make indemnification mutual
✓ Require mutual termination rights

Deviations: HIGH: 11 | MED: 2 | LOW: 2
```

### Post Renewal Digest

```bash
scripts/post_to_slack_mcp.sh --type renewals --file renewal-reports/renewals_2026-09-07.json
```

**Posts to Slack:**
```
🔔 Renewal Deadlines — 5 contracts due in next 90 days

⏰ CRITICAL (Due ≤14 days)
• Acme Corp (MSA) — 2025-11-15 (7 days left)
• Beta Inc (NDA) — 2025-11-20 (12 days left)

⚠️ URGENT (Due 15-30 days)  
• Gamma LLC (SOW) — 2025-12-01 (23 days)

🔄 Auto-Renewing (File notice if no renewal desired)
• Acme Corp — 2025-11-15
• Beta Inc — 2025-11-20
```

### Custom Channel

```bash
scripts/post_to_slack_mcp.sh \
  --type contract \
  --file extraction/output/contract_extracted.json \
  --channel "#legal-team"  # Custom channel
```

---

## How It Works

### The Script Does:

1. **Reads your JSON file** (contract or renewals data)
2. **Creates a prompt** that describes what to post
3. **Calls Claude** with Slack MCP access:
   ```
   claude -p "Post this to Slack..." --allowedTools "Read,mcp__claude_ai_Slack__slack_send_message"
   ```
4. **Claude formats the message** with Slack blocks, emoji, etc.
5. **Claude posts to Slack** using MCP
6. **Script confirms** message was sent

### MCP Tools Used:

```
mcp__claude_ai_Slack__slack_send_message
- Sends message to channel
- Supports rich formatting (blocks, emoji, mentions)
- Returns success/failure status
```

---

## Integration with Workflows

### Option A: Auto-Post After Workflow (Requires Always-On Service)

Set up a GitHub Actions webhook to trigger local posting:
1. Workflow completes, saves output file
2. Webhook triggers local process
3. Local Claude Code posts to Slack

*This requires a service running locally that listens for webhooks.*

### Option B: Manual Post (Recommended for MVP)

```bash
# After workflow completes, manually post:
scripts/post_to_slack_mcp.sh --type contract --file extraction/output/latest.json
```

Simple and works immediately.

### Option C: Scheduled Digest

Create a cron job to post daily:

```bash
# In crontab:
0 9 * * * cd /path/to/repo && bash scripts/daily_slack_digest.sh
```

---

## Troubleshooting

### Script Not Found

```
Error: scripts/post_to_slack_mcp.sh: command not found
```

**Fix:**
```bash
chmod +x scripts/post_to_slack_mcp.sh
ls -la scripts/post_to_slack_mcp.sh  # Verify executable
```

### Claude CLI Not Found

```
Error: claude CLI not found
```

**Fix:**
```bash
# Install/update Claude Code
curl -sSL https://claude.ai/install.sh | bash
claude --version
```

### Slack MCP Not Available

```
Error: mcp__claude_ai_Slack__slack_send_message not recognized
```

**Fix:**
1. Verify Claude Code settings have Slack MCP enabled
2. Check `.claude/settings.json`:
   ```json
   {
     "enableAllProjectMcpServers": true,
     "pluginConfigs": {
       "slack@anthropic-tools": { ... }
     }
   }
   ```
3. Restart Claude Code

### File Not Found

```
Error: file not found: extraction/output/contract_extracted.json
```

**Fix:**
```bash
# List available files
ls extraction/output/
# Use correct path in command
```

### Message Not Posted

```
⚠️ Unclear result - check logs above
```

**Debug:**
```bash
# Run with verbose flag to see Claude output
scripts/post_to_slack_mcp.sh --type contract --file extraction/output/contract.json --verbose

# Or test MCP directly:
claude -p "Test Slack MCP by posting 'Test' to #legal-contracts" \
  --allowedTools "mcp__claude_ai_Slack__slack_send_message"
```

---

## Message Customization

### Edit Contract Message Format

Edit `scripts/post_to_slack_mcp.sh`:

```bash
# Find this section:
build_contract_message_prompt() {
  cat <<'PROMPT_EOF'
# Modify the format here (emoji, sections, emphasis, etc.)
...
PROMPT_EOF
}
```

Suggestions:
- Add more emoji for visual interest
- Change emoji based on risk level
- Add GitHub issue links
- Include extraction completeness bar

### Edit Renewals Message Format

Similarly, modify the `build_renewals_message_prompt()` function to customize renewal digest appearance.

---

## Advanced: Direct MCP Usage

For custom messages, call Claude directly:

```bash
claude -p "Post this to Slack #legal-contracts: [your message]" \
  --allowedTools "mcp__claude_ai_Slack__slack_send_message"
```

Claude will:
1. Understand your message
2. Format it nicely with blocks/emoji
3. Post to Slack
4. Report success/failure

---

## Workflow Integration (Future)

When GitHub Actions gains full MCP support, workflows will be able to post directly:

```yaml
- name: Post to Slack
  run: |
    scripts/post_to_slack_mcp.sh \
      --type contract \
      --file extraction/output/${{ env.CONTRACT_STEM }}_extracted.json
```

For now, this requires Claude Code running locally.

---

## Comparison: Webhook vs MCP

| Feature | Webhook | MCP |
|---------|---------|-----|
| Setup | 2 minutes | 1 minute |
| Formatting | Basic curl JSON | Rich Slack blocks |
| GitHub Actions | ✅ Native support | ❌ Requires local runner |
| Interactive | ❌ No | ✅ Yes (threads, reactions) |
| Local posting | ❌ No | ✅ Yes |
| Complexity | Simple | Moderate |
| Cost | Free | Free (uses existing Claude) |

**Webhook:** Best for CI/CD automation (GitHub Actions)  
**MCP:** Best for rich formatting + local control

**Recommendation:** Use both!
- Workflows save data (no Slack posting needed)
- You manually post via MCP for rich formatting
- Or set up webhook as fallback

---

## Next Steps

1. ✅ Verify Claude Code + Slack MCP available
2. ✅ Test script: `scripts/post_to_slack_mcp.sh --help`
3. ✅ After workflow completes, post to Slack:
   ```bash
   scripts/post_to_slack_mcp.sh --type contract --file extraction/output/latest.json
   ```
4. 🔄 Optional: Set up webhook + MCP for full automation

---

## Support

If MCP posting fails:
1. Check Claude Code is running
2. Verify Slack MCP is connected: Settings → MCP Servers
3. Run with `--verbose` flag to see Claude output
4. Test MCP directly: `claude -p "Say hi" --allowedTools "mcp__claude_ai_Slack__slack_send_message"`

---

**Status:** Ready to use! 🚀

Test it:
```bash
scripts/post_to_slack_mcp.sh --type contract --file extraction/output/contract.json --verbose
```

# Installing ContractIQ

Three steps. No coding experience needed. If anything on screen doesn't
match what's described here, stop and ask engineering — don't guess.

---

## Step 1 — Get the files onto your computer

Open a terminal (on Windows: **Git Bash**; on Mac: **Terminal**) and run:

```bash
git clone https://github.com/sahil1808agg/LegalTeam.git
cd LegalTeam
```

This downloads the ContractIQ project into a folder called `LegalTeam` and
moves you into it. Everything else happens inside this folder.

---

## Step 2 — Run the installer

Still in the same terminal, run:

```bash
./install.sh
```

This checks that the tools ContractIQ needs (Claude Code, jq, Node.js) are
installed on your machine and sets up the working folders it uses to store
drafts, redline reports, and extracted contract data.

- If everything is already installed, you'll see a row of `[OK]` lines and
  a final **"Setup complete."** message.
- If something is missing, the script tells you exactly what to install and
  gives you a link — install it, then run `./install.sh` again. It's safe
  to run as many times as you need.

Don't move on to Step 3 until you see **"Setup complete."**

---

## Step 3 — Try it out

In the same terminal, start Claude Code:

```bash
claude
```

Once it opens, type:

```
/extract-contract
```

and press Enter. Claude will ask you for a contract file (or offer to
process a whole batch) and walk you through the rest — just answer its
questions.

That's it — you're set up. For what the other commands do (drafting an
NDA/MSA/SOW, running a redline comparison, checking renewal deadlines), ask
Claude directly: *"what ContractIQ commands are available?"*

---

## If something goes wrong

- **`git clone` fails** — you may not have Git installed, or you don't have
  access to the repository yet. Ask engineering for access.
- **`./install.sh` says a tool is missing** — follow the link it gives you,
  install that one tool, then run `./install.sh` again.
- **`/extract-contract` doesn't show up in Claude Code** — make sure you
  started `claude` from *inside* the `LegalTeam` folder (Step 1's `cd`
  command), not from somewhere else.

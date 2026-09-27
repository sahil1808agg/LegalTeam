# ContractIQ — Tool & Permission Security Audit

Scope: every tool surface Claude (interactive session, slash commands, hooks,
sub-agent, and `claude -p` subprocesses spawned by pipeline scripts) can
reach in this repository, the specific files/paths each one touches, and the
minimum permission grant that covers the observed use — as opposed to the
blanket wildcards currently present in `.claude/settings.json` and
`.claude/settings.local.json`.

Audited: `.claude/settings.json`, `.claude/settings.local.json`,
`.claude/hooks/*.sh`, `.claude/commands/*.md`, `.claude/agents/contract-extractor.md`,
`.claude-plugin/plugin.json`, all pipeline scripts (`drafting/`, `redlining/`,
`extraction/`, `obligations/`, `contracts/chunker.sh`, `scripts/`, `install.sh`),
`.github/workflows/*.yml`.

---

## 1. Read

| Caller | Files actually read | Current grant | Minimum grant |
|---|---|---|---|
| Interactive session | `CLAUDE.md`, `PRD.md`, command/agent/skill markdown | *(implicit — no restriction needed, repo docs)* | fine as-is |
| `redline-contract` command | `redlining/playbooks/*.md` (via `freshness_check.sh` gate) | — | `Read(redlining/playbooks/*.md)` |
| `contract-extractor` sub-agent | one contract `.txt`/chunk file passed by caller | `tools: Read, Grep, Glob` (agent frontmatter, already scoped, no `drafting/`/`redlining/` per its own instructions) | already minimal — good example |
| `claude -p --allowedTools "Read"` inside `draft_nda.sh`/`draft_msa.sh`/`draft_sow.sh` | exactly one template: `drafting/templates/{nda,msa,sow}_template.md` | subprocess-scoped to `Read` only, no path restriction | tighten to `Read(drafting/templates/*.md)` — the subprocess has no reason to read anything else |
| `claude -p --allowedTools "Read"` inside `redline.sh` | the two paths passed as `--incoming`/`--playbook` | subprocess-scoped to `Read` only | acceptable; paths are argv-controlled by the calling command, not free text |

**Findings**
- `settings.json` grants `Read(src/**)`, `Read(tests/**)`, `Read(config/**)` — **none of these directories exist** in the current repo (actual code lives in `drafting/`, `redlining/`, `extraction/`, `obligations/`). These are stale grants inherited from the target folder layout in `CLAUDE.md` and grant nothing today, but will silently become live, unaudited blanket grants the moment those folders are created. Replace with grants scoped to the folders that actually exist: `Read(drafting/templates/**)`, `Read(redlining/playbooks/**)`, `Read(extraction/output/**)`, `Read(obligations/output/**)`.
- `settings.json` grants `Read(drafting/**)` — broader than needed; a lawyer-facing session only ever needs to *read* `drafting/templates/` (to draft) — it does not need standing read access to `drafting/output/` (other users' in-progress drafts). Narrow to `Read(drafting/templates/**)`.
- `settings.local.json` contains `Read(//c/Users/Sahil/**)`, `Read(//mingw64/**)`, `Read(//c/Program Files/**)` — **full home-directory and system-tool read access**, accumulated from a one-off PDF/OCR debugging session. This is the single broadest grant in the repo: it lets any future Bash/Read call see every file the user owns, not just the one `Downloads\*.pdf` that was actually being triaged. **Remove and replace** with the exact files used: `Read(C:/Users/Sahil/Downloads/nda.pdf)`, `Read(C:/Users/Sahil/Downloads/nda_1.pdf)`, `Read(//tmp/ocr_test/**)` (already present, correctly scoped — a good contrast to the three above).

---

## 2. Write

| Caller | Files actually written | Mechanism | Current grant | Minimum grant |
|---|---|---|---|---|
| — | `drafting/output/*.md`, `redlining/output/*.md`, `extraction/output/*.json`, `obligations/output/*.json` | **Not the Write tool** — every pipeline script writes via shell redirection (`>`, `printf > file`) inside a `Bash`-permitted script, so these files never touch Claude's own Write permission at all. | `Write(src/**)`, `Write(tests/**)` in `settings.json` | **remove both** — dead grants pointing at directories that don't exist and that no current workflow writes to via the Write tool |

**Finding:** the Write tool is effectively unused by this codebase's real workflows (output is always produced by a script under a scoped `Bash(...)` grant, which is arguably *better* least-privilege than giving Claude direct Write access to those output directories — a compromised prompt can't get Claude to write an arbitrary file there, only to run the fixed script). If Claude is ever given direct Write access (e.g., to hand-edit a playbook), scope it narrowly, e.g. `Write(redlining/playbooks/*.md)`, not a repo-wide glob.

---

## 3. Edit

Same situation as Write: `Edit(src/**)`, `Edit(tests/**)` in `settings.json` point at directories that don't exist and aren't edited by any current command. **Remove both.** No pipeline script or command currently asks Claude to Edit a file directly (all mutation happens through the fixed shell scripts).

---

## 4. Glob

| Caller | Pattern | Current grant | Assessment |
|---|---|---|---|
| `redline-contract` command | `redlining/playbooks/*.md` | `Glob(redlining/playbooks/*.md)` | Already minimal — good pattern to replicate elsewhere. |

---

## 5. AskUserQuestion

Used by `draft-nda`, `draft-msa`, `draft-sow`, `extract-contract`, `redline-contract` commands to collect deal terms / pick a playbook / decide single-vs-batch. No file or system access. Already scoped per-command via each command's `allowed-tools:` frontmatter — no change needed.

---

## 6. Bash

Bash is the largest surface. Breaking it down by what each grant is actually for:

### 6a. Pipeline script entry points (already well-scoped — model to copy)

| Command | Grant | Files touched by the script |
|---|---|---|
| `/draft-nda` | `Bash(./drafting/draft_nda.sh:*)`, `Bash(drafting/draft_nda.sh:*)` | reads `drafting/templates/nda_template.md`; writes `drafting/output/*.md` |
| `/draft-msa` | `Bash(./drafting/draft_msa.sh:*)` | reads `drafting/templates/msa_template.md`; writes `drafting/output/*.md` |
| `/draft-sow` | `Bash(./drafting/draft_sow.sh:*)` | reads `drafting/templates/sow_template.md`; writes `drafting/output/*.md` |
| `/redline-contract` | `Bash(./redlining/redline.sh:*)` | reads `--incoming`/`--playbook` args; writes `redlining/output/*.md` |
| `/extract-contract` | `Bash(./extraction/extract.sh:*)`, `Bash(./extraction/parallel_extract.sh:*)` | reads `extraction/input/*.txt`; writes `extraction/output/*.json`, `extraction/output/.logs/*.log` |
| `/check-renewals` | `Bash(./obligations/check_deadlines.sh:*)` | reads `extraction/output/master_portfolio.json`; writes `obligations/output/deadline_alerts_*.json` |

These six are the model for the rest of this section: **one grant per script path, wildcarded only on the script's own arguments, not on the shell**. No changes needed here.

### 6b. Housekeeping commands in `settings.json` (project-wide, stale)

| Grant | Finding |
|---|---|
| `Bash(npm run test *)`, `Bash(npm run lint)` | No `package.json` exists anywhere in this repo — there is no npm project. Dead grant. **Remove.** |

### 6c. `settings.local.json` — accumulated one-off dev-session grants

This file is effectively a session transcript of every command a human approved while building the PDF/OCR pipeline, the drafting scripts, and the CI workflows. Individually most entries are already file/argument-scoped (good), but several are genuine blanket grants that outlive the session that created them:

| Grant | Why it's a blanket permission | Minimum replacement |
|---|---|---|
| `Bash(bash *)` | Runs **any** script with **any** arguments — supersedes every other, more specific `Bash(bash <script> ...)` rule already in the same file, making those narrower rules decorative. | Delete this entry; keep only the specific `Bash(bash <path/to/script> ...)` rules already present (redline.sh, chunker.sh, etc.). |
| `Bash(node *)` | Runs any Node script/inline `-e` code with any argument, anywhere on disk. | Scope to the two files actually used: `Bash(node contracts/chunks/nda_review/inspect_pdf.js *)`, `Bash(node contracts/chunks/nda_review/inspect_pdf2.js *)`. Drop `Bash(node -e '...')` and `Bash(node *)` entirely — inline `-e` is unauditable by pattern. |
| `Bash(Get-ChildItem *)` | Unrestricted directory listing anywhere the shell can reach. | Scope to the repo root if directory listing is genuinely needed: `Bash(Get-ChildItem "C:\Users\Sahil\mahesh - 16 day" *)`. |
| `Bash(git push *)` | Wildcard covers push to any remote/branch/force-push flag combination. | Push is a shared-state action (visible to others) per the operating rules for this agent — it should never be blanket-pre-approved; require confirmation per push, or at minimum restrict to `Bash(git push origin main)` / the specific branch in use. |
| `Bash(git remote *)`, `Bash(git branch *)` | Wildcard covers remote add/remove and branch delete, not just read (`git remote -v`, `git branch --list`). | Split into read-only (`Bash(git remote -v)`, `Bash(git branch --list)`) vs. mutating (kept out of the always-allow list). |
| `Bash(winget install *)`, `Bash(winget search *)`, `Bash(winget list *)` | Installs arbitrary Windows packages system-wide. | These were one-time Poppler/Tesseract setup steps; they should not remain in a persistent allow-list post-setup. Remove; re-approve interactively if a future package install is genuinely needed. |
| `Bash(gh run *)`, `Bash(gh issue *)`, `Bash(gh workflow *)` | Wildcard covers mutating subcommands (`gh issue close`, `gh issue comment`, `gh workflow run`, `gh workflow disable`) alongside the read-only ones actually used for CI debugging (`gh run view`, `gh run list`). | Split: read-only `Bash(gh run view *)`, `Bash(gh run list)`, `Bash(gh issue view *)` vs. mutating actions requiring per-call confirmation (issue creation in CI is done by the GitHub Actions runner with `GH_TOKEN`, not by a local Claude session — see §8). |
| `Bash(rm -rf *)`-style entries (several, e.g. `rm -rf contracts/chunks/nda_review_v2`, `/tmp/mp_test`, etc.) | Individually each is scoped to one literal path (fine), but taken together they establish a pattern of approving `rm -rf` freely. | Keep them as literal, one-path-at-a-time grants (current state is actually acceptable here) — flagging only so future additions to this list follow the same literal-path discipline rather than generalizing to `Bash(rm -rf *)`. |
| `Bash(cat)` (no args) | Combined with the full-filesystem `Read(//c/Users/Sahil/**)` grant above, this allows dumping any file's contents via stdin redirection from an already-broad Read grant. | Remove once the `Read(//c/Users/Sahil/**)` grant (§1) is narrowed — `cat` alone is low-risk without a matching broad Read/Bash grant to feed it. |
| `Bash(env)` | Dumps the full process environment, which for this repo includes `ANTHROPIC_API_KEY` / Slack tokens if ever exported into the shell. | Remove; if a specific variable needs checking, prefer `Bash(printf '%s\n' "$VAR_NAME")` scoped to that one variable name. |

### 6d. PDF/OCR toolchain (good example, minor cleanup)

`pdftotext`, `pdfinfo`, `pdfimages`, `pdffonts`, `pdftoppm`, `tesseract` calls are all scoped to one literal input file per grant (e.g. `Bash(pdftotext -layout "C:\...\nda_1.pdf" -)`), which is the correct pattern — each grant only works for the specific document under review, not any PDF on disk. The only cleanup needed: the `where`/`where.exe`/`command -v` discovery calls (`Bash(where pdftotext *)`, etc.) were one-time environment-setup steps and can be removed post-install now that `install.sh` documents the prerequisite check.

---

## 7. MCP endpoints

| Tool | Where it's actually invoked | Channel/DB scoping in the code | Current grant | Assessment / minimum grant |
|---|---|---|---|---|
| `mcp__claude_ai_Slack__slack_send_message` | `obligations/check_deadlines.sh`, `obligations/morning_digest.sh`, `scripts/post_to_slack_mcp.sh` — always via a **subprocess** `claude -p ... --allowedTools "Read,mcp__claude_ai_Slack__slack_send_message"` | Channel is hardcoded per-script default `#legal-contracts`, overridable via `--channel` flag passed into the prompt text (not enforced by the tool grant itself) | Also granted at the **top level** in `settings.local.json` with no channel restriction | The subprocess-level scoping (Read + this one Slack tool, nothing else) is correctly minimal. The top-level grant, however, lets an interactive Claude session post to **any** Slack channel, not just `#legal-contracts` — the tool grant itself carries no channel parameter restriction. Since Claude Code's permission syntax can't constrain a specific argument value for MCP tools, the mitigating control has to live in the prompt/script layer (as it already does) — document this as a residual risk rather than something the permission system alone can close. |
| `mcp__claude_ai_Notion__notion-ai-search` | **Not called by any script.** No file in this repo invokes it. | — | Granted at top level in `settings.local.json` | **Remove.** `notion-ai-search` performs workspace-wide search, far broader than the single "Contract Intelligence" database `insert_hotspots.sh` targets (`NOTION_DATABASE_ID=3d3558f40a4580668857efd2482b1f2d`). |
| `mcp__claude_ai_Notion__notion-fetch` | Not called by any script. | — | Granted at top level | **Remove** — same reasoning; `notion-fetch` can retrieve any page in the workspace, not just Contract Intelligence records. |
| `mcp__claude_ai_Notion__notion-query-data-sources` | Conceptually needed by `extraction/insert_hotspots.sh`'s upsert-by-`contract_name` logic (the script itself only *writes a prompt file* — see below) | Database ID is a fixed constant in the script | Granted at top level, no DB-ID scoping possible via the permission string itself | Keep, but note the script only prepares a prompt for **manual** `claude -p` invocation (`insert_hotspots.sh` does not call MCP directly) — so this permission is exercised only when a human runs the saved prompt file, not automatically. Document that as the intended control. |
| `mcp__claude_ai_Notion__notion-create-pages` | Same as above (upsert path) | Same DB ID | Granted at top level | Keep, same caveat as above. |
| `mcp__claude_ai_Google_Drive__search_files` | **Not called anywhere.** `plugin.json` lists `google-drive@anthropic-tools` as a dependency and `settings.json` configures a `"Legal Contracts"` folder, but no script, command, or hook ever references Google Drive. | — | Granted at top level in `settings.local.json` | **Remove entirely** — this is a pure orphaned grant: configured, permissioned, and never exercised by any actual workflow in the repo. If Google Drive integration is planned but not yet built, remove the permission until the feature exists, rather than pre-granting it. |

---

## 8. CI (GitHub Actions) — separate trust boundary, not a Claude Code permission, but same audit lens

`contract_review.yml` and `daily_renewals.yml` run `claude -p` non-interactively with `ANTHROPIC_API_KEY` from repo secrets, and explicitly **disable** `.claude/settings.json` for the run (`mv .claude/settings.json .claude/settings.json.bak`) to avoid interactive permission prompts blocking the pipeline. This means the CI `claude -p` calls run with the CLI's default tool access, not the repo's curated allow-list — worth flagging because the two workflow files never pass `--allowedTools` to their `claude -p` calls (unlike every local script, which does). **Recommendation:** add `--allowedTools "Read"` (contract_review.yml's risk-assessment call only needs to read piped stdin, not tools) and `--output-format json` already present — the missing piece is the explicit tool restriction, since disabling `settings.json` removes the one guardrail that would otherwise apply.

`gh issue create` in `contract_review.yml` runs with the workflow's own `GH_TOKEN` (scoped via the workflow's `permissions: issues: write`, already minimal — good). This is unrelated to the local `gh issue *` grant flagged in §6c, which applies to a human's interactive session, not CI.

---

## 9. Summary of required changes

**Remove (orphaned or stale — grant nothing real today, or grant more than any workflow uses):**
- `Read(src/**)`, `Write(src/**)`, `Edit(src/**)`, `Read(tests/**)`, `Write(tests/**)`, `Edit(tests/**)`, `Read(config/**)` (`settings.json`)
- `Bash(npm run test *)`, `Bash(npm run lint)` (`settings.json`)
- `mcp__claude_ai_Google_Drive__search_files` (`settings.local.json`)
- `mcp__claude_ai_Notion__notion-ai-search`, `mcp__claude_ai_Notion__notion-fetch` (`settings.local.json`)
- One-time discovery/setup commands: `where`/`where.exe`/`command -v` probes, `winget install/search/list` (`settings.local.json`)

**Narrow (currently wildcarded beyond what any script/workflow needs):**
- `Read(drafting/**)` → `Read(drafting/templates/**)`
- `Bash(bash *)` → delete (redundant with the specific `Bash(bash <script>)` rules already present)
- `Bash(node *)`, `Bash(node -e '*')` → `Bash(node contracts/chunks/nda_review/inspect_pdf.js *)`, `Bash(node contracts/chunks/nda_review/inspect_pdf2.js *)`
- `Read(//c/Users/Sahil/**)`, `Read(//mingw64/**)`, `Read(//c/Program Files/**)` → specific file paths actually used (e.g. `Read(C:/Users/Sahil/Downloads/nda.pdf)`)
- `Bash(git push *)`, `Bash(git remote *)`, `Bash(git branch *)` → split read-only vs. mutating; do not blanket-approve push
- `Bash(gh run *)`, `Bash(gh issue *)`, `Bash(gh workflow *)` → split read-only (`view`, `list`) vs. mutating subcommands
- `Bash(Get-ChildItem *)`, `Bash(env)` → scope to specific directory / remove

**Already minimal — keep as the model for future additions:**
- All six slash-command `allowed-tools:` frontmatter grants (one Bash rule per script path)
- `Glob(redlining/playbooks/*.md)`
- `contract-extractor` agent's `tools: Read, Grep, Glob` (no Bash, no MCP, no write access)
- Every `claude -p --allowedTools "..."` subprocess call inside the pipeline scripts (each restricted to `Read` plus, where needed, exactly one MCP tool)
- Literal, single-file `pdftotext`/`pdfinfo`/`rm -rf <one path>` grants in `settings.local.json`

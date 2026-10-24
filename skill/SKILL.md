---
name: dsh-plugin-hub
description: Control hub for DeepSeek Harness (dsh) plugins and skills - one routing table that answers "which plugin do I use for X" and dispatches to the right tool. Use when the user asks what plugins are installed, how to use a plugin, or wants memory, turn rewind, skill cards, browser automation, local transcription, pre-install skill scanning, or skill discovery. Triggers: plugin, hub, dispatch, memory, rewind, skill cards, Obsidian, browser automation, audio/video transcription, skill scanning, find skills.
whenToUse: User mentions installed plugins, plugin status, unified dispatch, or asks which tool to use for memory / rewind / failure-notes / Obsidian / web automation / transcription / skill scanning / skill discovery.
license: MIT
metadata:
  short-description: Unified entry & trigger routing for installed dsh plugins
---

# DSH Plugin Hub

One routing table for every plugin and skill installed in this harness.
All paths live in `config.ps1` next to this file (see the repo's
`config.example.ps1`). Run `status.ps1` to check what is actually healthy
before dispatching.

## Trigger routing

| User intent / keywords | Use | Notes |
| --- | --- | --- |
| remember, recall, long-term memory, cross-session | `dsh-hindsight`: `hindsight_*` tools / `/hindsight`; fallback `hindsight.ps1` | needs Hindsight service running (config: `$HindsightUrl`) |
| failure notes, past fixes, "how did I solve this" | `misakanet`: `mcp__misakanet__*` tools | community failure-experience library |
| rewind, undo, revert, back to last turn | `dsh-turn-rewind`: conversation/workspace rewind | Web UI entry too |
| skill cards, pick a skill | `dsh-skill-cards`: cards under the input box | Web UI entry |
| self-improvement, retrospective, distill lessons | `@klarkxy/dsh-self-improvement` | background/UI type |
| Obsidian, knowledge base, notes | `dsh-obsidian`: `obsidian_*` tools | set vault path in its settings |
| web pages, click, fill forms, screenshot, scrape | `agent-browser` skill + local CLI | verify with `ab.cmd --version` |
| audio/video to text, subtitles, offline transcription | `local-whisper` skill + whisper.cpp | models under your whisper dir |
| pre-install scan, skill security review | `skill-scanner` skill + Cisco Skill Scanner | scan BEFORE installing anything |
| find skills, skill marketplace | `find-skills` skill + `npx skills` | needs network |
| web search, research | built-in `web_search` / `web_fetch` | built-in |
| Word/Excel/PPT | built-in `office-docx` / `office-xlsx` / `office-pptx` | built-in |

## Common commands

```powershell
# one-shot status check (plugins, tool files, services, skill junctions)
powershell -ExecutionPolicy Bypass -File "<hub>\status.ps1"

# installed profile plugins + versions
& "<dsh-cli>" plugin --profile <profile> list --depth=1

# install / remove (desktop profile)
& "<dsh-cli>" plugin --profile <profile> add <package>
& "<dsh-cli>" plugin --profile <profile> remove <package>

# hindsight CLI (when the tool isn't loaded yet)
pwsh -File "<hub>\hindsight.ps1" -Action status
pwsh -File "<hub>\hindsight.ps1" -Action remember -Text "..."
pwsh -File "<hub>\hindsight.ps1" -Action recall -Query "..."
```

Health and manifest tooling:

```powershell
# per-check PASS/WARN/FAIL diagnosis; -Fix applies safe repairs (BOM, junction)
powershell -ExecutionPolicy Bypass -File "<hub>\doctor.ps1"

# draft PROVENANCE from the live plugin list; -Online fills license/source via npm
powershell -ExecutionPolicy Bypass -File "<hub>\gen-provenance.ps1" -Online
```

Plugin changes are hot-mounted by DSH HMR; skill-directory changes are picked
up by the skill-filesystem watcher.

## Rules

1. Confirm a plugin's status before dispatching; if it is down, say so —
   never pretend a call succeeded.
2. Third-party plugins/skills are untrusted by default; scan with
   `skill-scanner` and read the scripts before installing.
3. Never hand credentials, cookies, or session content to external plugins
   or web pages.
4. After every install/remove, update `PROVENANCE.md` (template in
   `templates/`) so the routing table stays truthful.
5. Do not install plugins whose purpose is bypassing model safety policies,
   or third-party account-pool/free-channel plugins (credential and
   compliance risk).

# dsh-plugin-hub

**One control hub for every plugin and skill installed in DeepSeek Harness (dsh).**

DeepSeek Harness ships a deliberately barebones core — "everything is a plugin".
Within weeks its community produced turn rewind, long-term memory, skill cards,
failure-experience libraries, Obsidian bridges, browser automation, local
transcription, security scanners... and then you face the real problem:

> You have 7 plugins across profile bundles, a skills directory, and built-in
> tools. You can't remember which one does what, whether it's actually running,
> or what you installed last week.

`dsh-plugin-hub` is the missing front door:

- **One routing table** (`SKILL.md`) — the agent answers "which tool for X" from a
  single, maintained table instead of guessing across plugin lists.
- **One status command** (`status.ps1`) — profile plugins, tool files, services,
  and skill junctions, checked in one shot.
- **One install step** (`install.ps1`) — copies the hub and junctions it into
  `%USERPROFILE%\.dsh\skills` so DSH hot-loads it. Skills stay in one unified
  directory; no more copy-pasting folders into `.dsh`.
- **One manifest** (`PROVENANCE.md`) — what you installed, from where, which
  license, verified how. The routing table is only allowed to claim what this
  file confirms.
- **Safety rules baked in** — third-party skills are untrusted by default; scan
  before install; no safety-policy-bypassing or account-pool plugins.

## Quick start (Windows, PowerShell 5.1+)

```powershell
git clone https://github.com/<you>/dsh-plugin-hub.git
cd dsh-plugin-hub
powershell -ExecutionPolicy Bypass -File .\install.ps1
# then edit %USERPROFILE%\.dsh-hub\dsh-plugin-hub\config.ps1
```

Restart DSH (or reload its Web UI) and ask your agent:

```
Which plugins are installed, and which one handles long-term memory?
```

## Compatibility

| dsh version | Status |
| --- | --- |
| 0.2.0-rc.2 (Desktop) | tested — hub in production use |
| 0.2.1-rc.2 (Desktop) | tested — incl. turn-rewind 0.3.10 compat fixes |

Windows-first (junctions, PowerShell). PRs for other platforms welcome.

## What it does NOT do

- It is not a plugin manager (`dsh plugin add/remove` still does that) — it is
  the discovery, dispatch, and truth-keeping layer above your plugins.
- It does not collect or send anything anywhere. All paths come from your local
  `config.ps1`, which is git-ignored.

## Roadmap

- [ ] 30-second demo GIF
- [x] `doctor` mode: per-check PASS/WARN/FAIL with fix hints (`doctor.ps1`, `-Fix` applies safe repairs)
- [x] Provenance generator: auto-draft the manifest from `dsh plugin list` (`gen-provenance.ps1`, `-Online` enriches via npm)
- [ ] Community routing-table presets (security, media, office workflows)

## Related projects

The hub routes to community plugins — the table above is only an entry point.
Notable ecosystem projects: [Anionex/dsh-turn-rewind](https://github.com/Anionex/dsh-turn-rewind),
[Ikalus1988/MisakaNet](https://github.com/Ikalus1988/MisakaNet),
[Ryu6Zero/dsh-hindsight](https://github.com/Ryu6Zero/dsh-hindsight),
[mingzeng21/dsh-obsidian](https://github.com/mingzeng21/dsh-obsidian),
[vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser),
[cisco-ai-defense/skill-scanner](https://github.com/cisco-ai-defense/skill-scanner).

---

Need a hardened multi-machine setup (skills factory, CI gating, security audit
pipelines) built on this pattern? Open an issue or reach out — this repo grew
out of a production single-operator studio.

MIT licensed. Provided as-is; review every third-party plugin you install.

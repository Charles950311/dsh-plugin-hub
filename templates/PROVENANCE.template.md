# Plugin / Skill Install Manifest — PROVENANCE

> Copy this file to `PROVENANCE.md` and keep it updated after every
> install/remove. The hub's routing table is only trustworthy if this list
> is truthful. Record: source, version, license, and how you verified it.

Environment: dsh version `<x.y.z>` (profile: `<desktop>`), updated `<YYYY-MM-DD>`

## Installed Cordis plugins (profile)

Install method: `dsh plugin --profile <profile> add <package>`

| Plugin | Version | Source | License | What it does | Verified how |
| --- | --- | --- | --- | --- | --- |
| `@owner/dsh-plugin` | 0.0.0 | github.com/owner/repo ★n | MIT | one line | e.g. "tool appears in session; ran /command" |

## Installed skill-type tools (unified skills dir + dsh hot-load)

| Tool/Skill | Version | Source | License | Location | Verified how |
| --- | --- | --- | --- | --- | --- |
| agent-browser | 0.39.1 | github.com/vercel-labs/agent-browser | Apache-2.0 | skills/agent-browser | `ab.cmd --version` |
| skill-scanner | 2.3.0 | github.com/cisco-ai-defense/skill-scanner | Apache-2.0 | skills/skill-scanner | scanned a skill, got JSON |
| local-whisper | v1.9.2 | github.com/ggml-org/whisper.cpp | MIT | skills/local-whisper | transcribed a test wav |

## Built-in, no install needed

| Need | dsh capability |
| --- | --- |
| Office documents | `office-docx` / `office-xlsx` / `office-pptx` |
| Web search | built-in `web_search` / `web_fetch` |

## Not installed / refused (with reasons)

| Item | Reason |
| --- | --- |
| `example/dsh-purge`-type plugins | purpose is bypassing model safety policy — do not install |
| third-party account-pool / free-channel plugins | credential + compliance risk |

## Model integrity notes (optional but recommended)

- model file, size, SHA256, and the release manifest it was checked against

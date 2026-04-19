# Clarity

**Copilot-style Claude Code context and token management — official-docs-first, project-grounded.**

> Status: v0.0.3 · private alpha — ships across four surfaces (CLI · MCP server · Claude Code plugin · slash-command skill), all validated against the latest official specs (MCP `2025-11-25`, Claude Code plugin v2.1.111).

## The problem

Anthropic's own session-management blog identifies five decisions you face at every turn (continue, `/rewind`, `/clear`, `/compact`, subagents) and two main failure modes: **context rot** past ~300-400k tokens, and **bad `/compact`** when the model summarizes without knowing your next step.

Most Claude Code users pay these taxes silently. Claude Code doesn't warn you before a bad `/compact`. It doesn't tell you your cache just expired. It doesn't flag a `check X` prompt about to balloon into a 800M-token session.

And the real driver — poor `.claude/` project structure — forces every session to re-explore the same codebase, burning tokens on work the structure should have prevented.

## The approach

Clarity does three things, all built from Anthropic's own official guidance:

1. **Doctor** — read your session logs, your `~/.claude/` and project `.claude/` config, your plugins and rules. Report where the tokens actually go. Recommend fixes only from official docs.
2. **Install** — scaffold the recommended `.claude/` structure (rules, skills, agents, settings) for your specific project. Not a generic template — it reads your codebase and tailors each file.
3. **Run with you** — sit quietly in the statusline. Warn before cache expires, before bad `/compact`, before a known trap prompt. One suggestion, one keystroke to accept.

## What Clarity will never do

- Run your prompts through its own servers
- Obfuscate or minify its source
- Require an external account
- Invent rules not in Anthropic's official docs

## Installation

Clarity ships in four interchangeable forms. Install one or all — they share the same analyzer under the hood.

### 1. Claude Code plugin (recommended for Claude Code users)

```bash
# One-time clone
git clone git@github.com:robotlearning123/clarity.git ~/tools/clarity

# Register as a local marketplace and install
claude plugin marketplace add ~/tools/clarity
claude plugin install clarity@clarity
```

The plugin ships:
- `/clarity-doctor [days]` slash command
- Skill frontmatter with `when_to_use` and `effort: low` so Claude invokes it at the right moment
- Plugin cache path: `~/.claude/plugins/cache/clarity/clarity/0.0.3/`

Verify:
```bash
claude plugin list | grep clarity
```

### 2. Standalone CLI

The CLI works with or without the plugin — useful for scripting, CI, or cron jobs.

```bash
# Symlink once for a short PATH entry
ln -s ~/tools/clarity/bin/clarity /usr/local/bin/clarity

clarity doctor --since-days 30
clarity doctor --since-days 7 --json
clarity version
clarity help
```

### 3. MCP server

Expose `clarity_doctor` as an MCP tool to any compliant client (Claude Code, Claude Desktop, other agents).

Add to your project's `.mcp.json`:
```json
{
  "mcpServers": {
    "clarity": {
      "command": "python3",
      "args": ["/Users/you/tools/clarity/mcp/server.py"]
    }
  }
}
```

Protocol: JSON-RPC 2.0 over stdio, MCP spec `2025-11-25`. Exposes one tool (`clarity_doctor`) with a single `since_days` parameter. No external account, no telemetry.

### 4. Statusline integration

Append to your `~/.claude/statusline-command.sh`:

```sh
# your existing statusline output first ...

clarity=$(printf '%s' "$input" | sh "$HOME/tools/clarity/scripts/clarity-status.sh" 2>/dev/null)
[ -n "$clarity" ] && printf ' · %b' "$clarity"
```

Output example:
```
main · opus 4.7 · ctx 12% · ● cache 42m · ctx 12% · OK to continue
                            └── Clarity's status ────────────────┘
```

Degrades gracefully: if the session jsonl isn't yet flushed, the `cache Xm` field is omitted and only `ctx` + traffic light show.

## Daily usage

### What Doctor reports

- Estimated 30-day cost using correct Opus 4.7 pricing (cache_read at 0.1x, not 1x — the common DIY-analyzer mistake that makes rankings unreliable)
- Top cost-concentration project (often one project dominates 80%+)
- Top 10 most expensive sessions with the first prompt that triggered each — this is where scope creep started
- Cache read/write ratio — flags if you're paying to rebuild cache too often
- 2-3 concrete recommendations citing official Anthropic docs only

### What the statusline tells you

| Dot | Meaning | Suggestion shown |
|---|---|---|
| 🟢 green | ctx < 25%, cache warm or unknown | `OK to continue` |
| 🟡 yellow | ctx 25-40%, or cache expired | `fine for now` or `cache expired · /clear is cheap now` |
| 🔴 red | ctx ≥ 40% | `/compact with focus or /clear with handoff` |

The `cache Xm` field shows minutes until prompt cache expires (60m with `ENABLE_PROMPT_CACHING_1H=1`, else 5m). Knowing this prevents bad `/compact` decisions mid-session.

## How it stacks up

| Tool | Mechanism | Auditable? | Account? | Approach |
|---|---|---|---|---|
| wozcode | Opaque hooks + obfuscated JS | No | Yes | Do it for you |
| kieranklaassen/token_analysis.py | Python log analyzer | Yes | No | Measure only |
| **Clarity** | Shell/Python, zero runtime deps | Yes | No | Measure + guide + install |

## Roadmap

- v0.0.1 — scaffold ✓
- v0.0.2 — **(this release)** Doctor (`analyze.py`) with correct cost weighting, statusline script, `/clarity-doctor` slash command, plugin manifest
- v0.0.3 — SessionStart hook: auto-run Doctor once per project on first session, `.clarity/doctor-report.md` opens automatically
- v0.0.4 — `clarity install` CLI: scaffolds project `.claude/` structure based on Doctor's findings (the 1Key PR in one command)
- v0.0.5 — PreCompact steering hook + `/handoff` skill bundled

## Case study

Clarity's first user is [1Key](https://github.com/robotlearning123/1key), a TypeScript monorepo that was consuming 88% of the author's Claude Code budget before install. See [docs/case-study-1key.md](docs/case-study-1key.md) for the full walkthrough — Doctor output, PR diff, three rounds of codex fixes, and measured outcome.

## License

MIT. See [LICENSE](LICENSE).

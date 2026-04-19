# Clarity

**Copilot-style Claude Code context and token management — official-docs-first, project-grounded.**

> Status: v0.0.5 · private alpha — ships across four surfaces (CLI · MCP server · Claude Code plugin · slash-command skill), validated against the latest official specs (MCP `2025-11-25`, Claude Code `2.1.114`).
>
> **Honest coverage** (per the blog that motivates this project): Clarity v0.0.5 addresses ~30% of the branch-point decisions the blog names. Statusline covers `continue / /clear / /compact` reasoning via ctx% and cache-age. **`/rewind`, subagent suggestions, and task-switch detection are NOT yet implemented** — see [Roadmap](#roadmap) and the [gap table below](#blog-coverage-honest).

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
curl -fsSL https://raw.githubusercontent.com/robotlearning123/clarity/v0.0.5/install.sh | CLARITY_REPO_REF=v0.0.5 bash
```

This installs Clarity into `~/.claude/clarity`, validates the plugin, registers the local marketplace, and installs `clarity@clarity` so Claude Code can use `/clarity-doctor`.

Manual fallback:
```bash
git clone https://github.com/robotlearning123/clarity.git ~/.claude/clarity
claude plugin marketplace add ~/.claude/clarity
claude plugin install clarity@clarity
```

The plugin ships:
- `/clarity-doctor [days]` slash command
- Skill frontmatter with `when_to_use` and `effort: low` so Claude invokes it at the right moment
- Plugin cache path: `~/.claude/plugins/cache/clarity/clarity/0.0.5/`

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

Protocol: JSON-RPC 2.0 over stdio, MCP spec `2025-11-25`. Exposes one tool (`clarity_doctor`) with a single `since_days` parameter and returns the same Markdown doctor report as the CLI. No external account, no telemetry.

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

## Blog coverage (honest)

Clarity's reason to exist is the Anthropic blog [*Using Claude Code: Session Management & 1M Context*](https://x.com/trq212/status/2044548257058328723). A local reference copy also lives at [docs/Using Claude Code Session Management & 1M Context.md](docs/Using%20Claude%20Code%20Session%20Management%20%26%201M%20Context.md). Every feature is measured against it. Current coverage:

| Blog concept | Clarity v0.0.5 | Gap |
|---|---|---|
| 1M context awareness | Statusline `ctx N%` + Doctor historical | ✓ |
| Context rot ~300-400k | Statusline red at 40% used (= 400k on 1M) | ⚠ threshold is %-based, not token-absolute — misleads on non-1M models |
| `continue` decision | Green dot + `OK to continue` | ✓ |
| `/clear` decision | Yellow/red cues when cache expired or ctx high | ✓ |
| `/compact` decision | Red cue at ctx ≥ 40% | ⚠ no PreCompact steering hook (`/compact focus on X`) |
| **`/rewind` decision** | — | ✗ not implemented |
| **Subagent decision** | — | ✗ no "tool output heavy → spin subagent" hint |
| **Task-switch detection** | — | ✗ biggest blog ask, requires semantic diff of prompts |
| Bad-compact prevention | Proactive red cue only | ⚠ no PreCompact hook to steer auto-compact |
| `/handoff` brief generation | — | ✗ v0.0.6 |

v0.0.5 is honest about the ~30% coverage. Doctor + statusline solve the *measurement* and *basic-awareness* half. The *per-turn decision support* half (rewind, subagent, task-switch) is the v0.0.6 and v0.0.7 work.

## Roadmap

- v0.0.1 — scaffold ✓
- v0.0.2 — Doctor + statusline + plugin manifest ✓
- v0.0.3 — CLI + MCP server, latest spec alignment ✓
- v0.0.4 — codex-audited hardening: symlink-safe CLI, robust jq parsing, cache TTL JSON parse, timezone-aware date filters, honest blog-coverage table
- v0.0.5 — **(this release)** one-line installer (`install.sh`), checked-in smoke tests, fail-closed statusline behavior, unified release metadata across CLI/plugin/MCP, and real Claude Code install/update verification
- v0.0.6 — `/rewind` + subagent guidance in statusline; PreCompact hook that asks "what's next?" before auto-compact fires
- v0.0.7 — task-switch detection (keyword diff of recent prompts); `/handoff` skill generates brief to `.claude/handoffs/`
- v0.0.8 — `clarity install` CLI: scaffolds project `.claude/` from Doctor findings (the 1Key PR in one command)

## Case study

Clarity's first user is [1Key](https://github.com/robotlearning123/1key), a TypeScript monorepo that was consuming 88% of the author's Claude Code budget before install. See [docs/case-study-1key.md](docs/case-study-1key.md) for the full walkthrough — Doctor output, PR diff, three rounds of codex fixes, and measured outcome.

## License

MIT. See [LICENSE](LICENSE).

# Clarity

**Copilot-style Claude Code context and token management — official-docs-first, project-grounded.**

> Status: v0.0.2 · private alpha — Doctor works, statusline script ships, install-as-plugin

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

## Installation (v0.0.2 — as a Claude Code plugin)

Clarity ships as a Claude Code plugin. Two install paths today:

**A. Clone and symlink (simplest, for private alpha):**

```bash
git clone git@github.com:robotlearning123/clarity.git ~/tools/clarity

# Make it discoverable by Claude Code's plugin loader
mkdir -p ~/.claude/plugins/cache/clarity/0.0.2
ln -s ~/tools/clarity ~/.claude/plugins/cache/clarity/0.0.2/local
```

Then in a new Claude Code session, `/clarity-doctor` is available as a slash command.

**B. Add statusline integration (recommended — gives you the real-time signal):**

Append to your `~/.claude/statusline-command.sh` (or wherever your statusline is defined):

```sh
# ... your existing statusline output ...
clarity=$(printf '%s' "$input" | sh "$HOME/tools/clarity/scripts/clarity-status.sh" 2>/dev/null)
[ -n "$clarity" ] && printf ' · %s' "$clarity"
```

Your statusline will now show something like:
```
main · opus 4.7 · ctx 12% · ● cache 42m · ctx 12% · OK to continue
                            └── Clarity's output ─────────────────┘
```

When context gets heavy or cache is about to expire, the dot turns yellow/red with a one-line suggestion.

## Usage

```bash
# Slash command (after plugin install):
/clarity-doctor                     # run Doctor, write .clarity/doctor-report.md

# Direct CLI (always works):
python3 ~/tools/clarity/scripts/analyze.py --since-days 30
python3 ~/tools/clarity/scripts/analyze.py --since-days 7 --json
```

### What Doctor reports

- Estimated 30-day cost (using correct Opus 4.7 pricing — cache_read at 0.1x, not 1x)
- Top cost-concentration project (often one project dominates)
- Top 10 most expensive sessions, with the first prompt that triggered each (this is where scope-creep started)
- Cache read/write ratio — flags if you're paying to rebuild cache too often
- 2-3 concrete recommendations citing official Anthropic docs only

### What the statusline tells you

| Dot | Meaning | Suggestion shown |
|---|---|---|
| 🟢 green | ctx < 25%, cache warm | `OK to continue` |
| 🟡 yellow | ctx 25-40%, or cache expired | `ctx X% · fine for now` or `cache expired · /clear is cheap now` |
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

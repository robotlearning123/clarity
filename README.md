# Clarity

**Copilot-style Claude Code context and token management — official-docs-first, project-grounded.**

> Status: v0.0.1 · private alpha

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

```bash
# Not yet shipped. v0.0.1 is scaffold only.
# Target install: brew install clarity  OR  curl -fsSL https://clarity.dev/install.sh | sh
```

## Usage (target UX)

```bash
clarity doctor         # Diagnose token spend + config health. Read-only.
clarity install        # Apply recommended .claude/ structure to current repo.
clarity status         # Single-line health for statusline integration.
clarity handoff        # Generate handoff brief before /clear.
```

## How it stacks up

| Tool | Mechanism | Auditable? | Account? | Approach |
|---|---|---|---|---|
| wozcode | Opaque hooks + obfuscated JS | No | Yes | Do it for you |
| kieranklaassen/token_analysis.py | Python log analyzer | Yes | No | Measure only |
| **Clarity** | Shell/Python, zero runtime deps | Yes | No | Measure + guide + install |

## Roadmap

- v0.0.1 — scaffold, license, basic `clarity doctor` (this release)
- v0.0.2 — `clarity install` scaffolds rules/skills/agents for a project
- v0.0.3 — statusline integration (health dot + ctx/cache readout)
- v0.0.4 — PreCompact steering hook
- v0.0.5 — `clarity handoff` skill bundled + wired to `/clear`

## Case study

Clarity's first user is [1Key](https://github.com/robotlearning123/1key), a TypeScript monorepo that was consuming 88% of the author's Claude Code budget before install. See [docs/case-study-1key.md](docs/case-study-1key.md) for the full walkthrough — Doctor output, PR diff, three rounds of codex fixes, and measured outcome.

## License

MIT. See [LICENSE](LICENSE).

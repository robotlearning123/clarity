# Changelog

All notable changes to Clarity will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/).

## [0.0.4] — 2026-04-19

### Fixed (from strict codex review + user-level test suite)
- **[P1 release blocker] `bin/clarity` CLI broke when installed via symlink.** `$(dirname "$0")` resolved to the symlink location (e.g., `/usr/local/bin`) instead of the repo, so `clarity doctor` failed with "can't open /usr/local/scripts/analyze.py". Now uses a portable readlink loop per `BASH_SOURCE[0]` so `ln -s bin/clarity /usr/local/bin/clarity` actually works.
- **Statusline polluted stderr on malformed JSON input.** jq parse errors leaked through to the statusline; now silenced with `2>/dev/null`, emitting a clean `ctx 0%` fallback.
- **Cache TTL detection used raw `grep` on settings.json.** Commented-out keys and string `"false"` were matching; now parses with `jq -r .env.ENABLE_PROMPT_CACHING_1H` and checks truthy values (`1`/`true`/`yes`). Same logic applied to `ENABLE_PROMPT_CACHING_1H` env var.
- **`analyze.py --since-date` discarded timezone offsets.** A naive `replace(tzinfo=UTC)` after `fromisoformat` silently mis-shifted aware inputs (e.g., `2026-01-01T00:00:00+02:00` became 00:00 UTC instead of 22:00 UTC prior day). Now uses `astimezone(UTC)` when input is aware; still defaults to UTC for naive input.

### Added
- **Honest blog-coverage table in README.** Clarity v0.0.4 addresses ~30% of the branch-point decisions the Anthropic session-management blog names. `/rewind`, subagent hints, and task-switch detection are marked as NOT YET IMPLEMENTED rather than quietly omitted.
- **User-level E2E test suite** (not shipped as code yet — lives in the strict-test conversation log): 22 scenarios covering statusline edge cases (malformed JSON, missing context_window, cache cold), CLI (symlink, unknown command, invalid since-days), and MCP (unknown tool, unknown method, real tools/call).

### Known limits (moved to Roadmap)
- `/rewind`, subagent, task-switch, PreCompact steering, `/handoff` are v0.0.5/v0.0.6 work.
- Rot threshold is a fixed 40% of context_window rather than a token-absolute band (300-400k) — fine on 1M models but misleads on smaller context sizes.
- MCP `clarity_doctor` returns only a Markdown blob; a structured JSON schema for downstream automation is v0.0.5.

## [0.0.3] — 2026-04-19

### Added
- **CLI entrypoint** (`bin/clarity`): unified `clarity doctor` / `clarity status` / `clarity version` / `clarity help`. Dispatches to the right script regardless of install method.
- **MCP server** (`mcp/server.py`): minimal JSON-RPC stdio server, no external SDK. Exposes one tool `clarity_doctor` with `since_days` parameter. Protocol version `2025-11-25` per current MCP spec. Register in any `.mcp.json`.
- **SKILL.md enhancements**: `when_to_use` and `effort: low` frontmatter fields per latest Claude Code skills reference (v2.1.111+).

### Changed
- Plugin install now uses the documented `claude plugin marketplace add <path>` + `claude plugin install` flow. Previous README instructions (symlink into `~/.claude/plugins/cache/`) bypassed the marketplace and did not enable the plugin; replaced with the correct official procedure.
- `plugin.json` bumped to `0.0.3`, added `author` (object, not string) and `repository` fields per Claude Code plugins-reference schema.
- `marketplace.json`: removed ignored `owner.url` field (not in spec), bumped plugin version to `0.0.3`.
- Statusline suggestions rewritten to action-only (no duplicate ctx% in the output). Previous output `ctx 30% · ctx 30% · fine for now` became `● ctx 30% · fine for now`.
- Statusline degrades gracefully when session jsonl is missing (new session, fresh clone): omits the `cache Xm` field instead of producing empty output.

### Verified against latest official specs
Full audit against docs.claude.com, modelcontextprotocol.io, and Anthropic Claude Code changelog (Jan-Apr 2026). All four surfaces validated:
- MCP: protocol `2025-11-25`, `capabilities.tools.listChanged=false`
- Plugin: `claude plugin validate` passes, manifest at `.claude-plugin/plugin.json`
- Marketplace: `claude plugin marketplace add` accepts and installs
- Skill: frontmatter matches the 2026 reference (name, description, when_to_use, argument-hint, effort)

### Known limits
- No `clarity install` CLI yet — project `.claude/` scaffolding is still manual (see docs/case-study-1key.md for the 1Key example, v0.0.4 will automate).
- Statusline `date` invocation assumes macOS BSD `date -j -f` OR GNU `date -d`; fully portable rewrite deferred.
- MCP server is stdio-only; HTTP/SSE transports not implemented (v0.0.5).

## [0.0.2] — 2026-04-19

### Added
- `scripts/analyze.py` — Doctor: reads `~/.claude/projects/**/*.jsonl`, computes per-project and per-session token totals with correct Opus 4.7 cost weighting (cache_read at 0.1x, not 1x — the common mistake in DIY analyzers that makes cost rankings unreliable). Outputs Markdown report at `.clarity/doctor-report.md`; optional `--json` for machine consumption.
- `scripts/clarity-status.sh` — one-line statusline integration. Reads Claude Code's statusline JSON on stdin, computes minutes since last activity (cache TTL proxy), context % in use, and traffic-light suggestion. ASCII dot by default, ANSI color when outputting to a real TTY.
- `skills/clarity-doctor/SKILL.md` — `/clarity-doctor [days]` slash command that runs `analyze.py` and summarizes the top 3-5 signals for the user.
- `.claude-plugin/plugin.json` — makes the repo discoverable as a Claude Code plugin (v0.0.2).

### Verified
- `analyze.py` run against real 30-day data: $2,528 estimated cost over 7 days, top project correctly surfaced at 90% concentration.
- Statusline logic hand-tested across 5 path forms (bare, `./`, absolute, nested, innocent).

### Known limits
- No `clarity install` CLI yet — project `.claude/` scaffolding is still manual (see docs/case-study-1key.md for the 1Key example).
- Statusline script assumes macOS `date -j -f` OR GNU `date -d`; other platforms untested.
- SessionStart hook that auto-runs Doctor on first session not yet included — coming v0.0.3.

## [0.0.1] — 2026-04-19

### Added
- Initial repository scaffold.
- README.md — problem statement, approach, comparison with wozcode and kieranklaassen/token_analysis.py, roadmap through v0.0.5.
- MIT LICENSE.
- .gitignore.
- docs/case-study-1key.md — live walkthrough of install → doctor → fix → daily-use using 1Key as the first user, with real session stats, PR link, and three rounds of codex review fixes.

### Notes
- Validated against 1Key project as first user case during design phase. 1Key's historical session data (3.48B tokens over 30 days, single session peaking at 867M tokens, 88% project concentration) shaped the initial rule set and skill templates.
- No executable code in this release — v0.0.1 is scaffold only. First working `clarity doctor` ships in v0.0.2.
- Three rounds of codex review on the 1Key install surfaced real defects in the initial scaffold: hook used fake env var, l2-add skill made false file-count promises, `.env.*` deny globs overreached, `.dev.vars` was missed, and several paths didn't match the actual codebase. All fixed before merge. See case study for details.

# Changelog

All notable changes to Clarity will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/).

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

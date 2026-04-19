# Changelog

All notable changes to Clarity will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/).

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

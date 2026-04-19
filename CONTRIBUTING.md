# Contributing

Thanks for contributing to Clarity.

Clarity is intentionally small. The standard here is not "more automation" or
"more features." The standard is: simple install, honest behavior, and release
surfaces that stay consistent.

## What to optimize for

- Minimal diffs that solve one concrete problem
- Fewer commands and fewer moving parts
- No false-safe behavior
- Clear release-facing docs
- Repeatable release checks

## Before you open a PR

Run:

```bash
bash scripts/release-check.sh
```

That covers:

- `tests/smoke.sh`
- version consistency across CLI / plugin / MCP / README
- `claude plugin validate` when `claude` is available locally

## Scope guidance

Good contributions:

- Fix a real bug in CLI / statusline / doctor / installer / MCP
- Improve install reliability
- Tighten release consistency
- Improve docs without broadening claims
- Add small, targeted tests for regressions

Changes that should be discussed before implementation:

- New dependencies
- CI complexity beyond the current minimal workflows
- New bots or automation systems
- New top-level commands
- Broad product repositioning

## Style

- Keep shell scripts portable and explicit
- Prefer direct scripts over indirection
- Prefer one strong workflow over multiple overlapping ones
- Keep README claims narrower than implementation, not broader

## Release-sensitive files

If your change touches release behavior, check these carefully:

- `install.sh`
- `bin/clarity`
- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- `mcp/server.py`
- `README.md`
- `CHANGELOG.md`
- `tests/smoke.sh`

## Changelog

If user-facing behavior changes, add or update the relevant section in
`CHANGELOG.md`.

## Manual host validation

Repo tests are necessary but not always sufficient. For plugin-install or slash
command changes, validate in a real Claude Code environment before release using
`docs/release-checklist.md`.

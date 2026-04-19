---
name: clarity-doctor
description: Run Clarity's Doctor — scan the past 30 days of Claude Code token usage, find problems, recommend fixes. Writes .clarity/doctor-report.md in the current directory.
when_to_use: First install of Clarity, or any time token spend feels off. Also when switching to a new project and wanting a baseline. Read-only — safe to run anytime.
argument-hint: "[days]"
effort: low
---

# Clarity Doctor

Read-only diagnostic. Scans `~/.claude/projects/**/*.jsonl` for all recent sessions across all projects, attributes cost using Opus 4.7 list prices (cache_read weighted at 0.1x, not 1x — the common mistake in DIY analyzers), surfaces the top expensive sessions and top projects, and flags 2-3 concrete fix recommendations.

## Arguments
`$1` — number of days to analyze (default: 30)

## Run

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/analyze.py" --since-days "${1:-30}" --out .clarity/doctor-report.md
```

Then Read `.clarity/doctor-report.md` and summarize for the user in 3-5 bullet points:

1. Total cost + session count
2. Top cost-concentration project (if >50% of spend)
3. The most expensive single session's first prompt (this is where scope-creep started)
4. Cache-read / cache-create ratio (if low, recommend `ENABLE_PROMPT_CACHING_1H=1`)
5. Recommended next step (likely: install `.claude/` structure for the hot project — see case study)

## Do not
- Interpret the cost as your actual billed amount (depends on your plan)
- Modify any files — Doctor is read-only
- Read the full report back to the user — summarize the key signals only

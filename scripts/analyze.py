#!/usr/bin/env python3
"""
clarity analyze — Claude Code token usage analyzer.

Reads ~/.claude/projects/<project>/*.jsonl, computes per-project and per-session
token totals with correct cost weighting (cache_read at 0.1x, not 1x), flags the
top expensive sessions, and writes a Markdown doctor report.

Origin: derived from https://gist.github.com/kieranklaassen/7b2ebb39cbbb78cc2831497605d76cc6
Fixes applied:
- Cache-read tokens weighted at 0.1x input price (not 1x) — Anthropic official pricing
- User-name prefix stripped generically (no hardcoded username)
- Output path configurable via --out; defaults to ./.clarity/doctor-report.md
- Cost estimated in USD using Opus 4.7 list prices

Usage:
    python3 analyze.py [--since-days N] [--out path] [--json]

Env:
    SINCE_DAYS   equivalent to --since-days
    SINCE_DATE   YYYY-MM-DD absolute start date

No external deps. Python 3.9+.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

# Opus 4.7 list price per million tokens (2026-04).
# Cache read is 10x cheaper than base input, not 1x. Kieran's original totals overweight cache reads.
PRICE = {
    "input": 5.0,
    "cache_create_5m": 6.25,  # 1.25x base
    "cache_create_1h": 10.0,  # 2x base
    "cache_read": 0.5,  # 0.1x base
    "output": 25.0,
}

PROJECTS_DIR = Path.home() / ".claude" / "projects"


def normalize_project(name: str) -> str:
    """Strip common home-path prefixes so project names are readable."""
    user = os.environ.get("USER", "")
    for p in (f"-Users-{user}-", f"Users-{user}-"):
        if name.startswith(p):
            return name[len(p) :]
    return name.lstrip("-")


def collect_usage(jsonl_path: Path) -> dict[str, int]:
    """Sum token usage from one session jsonl."""
    totals = defaultdict(int)
    try:
        with jsonl_path.open() as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if obj.get("isSidechain"):
                    continue
                msg = obj.get("message", {})
                usage = msg.get("usage") or {}
                for k in (
                    "input_tokens",
                    "cache_creation_input_tokens",
                    "cache_read_input_tokens",
                    "output_tokens",
                ):
                    v = usage.get(k, 0) or 0
                    totals[k] += int(v)
    except OSError:
        pass
    return totals


def first_prompt(jsonl_path: Path, max_len: int = 140) -> str:
    """Extract first user prompt for session labeling."""
    try:
        with jsonl_path.open() as fh:
            for line in fh:
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if obj.get("isSidechain"):
                    continue
                msg = obj.get("message", {})
                if msg.get("role") != "user":
                    continue
                content = msg.get("content", "")
                if isinstance(content, list):
                    # Skip tool_result entries; find text
                    text_parts = [
                        p.get("text", "")
                        for p in content
                        if isinstance(p, dict) and p.get("type") == "text"
                    ]
                    content = " ".join(text_parts)
                if isinstance(content, str) and content.strip():
                    s = " ".join(content.split())
                    return s[:max_len] + ("…" if len(s) > max_len else "")
    except OSError:
        pass
    return "(no prompt)"


def cost_usd(tokens: dict[str, int]) -> float:
    """Estimate USD cost using Opus 4.7 list prices. Assumes 5-min cache writes by default."""
    return (
        tokens.get("input_tokens", 0) * PRICE["input"] / 1_000_000
        + tokens.get("cache_creation_input_tokens", 0)
        * PRICE["cache_create_5m"]
        / 1_000_000
        + tokens.get("cache_read_input_tokens", 0) * PRICE["cache_read"] / 1_000_000
        + tokens.get("output_tokens", 0) * PRICE["output"] / 1_000_000
    )


def session_mtime(path: Path) -> datetime:
    return datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc)


def main() -> int:
    ap = argparse.ArgumentParser(description="Clarity token analyzer.")
    ap.add_argument(
        "--since-days", type=int, default=int(os.environ.get("SINCE_DAYS", 30))
    )
    ap.add_argument("--since-date", default=os.environ.get("SINCE_DATE"))
    ap.add_argument(
        "--out", type=Path, default=Path.cwd() / ".clarity" / "doctor-report.md"
    )
    ap.add_argument(
        "--json", action="store_true", help="Also write JSON alongside Markdown"
    )
    args = ap.parse_args()

    if not PROJECTS_DIR.exists():
        print(
            f"error: {PROJECTS_DIR} not found. Is Claude Code installed?",
            file=sys.stderr,
        )
        return 1

    if args.since_date:
        parsed = datetime.fromisoformat(args.since_date)
        # If input had an explicit offset, convert to UTC. If naive, assume UTC.
        cutoff = (
            parsed.astimezone(timezone.utc)
            if parsed.tzinfo
            else parsed.replace(tzinfo=timezone.utc)
        )
    else:
        cutoff = datetime.now(timezone.utc) - timedelta(days=args.since_days)

    per_project: dict[str, dict[str, Any]] = defaultdict(
        lambda: {"sessions": 0, "tokens": defaultdict(int), "cost": 0.0}
    )
    sessions: list[dict[str, Any]] = []

    for project_dir in PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue
        for jsonl in project_dir.glob("*.jsonl"):
            if session_mtime(jsonl) < cutoff:
                continue
            totals = collect_usage(jsonl)
            if not any(totals.values()):
                continue
            cost = cost_usd(totals)
            per_project[project_dir.name]["sessions"] += 1
            per_project[project_dir.name]["cost"] += cost
            for k, v in totals.items():
                per_project[project_dir.name]["tokens"][k] += v
            sessions.append(
                {
                    "project": project_dir.name,
                    "session_id": jsonl.stem,
                    "mtime": session_mtime(jsonl).isoformat(),
                    "tokens": dict(totals),
                    "cost_usd": cost,
                    "first_prompt": first_prompt(jsonl),
                }
            )

    sessions.sort(key=lambda s: s["cost_usd"], reverse=True)
    top_projects = sorted(
        per_project.items(), key=lambda kv: kv[1]["cost"], reverse=True
    )

    grand_cost = sum(p[1]["cost"] for p in top_projects)
    grand_tokens = defaultdict(int)
    for _, p in top_projects:
        for k, v in p["tokens"].items():
            grand_tokens[k] += v

    args.out.parent.mkdir(parents=True, exist_ok=True)

    lines = []
    lines.append("# Clarity Doctor Report")
    lines.append("")
    lines.append(
        f"Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')} · Since: {cutoff.strftime('%Y-%m-%d')} · Days: {args.since_days}"
    )
    lines.append("")
    lines.append("## Grand totals")
    lines.append("")
    lines.append(f"- Projects active: {len(per_project)}")
    lines.append(f"- Sessions: {sum(p[1]['sessions'] for p in top_projects)}")
    lines.append(
        f"- Estimated cost: **${grand_cost:,.2f}** (Opus 4.7 list price; actual varies with your plan)"
    )
    lines.append(f"- Input: {grand_tokens['input_tokens']:>12,}")
    lines.append(f"- Cache create: {grand_tokens['cache_creation_input_tokens']:>12,}")
    lines.append(f"- Cache read: {grand_tokens['cache_read_input_tokens']:>12,}")
    lines.append(f"- Output: {grand_tokens['output_tokens']:>12,}")
    lines.append("")

    lines.append("## Cost concentration — top projects")
    lines.append("")
    lines.append("| Project | Sessions | Cost USD | Share |")
    lines.append("|---|---:|---:|---:|")
    for name, p in top_projects[:10]:
        share = (p["cost"] / grand_cost * 100) if grand_cost else 0
        lines.append(
            f"| `{normalize_project(name)}` | {p['sessions']} | ${p['cost']:,.2f} | {share:.0f}% |"
        )
    lines.append("")

    lines.append("## Top 10 most expensive sessions")
    lines.append("")
    lines.append(
        "A single expensive session is usually a scope-creep session — the first prompt was too broad."
    )
    lines.append("")
    for s in sessions[:10]:
        lines.append(
            f"- **${s['cost_usd']:,.2f}** · `{normalize_project(s['project'])}` · `{s['session_id'][:8]}`"
        )
        lines.append(f"    > {s['first_prompt']}")
    lines.append("")

    lines.append("## Recommendations")
    lines.append("")
    if not top_projects:
        lines.append(
            "- **No recent Claude Code sessions found in the selected window.** Try a wider `--since-days` window or rerun Clarity after using Claude Code."
        )
    if top_projects:
        top_name, top_p = top_projects[0]
        share = (top_p["cost"] / grand_cost * 100) if grand_cost else 0
        if share > 50:
            lines.append(
                f"- **{share:.0f}% of spend is concentrated in `{normalize_project(top_name)}`.** Prioritize adding project-level `.claude/` rules, skills, and handoff notes there first so Claude stops re-exploring the same codebase every session."
            )
    if sessions and sessions[0]["cost_usd"] > 10:
        lines.append(
            f"- **Your most expensive single session cost ~${sessions[0]['cost_usd']:,.2f}.** Review that first prompt — bounded prompts rarely balloon. Rewrite vague prompts into a concrete goal, a bounded scope, and a clear exit condition."
        )
    if grand_tokens["cache_creation_input_tokens"] > 0 and (
        grand_tokens["cache_read_input_tokens"]
        / grand_tokens["cache_creation_input_tokens"]
        < 5
    ):
        lines.append(
            '- **Cache-read / cache-create ratio is low (<5).** You\'re paying to rebuild cache too often. Consider enabling `ENABLE_PROMPT_CACHING_1H="1"` in `~/.claude/settings.json` env block.'
        )
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("Generated by [Clarity](https://github.com/robotlearning123/clarity).")

    args.out.write_text("\n".join(lines))

    if args.json:
        json_path = args.out.with_suffix(".json")
        json_path.write_text(
            json.dumps(
                {
                    "generated_at": datetime.now(timezone.utc).isoformat(),
                    "since": cutoff.isoformat(),
                    "grand": {"cost_usd": grand_cost, "tokens": dict(grand_tokens)},
                    "projects": [
                        {
                            "name": normalize_project(n),
                            **{
                                k: (dict(v) if isinstance(v, defaultdict) else v)
                                for k, v in p.items()
                            },
                        }
                        for n, p in top_projects
                    ],
                    "top_sessions": sessions[:25],
                },
                indent=2,
                default=str,
            )
        )

    print(f"Report: {args.out}")
    print(
        f"Projects: {len(per_project)} · Sessions: {sum(p[1]['sessions'] for p in top_projects)} · Est cost: ${grand_cost:,.2f}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

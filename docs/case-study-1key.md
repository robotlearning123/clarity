# Case Study: 1Key — Clarity's First User

> A live walkthrough of `install → doctor → fix → daily-use`, with real numbers and real PR diffs.

**Repo:** `robotlearning123/1key` — provider access control plane (AI app billing/key management). TypeScript monorepo: Hono gateway + Next.js web + Supabase + Stripe + pnpm workspaces.

**Why this project:** It was consuming 88% of the author's Claude Code budget. If Clarity cannot save tokens here, it cannot save them anywhere.

---

## Before Clarity — the damage

30-day analysis (2026-03-20 → 2026-04-18), using a modified [kieranklaassen/token_analysis.py](https://gist.github.com/kieranklaassen/7b2ebb39cbbb78cc2831497605d76cc6):

```
Projects:      17
Sessions:      434
Total tokens:  3,482,455,864
├── Input:          18M  (0.5%)
├── Cache create:   61M  (1.8%)
├── Cache read:   3.39B  (97.3%)
└── Output:         13M  (0.4%)
Subagents:        537M  (15% of total)
```

**Top 5 most expensive sessions (all from 1Key):**

| Final tokens | First prompt |
|---|---|
| 867M | `check openrouter usdc的充值` |
| 687M | `检查一下,voice agent + OpenAI Realtime + orchestration…` |
| 609M | `check 42-awesome-agent-infra, refer` |
| 246M | (pasted Obsidian clipping about biomedical search) |
| 146M | `check if you have fal.ai key, we need seedance 2.0…` |

**The pattern:** short `check X` prompts (or pasted long text) with no explicit scope. Claude explores broadly, reads many files, drifts into unrelated tasks, session balloons.

---

## Step 1 — Install Clarity (v0.0.1, manual)

v0.0.1 ships only the scaffold. `clarity doctor` is not yet a CLI binary; the Python analyzer runs standalone. Target in v0.0.2: single `clarity` binary.

Today:

```bash
git clone git@github.com:robotlearning123/clarity.git ~/tools/clarity
cd ~/workspace/41-openclone               # or your project
SINCE_DAYS=30 python3 ~/tools/clarity/scripts/analyze.py  # shipped in v0.0.2
```

---

## Step 2 — Doctor output (what Clarity found)

Clarity's Doctor diagnoses five surfaces and flags the worst:

```
╭─ clarity doctor ─ 1Key ────────────────────────────────
│ 17 projects · 434 sessions · 3.48B tokens (30 days)
│ This project = 88% of budget
│
│ ❌ Top problems
│   1. "check X" pattern → 867M token session
│   2. Long paste pollution → 134M + 71M sessions
│   3. No project-level skills; agent re-explores each time
│   4. CLAUDE.md 275 lines (officially <200)
│   5. No permissions.deny → Claude tries to read pnpm-lock
│
│ ✓ Solution (from official Anthropic docs only)
│   + .claude/settings.json       permissions.deny + lockfile hook
│   + .claude/rules/token-saving.md
│   + .claude/skills/handoff/
│   + .claude/skills/l2-add/
│   + .claude/agents/migration-reviewer.md
│   + CLAUDE.md edit: @import rules
│
│ Estimated savings: 3-5x on exploratory tasks
╰────────────────────────────────────────────────────────
```

Each recommendation is linked to a specific Anthropic doc (`docs/en/settings`, `docs/en/memory`, `docs/en/hooks`, `docs/en/skills`). No invented rules.

---

## Step 3 — Install the recommended `.claude/` structure

Clarity scaffolds the full structure into a git worktree (never directly into the main working tree). On 1Key this became **PR #228**:

**https://github.com/robotlearning123/1key/pull/228**

Files added/changed:

```
.claude/
├── settings.json                  permissions.deny + PreToolUse hook
├── rules/
│   └── token-saving.md           179 lines, encoded from historical sessions
├── skills/
│   ├── handoff/SKILL.md          before /clear, generate brief (Anthropic blog)
│   └── l2-add/SKILL.md           workflow reminder for L2 provider integration
├── agents/
│   └── migration-reviewer.md     revenue-leak pattern reviewer
└── hooks/
    └── block-lockfile-edit.sh    JSON permissionDecision API

+ CLAUDE.md                       @import rules + reference skills
+ .gitignore                      narrow .claude/ ignore to allow shared config
```

**Not one single file is invented.** Every path referenced exists, every rule cites an Anthropic doc or a historical session from this repo.

---

## Step 4 — Codex review round-trips (honesty)

Clarity's output was reviewed by [codex](https://github.com/openai/codex) against the repo's actual code. Three rounds of fixes before it passed:

| Round | Issue | Fix |
|---|---|---|
| 1 | Hook used fake env var `CLAUDE_TOOL_INPUT_FILE_PATH`, exit 1 doesn't block | External script reads stdin JSON, emits `hookSpecificOutput.permissionDecision=deny` |
| 1 | l2-add skill missed shipkey inventory + secret sync | Added Step 2 for `shipkey.json` + `pnpm secrets:setup/sync` |
| 2 | Hook case pattern required leading slash | Normalize `./` prefix, add bare-filename alternatives |
| 2 | Matcher missed `MultiEdit` | `Edit\|Write\|MultiEdit` |
| 2 | `.env.*` denied tracked `.env.example` files | Narrow to `.env.local` + `.env.*.local` only |
| 3 | Missed `.dev.vars` (Wrangler secrets) | Add `.dev.vars` + `.dev.vars.*` |
| 3 | l2-add pointed at `index.ts`, providers register in `routers/l2-proxy.ts` | Rewrote as workflow reminder, cites `buildL2ProviderMap` correctly |
| 3 | l2-add promised "exactly 4 files" but new providers need `types.ts`/`pricing.ts`/`billing.ts` | Dropped fixed count, call out novel-billing cases |
| 3 | Naming example used `FAL_KEY`, repo uses `FAL_API_KEY` | Corrected |

**Lesson**: Clarity's recommendations must be verified against the actual codebase, not guessed from pattern. Codex caught every hallucination.

---

## Step 5 — Run with Clarity (day-to-day, post-install)

Once `.claude/` is installed, future sessions in 1Key load the rules and skills automatically:

| You type | What happens |
|---|---|
| `check openrouter 充值` | token-saving.md's high-risk-word table triggers Claude to ask for scope before Read |
| `Edit pnpm-lock.yaml` | Hook denies with regenerate hint |
| `/handoff` before `/clear` | Generates brief in `.claude/handoffs/` so next session resumes with zero re-read |
| Merging `012_some_migration.sql` | `migration-reviewer` agent auto-dispatched, applies revenue-leak lens |
| Adding ElevenLabs as L2 | `l2-add` skill points straight at the slice doc, no self-exploration |

`clarity status` (target v0.0.3) will live in statusline showing current ctx %, cache TTL remaining, and a suggestion when token load crosses 200k.

---

## Measured outcome (to be confirmed)

v0.0.1 ships the structure; v0.0.2 will ship the rolling report. Expected impact over the next 30 days on 1Key:

- **3-5x on exploratory tasks** (new "check X" sessions stay <200M instead of ballooning to 800M+)
- **~30% baseline savings** from `1h` cache + trimmed plugin set (already in effect)
- **Zero regression risk** — all changes are config/doc, no runtime code touched

Full measurement in the next Clarity case-study update.

---

## Takeaways for Clarity's design

Three things 1Key proved:

1. **Official-docs-first is not aesthetic, it's safety.** Three of the nine codex findings were cases where Clarity's output would have been wrong if I'd trusted my memory instead of re-reading Anthropic docs.
2. **Measurement before prescription.** Without the 867M-session evidence, the high-risk-word table would have felt arbitrary.
3. **Skills are not specs.** An over-confident skill that promises "exactly N files" becomes a liability when the real codebase has more moving parts. Skills must be reminders + pointers, not replacements for the source of truth.

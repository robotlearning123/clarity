#!/bin/sh
# clarity status — one-line status for Claude Code statusline integration.
# Append the output of this script to your ~/.claude/statusline-command.sh.
#
# Reads the current session's .jsonl from stdin-provided cwd, computes:
# - Context tokens used (input+cache_create+output for this session)
# - Minutes since last activity (cache lifecycle proxy — 1h TTL)
# - Traffic-light color: green (healthy) / yellow (warning) / red (action needed)
# - Best-action hint when color isn't green
#
# Input: statusline JSON on stdin (from Claude Code), same format as statusline-command.sh.
# Output: one line like `cache 42m · ctx 87k · OK` (ASCII only, safe for any terminal).

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // ""')
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')

[ -z "$cwd" ] && exit 0

# Locate the session jsonl. Claude Code stores it under ~/.claude/projects/<slug>/<session_id>.jsonl
slug=$(printf '%s' "$cwd" | sed 's|/|-|g')
jsonl="$HOME/.claude/projects/$slug/$session_id.jsonl"
[ ! -f "$jsonl" ] && exit 0

# Last timestamp (any message) — for cache-age proxy.
last_ts=$(tail -100 "$jsonl" | jq -r 'select(.timestamp) | .timestamp' 2>/dev/null | tail -1)
now_epoch=$(date -u +%s)
if [ -n "$last_ts" ]; then
  last_epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "${last_ts%%.*}" +%s 2>/dev/null || date -u -d "$last_ts" +%s 2>/dev/null || echo "$now_epoch")
  mins_idle=$(( (now_epoch - last_epoch) / 60 ))
else
  mins_idle=999
fi

# Cache TTL check — 1h window if ENABLE_PROMPT_CACHING_1H=1, else 5m.
ttl_minutes=60
if [ "${ENABLE_PROMPT_CACHING_1H:-}" != "1" ] && ! grep -q 'ENABLE_PROMPT_CACHING_1H' ~/.claude/settings.json 2>/dev/null; then
  ttl_minutes=5
fi
cache_remaining=$(( ttl_minutes - mins_idle ))
[ "$cache_remaining" -lt 0 ] && cache_remaining=0

# Approximate context in k from the statusline JSON (Claude Code sends context_window.remaining_percentage).
remaining_pct=$(printf '%s' "$input" | jq -r '.context_window.remaining_percentage // empty')
if [ -n "$remaining_pct" ]; then
  ctx_used_pct=$(awk "BEGIN{printf \"%d\", 100 - $remaining_pct}")
else
  ctx_used_pct=0
fi

# Decide state.
state_color=""
suggestion=""
if [ "$cache_remaining" -le 0 ]; then
  state_color="yellow"
  suggestion="cache expired · /clear is cheap now"
elif [ "$ctx_used_pct" -ge 40 ]; then
  state_color="red"
  suggestion="ctx ${ctx_used_pct}% · /compact with focus or /clear with handoff"
elif [ "$ctx_used_pct" -ge 25 ]; then
  state_color="yellow"
  suggestion="ctx ${ctx_used_pct}% · fine for now"
else
  state_color="green"
  suggestion="OK to continue"
fi

# Colorize (ANSI). Respect NO_COLOR convention.
if [ -z "${NO_COLOR:-}" ] && [ -t 1 ] || [ "${CLARITY_FORCE_COLOR:-}" = "1" ]; then
  case "$state_color" in
    green)  dot="\033[32m●\033[0m" ;;
    yellow) dot="\033[33m●\033[0m" ;;
    red)    dot="\033[31m●\033[0m" ;;
    *)      dot="●" ;;
  esac
else
  dot="●"
fi

printf "%b cache %dm · ctx %d%% · %s" "$dot" "$cache_remaining" "$ctx_used_pct" "$suggestion"

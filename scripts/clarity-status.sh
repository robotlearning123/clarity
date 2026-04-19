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

# Fail closed if jq is missing. The caller (statusline) gets empty output rather than crash.
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
[ -z "$input" ] && exit 0

# Parse with jq; silence parse errors so malformed input doesn't pollute the statusline.
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // ""' 2>/dev/null)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)

# Context % from Claude Code's statusline JSON (always present on current CC).
remaining_pct=$(printf '%s' "$input" | jq -r '.context_window.remaining_percentage // empty' 2>/dev/null)
if [ -n "$remaining_pct" ]; then
  ctx_used_pct=$(awk "BEGIN{printf \"%d\", 100 - $remaining_pct}")
else
  ctx_used_pct=0
fi

# Try to locate the current session jsonl for cache-age inference.
mins_idle=
cache_known=0
if [ -n "$cwd" ] && [ -n "$session_id" ]; then
  slug=$(printf '%s' "$cwd" | sed 's|/|-|g')
  jsonl="$HOME/.claude/projects/$slug/$session_id.jsonl"
  if [ -f "$jsonl" ]; then
    last_ts=$(tail -100 "$jsonl" | jq -r 'select(.timestamp) | .timestamp' 2>/dev/null | tail -1)
    if [ -n "$last_ts" ]; then
      now_epoch=$(date -u +%s)
      # macOS (BSD date) first, GNU date fallback.
      last_epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "${last_ts%%.*}" +%s 2>/dev/null || date -u -d "$last_ts" +%s 2>/dev/null || echo "$now_epoch")
      mins_idle=$(( (now_epoch - last_epoch) / 60 ))
      cache_known=1
    fi
  fi
fi

# Cache TTL: 1h if env var is truthy OR settings.json opts in via a real value; else 5m.
# Parse settings.json with jq (not string grep) so commented lines and "false" don't false-match.
ttl_minutes=5
case "${ENABLE_PROMPT_CACHING_1H:-}" in
  1|true|TRUE|True|yes) ttl_minutes=60 ;;
esac
if [ "$ttl_minutes" = "5" ] && [ -f "$HOME/.claude/settings.json" ]; then
  val=$(jq -r '.env.ENABLE_PROMPT_CACHING_1H // empty' "$HOME/.claude/settings.json" 2>/dev/null)
  case "$val" in 1|true|TRUE|True|yes) ttl_minutes=60 ;; esac
fi

cache_remaining=0
if [ "$cache_known" = "1" ]; then
  cache_remaining=$(( ttl_minutes - mins_idle ))
  [ "$cache_remaining" -lt 0 ] && cache_remaining=0
fi

# Decide traffic-light state. Suggestions are action-only (the ctx field is printed separately).
state_color="green"
suggestion="OK to continue"
if [ "$ctx_used_pct" -ge 40 ]; then
  state_color="red"
  suggestion="/compact with focus or /clear with handoff"
elif [ "$cache_known" = "1" ] && [ "$cache_remaining" -le 0 ]; then
  state_color="yellow"
  suggestion="cache expired · /clear is cheap now"
elif [ "$ctx_used_pct" -ge 25 ]; then
  state_color="yellow"
  suggestion="fine for now"
fi

# Colorize (ANSI). Respect NO_COLOR and force-color env.
if { [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; } || [ "${CLARITY_FORCE_COLOR:-}" = "1" ]; then
  case "$state_color" in
    green)  dot="\033[32m●\033[0m" ;;
    yellow) dot="\033[33m●\033[0m" ;;
    red)    dot="\033[31m●\033[0m" ;;
    *)      dot="●" ;;
  esac
else
  dot="●"
fi

# Build output — omit `cache Xm` field if cache_known=0 (keeps the line honest).
if [ "$cache_known" = "1" ]; then
  printf "%b cache %dm · ctx %d%% · %s" "$dot" "$cache_remaining" "$ctx_used_pct" "$suggestion"
else
  printf "%b ctx %d%% · %s" "$dot" "$ctx_used_pct" "$suggestion"
fi

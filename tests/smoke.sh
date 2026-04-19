#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

HOME_DIR="$TMP/home"
export HOME="$HOME_DIR"
mkdir -p "$HOME_DIR/.claude/projects/-tmp-proj"

cat > "$HOME_DIR/.claude/projects/-tmp-proj/session123.jsonl" <<'EOF'
{"timestamp":"2026-04-19T12:00:00.000Z","message":{"role":"user","content":"check billing leak","usage":{"input_tokens":1000000,"cache_creation_input_tokens":2000000,"cache_read_input_tokens":3000000,"output_tokens":4000000}}}
{"timestamp":"2026-04-19T12:05:00.000Z","message":{"role":"assistant","content":"done","usage":{"input_tokens":10,"cache_creation_input_tokens":20,"cache_read_input_tokens":30,"output_tokens":40}}}
EOF

python3 -m py_compile "$ROOT/scripts/analyze.py" "$ROOT/mcp/server.py"
sh -n "$ROOT/bin/clarity"
sh -n "$ROOT/scripts/clarity-status.sh"
sh -n "$ROOT/install.sh"

cli_version="$("$ROOT/bin/clarity" version)"
[ "$cli_version" = "clarity 0.0.5" ]

mkdir -p "$TMP/bin"
ln -s "$ROOT/bin/clarity" "$TMP/bin/clarity"
[ "$("$TMP/bin/clarity" version)" = "clarity 0.0.5" ]

python3 - <<'PY' "$ROOT"
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
cli = (root / "bin" / "clarity").read_text()
plugin = json.loads((root / ".claude-plugin" / "plugin.json").read_text())["version"]
market = json.loads((root / ".claude-plugin" / "marketplace.json").read_text())["plugins"][0]["version"]
mcp = re.search(r'SERVER_INFO = \{"name": "clarity", "version": "([^"]+)"\}', (root / "mcp" / "server.py").read_text()).group(1)
assert plugin == "0.0.5"
assert market == "0.0.5"
assert f'VERSION="{plugin}"' in cli
assert mcp == plugin
PY

"$ROOT/bin/clarity" doctor --since-days 30 --out "$TMP/report.md" >/dev/null
grep -Fq 'Estimated cost: **$119.00**' "$TMP/report.md"

TZ_HOME="$TMP/tz-home"
mkdir -p "$TZ_HOME/.claude/projects/-tz-proj"
cat > "$TZ_HOME/.claude/projects/-tz-proj/session1.jsonl" <<'EOF'
{"timestamp":"2026-01-01T22:30:00.000Z","message":{"role":"user","content":"timezone cutoff test","usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}}
EOF
python3 - <<'PY' "$TZ_HOME/.claude/projects/-tz-proj/session1.jsonl"
import datetime
import os
import sys

path = sys.argv[1]
ts = datetime.datetime(2026, 1, 1, 22, 30, 0, tzinfo=datetime.timezone.utc).timestamp()
os.utime(path, (ts, ts))
PY
HOME="$TZ_HOME" python3 "$ROOT/scripts/analyze.py" --since-date '2026-01-02T00:00:00+02:00' --out "$TMP/report-tz.md" >/dev/null
grep -q '`tz-proj`' "$TMP/report-tz.md"

EMPTY_HOME="$TMP/empty-home"
mkdir -p "$EMPTY_HOME/.claude/projects"
HOME="$EMPTY_HOME" python3 "$ROOT/scripts/analyze.py" --since-days 30 --out "$TMP/report-zero.md" >/dev/null
grep -q "No recent Claude Code sessions found" "$TMP/report-zero.md"
if grep -q 'Cache-read / cache-create ratio is low' "$TMP/report-zero.md"; then
  echo "unexpected cache recommendation on empty report" >&2
  exit 1
fi

valid_status="$(printf '%s' '{"workspace":{"current_dir":"/tmp/proj"},"session_id":"session123","context_window":{"remaining_percentage":55}}' | HOME="$HOME_DIR" sh "$ROOT/scripts/clarity-status.sh")"
case "$valid_status" in
  *"ctx 45%"*) ;;
  *)
    echo "unexpected valid status output: $valid_status" >&2
    exit 1
    ;;
esac

malformed_status="$(printf '%s' '{not json' | HOME="$HOME_DIR" sh "$ROOT/scripts/clarity-status.sh" || true)"
[ -z "$malformed_status" ]

cat > "$TMP/in.jsonl" <<'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"clarity_doctor","arguments":{"since_days":30}}}
EOF

HOME="$HOME_DIR" python3 "$ROOT/mcp/server.py" < "$TMP/in.jsonl" > "$TMP/out.jsonl"
grep -q '"version": "0.0.5"' "$TMP/out.jsonl"
grep -q 'Clarity Doctor Report' "$TMP/out.jsonl"

FAKE_HOME="$TMP/fake-home"
FAKE_BIN="$TMP/fake-bin"
FAKE_LOG="$TMP/fake-claude.log"
mkdir -p "$FAKE_HOME" "$FAKE_BIN"
cat > "$FAKE_BIN/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
LOG_PATH="${FAKE_CLAUDE_LOG:?}"
STATE_PATH="${FAKE_CLAUDE_STATE:?}"
printf '%s\n' "$*" >> "$LOG_PATH"
case "$1 $2 ${3:-}" in
  "plugin validate "*)
    exit 0
    ;;
  "plugin marketplace add")
    marketplace_path="${4:-}"
    if [ -f "$STATE_PATH" ]; then
      exit 1
    fi
    printf '%s\n' "$marketplace_path" > "$STATE_PATH"
    exit 0
    ;;
  "plugin marketplace list")
    if [ -f "$STATE_PATH" ]; then
      printf 'Configured marketplaces:\n\n  ❯ clarity\n    Source: Directory (%s)\n' "$(cat "$STATE_PATH")"
    else
      printf 'Configured marketplaces:\n'
    fi
    exit 0
    ;;
  "plugin install "*)
    exit 0
    ;;
  *)
    printf 'unexpected fake claude invocation: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$FAKE_BIN/claude"

INSTALL_HOME="$TMP/install-home"
export FAKE_CLAUDE_LOG="$FAKE_LOG"
export FAKE_CLAUDE_STATE="$TMP/fake-claude.state"
PATH="$FAKE_BIN:$PATH" HOME="$INSTALL_HOME" CLARITY_REPO_URL="file://$ROOT" CLARITY_INSTALL_DIR="$INSTALL_HOME/.claude/clarity" CLARITY_REPO_REF="" "$ROOT/install.sh" >/dev/null
PATH="$FAKE_BIN:$PATH" HOME="$INSTALL_HOME" CLARITY_REPO_URL="file://$ROOT" CLARITY_INSTALL_DIR="$INSTALL_HOME/.claude/clarity" CLARITY_REPO_REF="" "$ROOT/install.sh" >/dev/null
test -d "$INSTALL_HOME/.claude/clarity/.git"
grep -Fq "plugin validate $INSTALL_HOME/.claude/clarity" "$FAKE_LOG"
grep -Fq "plugin install clarity@clarity" "$FAKE_LOG"

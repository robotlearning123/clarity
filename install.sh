#!/usr/bin/env bash

set -euo pipefail

REPO_URL="${CLARITY_REPO_URL:-https://github.com/robotlearning123/clarity.git}"
REPO_REF="${CLARITY_REPO_REF:-}"
INSTALL_DIR="${CLARITY_INSTALL_DIR:-$HOME/.claude/clarity}"
CLAUDE_BIN="${CLARITY_CLAUDE_BIN:-claude}"
PLUGIN_COORD="${CLARITY_PLUGIN_COORD:-clarity@clarity}"

log() {
  printf '==> %s\n' "$*"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

need_cmd git
need_cmd "$CLAUDE_BIN"

mkdir -p "$(dirname "$INSTALL_DIR")"

if [ -d "$INSTALL_DIR/.git" ]; then
  log "Updating Clarity in $INSTALL_DIR"
  git -C "$INSTALL_DIR" fetch --tags origin
else
  [ ! -e "$INSTALL_DIR" ] || die "$INSTALL_DIR exists but is not a git checkout"
  log "Cloning Clarity into $INSTALL_DIR"
  git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi

if [ -n "$REPO_REF" ]; then
  log "Checking out $REPO_REF"
  git -C "$INSTALL_DIR" fetch --depth 1 origin "$REPO_REF" >/dev/null 2>&1 || true
  git -C "$INSTALL_DIR" checkout --quiet "$REPO_REF"
else
  current_branch="$(git -C "$INSTALL_DIR" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [ -n "$current_branch" ]; then
    git -C "$INSTALL_DIR" pull --ff-only origin "$current_branch"
  fi
fi

log "Validating plugin manifest"
"$CLAUDE_BIN" plugin validate "$INSTALL_DIR"

log "Registering marketplace"
if ! "$CLAUDE_BIN" plugin marketplace add "$INSTALL_DIR"; then
  if "$CLAUDE_BIN" plugin marketplace list 2>/dev/null | grep -Fq "$INSTALL_DIR"; then
    log "Marketplace already registered"
  else
    die "failed to register marketplace at $INSTALL_DIR"
  fi
fi

log "Installing plugin $PLUGIN_COORD"
"$CLAUDE_BIN" plugin install "$PLUGIN_COORD"

log "Install complete"
printf '\nNext:\n'
printf '  1. Restart Claude Code if it is already running.\n'
printf '  2. Run /clarity-doctor in Claude Code.\n'

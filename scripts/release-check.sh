#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
cd "$ROOT"

version="$(
  python3 - <<'PY'
import json
from pathlib import Path
print(json.loads(Path(".claude-plugin/plugin.json").read_text())["version"])
PY
)"

echo "==> release-check: version $version"

bash tests/smoke.sh

python3 - <<'PY'
import json
import re
from pathlib import Path

root = Path.cwd()
plugin_version = json.loads((root / ".claude-plugin" / "plugin.json").read_text())["version"]
market_version = json.loads((root / ".claude-plugin" / "marketplace.json").read_text())["plugins"][0]["version"]
cli = (root / "bin" / "clarity").read_text()
mcp = (root / "mcp" / "server.py").read_text()
readme = (root / "README.md").read_text()

assert market_version == plugin_version, f"marketplace version {market_version} != plugin version {plugin_version}"
assert f'VERSION="{plugin_version}"' in cli, "CLI version does not match plugin.json"
assert f'"version": "{plugin_version}"' in mcp, "MCP server version does not match plugin.json"
assert f"v{plugin_version}/install.sh" in readme, "README install command is not pinned to the current tag"
assert f"CLARITY_REPO_REF=v{plugin_version}" in readme, "README installer ref is not pinned to the current tag"
assert f"/clarity/{plugin_version}/" in readme, "README plugin cache path is not pinned to the current version"
PY

if command -v claude >/dev/null 2>&1; then
  echo "==> release-check: claude plugin validate"
  claude plugin validate "$ROOT"
fi

echo "==> release-check: ok"

#!/usr/bin/env python3
"""
Clarity MCP server — exposes Clarity's Doctor as an MCP tool.

Minimal JSON-RPC over stdio MCP server, no external SDK required. Implements
the subset of MCP needed for tool calling:
- initialize
- tools/list
- tools/call (clarity_doctor)

Register in any project's .mcp.json:

    {
      "mcpServers": {
        "clarity": {
          "command": "python3",
          "args": ["/absolute/path/to/clarity/mcp/server.py"]
        }
      }
    }

After registering, the host (Claude Code, Claude Desktop, etc.) can call the
clarity_doctor tool to get a structured doctor report.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

PROTO_VERSION = (
    "2025-11-25"  # Current stable per modelcontextprotocol.io/specification/versioning
)
SERVER_INFO = {"name": "clarity", "version": "0.0.3"}
ROOT = Path(__file__).resolve().parent.parent

TOOLS = [
    {
        "name": "clarity_doctor",
        "description": (
            "Run Clarity's Doctor: scan ~/.claude/projects/**/*.jsonl, compute per-project and "
            "per-session token totals with correct Opus 4.7 cost weighting (cache_read at 0.1x). "
            "Returns a structured summary including grand totals, top projects, top expensive "
            "sessions (with first prompts that triggered scope creep), and concrete recommendations."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "since_days": {
                    "type": "integer",
                    "description": "Number of days to analyze",
                    "default": 30,
                    "minimum": 1,
                    "maximum": 365,
                }
            },
            "additionalProperties": False,
        },
    }
]


def run_doctor(since_days: int = 30) -> str:
    """Run analyze.py and return the Markdown report as a string."""
    with tempfile.TemporaryDirectory() as td:
        out_path = Path(td) / "report.md"
        proc = subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts" / "analyze.py"),
                "--since-days",
                str(since_days),
                "--out",
                str(out_path),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if proc.returncode != 0:
            raise RuntimeError(
                f"analyze.py failed (exit {proc.returncode}): {proc.stderr.strip()}"
            )
        return out_path.read_text()


def respond(request_id, result=None, error=None):
    msg = {"jsonrpc": "2.0", "id": request_id}
    if error is not None:
        msg["error"] = error
    else:
        msg["result"] = result
    sys.stdout.write(json.dumps(msg) + "\n")
    sys.stdout.flush()


def handle(message: dict) -> None:
    method = message.get("method")
    request_id = message.get("id")

    if method == "initialize":
        respond(
            request_id,
            {
                "protocolVersion": PROTO_VERSION,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": SERVER_INFO,
            },
        )
    elif method == "tools/list":
        respond(request_id, {"tools": TOOLS})
    elif method == "tools/call":
        params = message.get("params") or {}
        name = params.get("name")
        args = params.get("arguments") or {}
        if name != "clarity_doctor":
            respond(
                request_id, error={"code": -32601, "message": f"unknown tool: {name}"}
            )
            return
        try:
            report = run_doctor(int(args.get("since_days", 30)))
            respond(
                request_id,
                {
                    "content": [{"type": "text", "text": report}],
                    "isError": False,
                },
            )
        except Exception as exc:  # noqa: BLE001 — surface all failures to the client
            respond(
                request_id,
                {
                    "content": [
                        {"type": "text", "text": f"clarity_doctor failed: {exc}"}
                    ],
                    "isError": True,
                },
            )
    elif method == "notifications/initialized":
        # No response for notifications.
        return
    else:
        if request_id is not None:
            respond(
                request_id,
                error={"code": -32601, "message": f"method not found: {method}"},
            )


def main() -> int:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        handle(message)
    return 0


if __name__ == "__main__":
    sys.exit(main())

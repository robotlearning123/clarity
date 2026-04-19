# MCP

Register Clarity as a local MCP server when you want to call `clarity_doctor`
from Claude Code, Claude Desktop, or another MCP client.

## Example `.mcp.json`

```json
{
  "mcpServers": {
    "clarity": {
      "command": "python3",
      "args": ["/absolute/path/to/clarity/mcp/server.py"]
    }
  }
}
```

## Tool

- `clarity_doctor`
  - input: `since_days` integer, default `30`
  - output: the same Markdown doctor report returned by `clarity doctor`

## Notes

- Transport: JSON-RPC 2.0 over stdio
- Protocol version: `2025-11-25`
- No external account or hosted service required

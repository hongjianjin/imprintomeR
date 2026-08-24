# imprintomeR MCP server

This server exposes package discovery and CLI-help tools through MCP. Streamable
HTTP is the default transport and supports simultaneous clients such as Claude
Code, Codex, and Cursor.

```bash
python -m venv .venv-mcp
. .venv-mcp/bin/activate       # Windows: .venv-mcp\Scripts\Activate.ps1
python -m pip install -r requirements-mcp.txt
python mcp_server/server.py --transport streamable-http --host 127.0.0.1 --port 8000
```

Connect clients to `http://127.0.0.1:8000/mcp`. For local stdio clients use
`python mcp_server/server.py --transport stdio`. The server requires `Rscript`
on `PATH` for `cli_help`.

Exposed capabilities: `package_info`, `list_data_files`, `cli_help`, and the
`imprintomer://readme` resource.

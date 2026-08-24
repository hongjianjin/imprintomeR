#!/usr/bin/env python3
"""MCP server for imprintomeR; Streamable HTTP supports concurrent clients."""
from __future__ import annotations
import argparse, json, os, subprocess
from pathlib import Path
from typing import Any
from mcp.server.fastmcp import FastMCP
ROOT = Path(__file__).resolve().parents[1]
EXTDATA = ROOT / "inst" / "extdata"
CLI = ROOT / "inst" / "scripts" / "run_imprintomeR.R"
mcp = FastMCP("imprintomeR", stateless_http=True, json_response=True)
def _json(value: Any) -> str:
    return json.dumps(value, indent=2, default=str)
@mcp.tool()
def package_info() -> str:
    """Return package version, repository path, and CLI availability."""
    version = "unknown"
    description = ROOT / "DESCRIPTION"
    if description.exists():
        for line in description.read_text(encoding="utf-8").splitlines():
            if line.startswith("Version:"):
                version = line.split(":", 1)[1].strip(); break
    return _json({"package": "imprintomeR", "version": version, "repository": str(ROOT), "cli": str(CLI), "cli_exists": CLI.exists()})
@mcp.tool()
def list_data_files() -> str:
    """List data files shipped in inst/extdata and their sizes."""
    if not EXTDATA.exists(): return _json([])
    return _json([{"name": p.name, "bytes": p.stat().st_size} for p in sorted(EXTDATA.iterdir()) if p.is_file()])
@mcp.tool()
def cli_help() -> str:
    """Return run_imprintomeR.R --help output."""
    if not CLI.exists(): return "CLI script not found: " + str(CLI)
    result = subprocess.run(["Rscript", str(CLI), "--help"], cwd=ROOT, capture_output=True, text=True, check=False)
    return result.stdout or result.stderr
@mcp.resource("imprintomer://readme")
def readme() -> str:
    """Expose the project README as an MCP resource."""
    path = ROOT / "README.md"
    return path.read_text(encoding="utf-8") if path.exists() else "README.md not found"
def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--transport", choices=("streamable-http", "stdio"), default="streamable-http")
    parser.add_argument("--host", default=os.getenv("MCP_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.getenv("MCP_PORT", "8000")))
    args = parser.parse_args()
    if args.transport == "stdio": mcp.run(transport="stdio")
    else:
        mcp.settings.host, mcp.settings.port = args.host, args.port
        mcp.run(transport="streamable-http")
if __name__ == "__main__": main()

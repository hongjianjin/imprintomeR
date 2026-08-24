# imprintomeR MCP server

This server exposes the documented `imprintomeR` command-line workflows through MCP. Streamable HTTP is the default transport and supports simultaneous clients such as Claude Code, Codex, and Cursor.

## Install and run

```bash
python -m venv .venv-mcp
. .venv-mcp/bin/activate       # Windows: .venv-mcp\Scripts\Activate.ps1
python -m pip install -r requirements-mcp.txt
python mcp_server/server.py --transport streamable-http --host 127.0.0.1 --port 8000
```

Connect clients to `http://127.0.0.1:8000/mcp`. For local stdio clients use `python mcp_server/server.py --transport stdio`. The server requires `Rscript` on `PATH`.

Claude Code registration:

```bash
claude mcp add --transport http imprintomeR http://127.0.0.1:8000/mcp
```

## Analysis tools

- `run_methylation_qc` — runs `run_meth_QC.R` from metadata and an IDAT directory. Supports platform, QC cutoffs, QC plot/report controls, and ewastools control selection.
- `run_imprintome_analysis` — runs `run_imprintomeR.R` from either a `MethQcSet` RDS or beta plus metadata. Supports `probeset`, `plot_types`, `ids_cutoff`, `genome`, `radar_all`, `rainfall_all`, `beeswarm_chr_all`, and `skip_plots`.
- `package_info`, `list_data_files`, and `cli_help` provide discovery and help.
- `imprintomer://readme` exposes the project README.

Example request in Claude Code:

> Run `run_imprintome_analysis` with `rds="qc_results/epic/data/epic_qcset.rds"`, `outdir="imprintome_results"`, `prefix="GSE240091"`, `probeset="selected"`, `genome="hg19"`, `plot_types="default"`, and `radar_all=true`.

The tool returns the R exit code, stdout/stderr, and files created under the requested output directory. Inputs are passed as argument arrays (not shell strings); arbitrary commands are not exposed.

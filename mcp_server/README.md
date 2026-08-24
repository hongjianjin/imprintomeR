# imprintomeR MCP server

This server exposes the documented `imprintomeR` command-line workflows through MCP. Streamable HTTP is the default transport and supports simultaneous clients such as Claude Code, Codex, and Cursor.

## Deployment options

### Local clone (Claude Code or Codex)

The server runs the repository CLI and therefore needs a local clone, R, and `Rscript` on the machine running the MCP server:

```bash
git clone https://github.com/hongjianjin/imprintomeR.git
cd imprintomeR
python -m pip install -r requirements-mcp.txt
```

### No local clone

Deploy the repository and its R dependencies on an HPC node, VM, or cloud server. Expose the Streamable HTTP endpoint as a secured HTTPS URL, then configure that URL in Claude Code or Codex. Analysis and output files remain on the remote machine. Use HTTPS and authentication for shared or production deployments; do not expose an unauthenticated analysis service.

## Install and run

```bash
python -m venv .venv-mcp
. .venv-mcp/bin/activate       # Windows: .venv-mcp\Scripts\Activate.ps1
python -m pip install -r requirements-mcp.txt
python mcp_server/server.py --transport streamable-http --host 127.0.0.1 --port 8000
```

Connect clients to `http://127.0.0.1:8000/mcp`. For local stdio clients use `python mcp_server/server.py --transport stdio`. The server requires `Rscript` on `PATH`.

Cloning the repository does not automatically register the server with any AI client. The server must be running, and each client must be configured to connect to its endpoint. A hosted/web session usually cannot reach your local `127.0.0.1` address; use a desktop/CLI client on the same machine or deploy the server at a secured HTTPS URL.

Claude Code registration:

```bash
claude mcp add --transport http imprintomeR http://127.0.0.1:8000/mcp
claude mcp list
```

After registration, ask the client to call `package_info`. The response should report package version `1.1.5`. If no imprintomeR tools appear, confirm that the server process is still running, the client is using the same machine/environment, and that the endpoint is exactly `http://127.0.0.1:8000/mcp`.

Codex can use the same `http://127.0.0.1:8000/mcp` endpoint through its MCP/server settings.
## Analysis tools

- `run_methylation_qc` — runs `run_meth_QC.R` from metadata and an IDAT directory. Supports platform, QC cutoffs, QC plot/report controls, and ewastools control selection. It verifies that a `*_qcset.rds` file was exported and returns its path in `required_outputs`, ready for `run_imprintome_analysis`.
- `run_imprintome_analysis` — runs `run_imprintomeR.R` from either a `MethQcSet` RDS or beta plus metadata. Supports `probeset`, `plot_types`, `ids_cutoff`, `genome`, `radar_all`, `rainfall_all`, `beeswarm_chr_all`, and `skip_plots`.
- `package_info`, `list_data_files`, and `cli_help` provide discovery and help.
- `imprintomer://readme` exposes the project README.

### Example requests in Claude Code

QC:

> Use `run_methylation_qc` with `metadata="metadata.tsv"`, `datadir="/data/idats"`, `outdir="qc_results"`, `platform="EPIC"`, `plot_types="intensity,detection_pval,probe_coverage,beta_density"`, and `verbose=true`. Report the QC output files and any errors.

Imprintome analysis:

> Use `run_imprintome_analysis` with `rds="qc_results/epic/data/epic_qcset.rds"`, `outdir="imprintome_results"`, `prefix="GSE240091"`, `probeset="selected"`, `genome="hg19"`, `plot_types="default"`, `radar_all=true`, and `beeswarm_chr_all=true`. Report the analysis outputs and any errors.

### Example requests in Codex

QC:

> Call the `run_methylation_qc` MCP tool with `metadata="metadata.tsv"`, `datadir="/data/idats"`, `outdir="qc_results"`, `platform="EPIC"`, `plot_types="intensity,detection_pval,probe_coverage,beta_density"`, and `verbose=true`. Report the QC output files and any errors.

Imprintome analysis:

> Call the `run_imprintome_analysis` MCP tool with `rds="qc_results/epic/data/epic_qcset.rds"`, `outdir="imprintome_results"`, `prefix="GSE240091"`, `probeset="selected"`, `genome="hg19"`, `plot_types="default"`, `ids_cutoff=0.2`, `rainfall_all=true`, and `beeswarm_chr_all=true`. Report the analysis outputs and any errors.

Inputs are passed as argument arrays (not shell strings); arbitrary commands are not exposed. Each tool returns the R exit code, stdout/stderr, and files created under the requested output directory.


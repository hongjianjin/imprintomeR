#!/usr/bin/env python3
"""MCP server for imprintomeR; Streamable HTTP supports concurrent clients."""
from __future__ import annotations
import argparse, json, os, subprocess
from pathlib import Path
from typing import Any, Optional
from mcp.server.fastmcp import FastMCP
ROOT = Path(__file__).resolve().parents[1]
EXTDATA = ROOT / "inst" / "extdata"
IMP_CLI = ROOT / "inst" / "scripts" / "run_imprintomeR.R"
QC_CLI = ROOT / "inst" / "scripts" / "run_meth_QC.R"
mcp = FastMCP("imprintomeR", stateless_http=True, json_response=True)
def _json(value: Any) -> str: return json.dumps(value, indent=2, default=str)
def _path(value: str, must_exist: bool = False) -> Path:
    path = Path(value).expanduser().resolve()
    if must_exist and not path.exists(): raise ValueError(f"Path does not exist: {path}")
    return path
def _run(script: Path, args: list[str], outdir: Path) -> str:
    if not script.exists(): raise ValueError(f"CLI script not found: {script}")
    outdir.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(["Rscript", str(script), *args], cwd=ROOT, capture_output=True, text=True, check=False)
    files = [str(p.relative_to(outdir)) for p in outdir.rglob("*") if p.is_file()]
    return _json({"returncode": result.returncode, "success": result.returncode == 0, "stdout": result.stdout, "stderr": result.stderr, "output_files": sorted(files)})
@mcp.tool()
def package_info() -> str:
    """Return package version, repository path, and CLI availability."""
    version = "unknown"
    description = ROOT / "DESCRIPTION"
    if description.exists():
        for line in description.read_text(encoding="utf-8").splitlines():
            if line.startswith("Version:"): version = line.split(":", 1)[1].strip(); break
    return _json({"package": "imprintomeR", "version": version, "repository": str(ROOT), "imprintome_cli": IMP_CLI.exists(), "qc_cli": QC_CLI.exists()})
@mcp.tool()
def list_data_files() -> str:
    """List data files shipped in inst/extdata and their sizes."""
    if not EXTDATA.exists(): return _json([])
    return _json([{"name": p.name, "bytes": p.stat().st_size} for p in sorted(EXTDATA.iterdir()) if p.is_file()])
@mcp.tool()
def cli_help(workflow: str = "imprintome") -> str:
    """Return help for the imprintome or methylation-QC CLI."""
    script = IMP_CLI if workflow == "imprintome" else QC_CLI if workflow == "qc" else None
    if script is None: raise ValueError("workflow must be 'imprintome' or 'qc'")
    result = subprocess.run(["Rscript", str(script), "--help"], cwd=ROOT, capture_output=True, text=True, check=False)
    return result.stdout or result.stderr
@mcp.tool()
def run_imprintome_analysis(rds: Optional[str] = None, beta_file: Optional[str] = None, meta_file: Optional[str] = None, outdir: str = "imprintome_results", prefix: Optional[str] = None, probeset: str = "selected", plot_types: str = "default", ids_cutoff: float = 0.2, genome: str = "hg19", radar_all: bool = False, rainfall_all: bool = False, beeswarm_chr_all: bool = False, skip_plots: bool = False, verbose: bool = False) -> str:
    """Run run_imprintomeR.R using an RDS or beta+metadata input and return outputs."""
    if bool(rds) == bool(beta_file or meta_file): raise ValueError("Provide rds, or provide both beta_file and meta_file")
    if (beta_file and not meta_file) or (meta_file and not beta_file): raise ValueError("beta_file and meta_file must be supplied together")
    if probeset not in {"selected", "NanoImprint", "Joshi", "Court", "Rosenski", "Jima", "chr11p15"}: raise ValueError("Unsupported probeset")
    if genome.lower() not in {"hg19", "hg38"}: raise ValueError("genome must be hg19 or hg38")
    output = _path(outdir)
    args = ["-o", str(output), "--probeset", probeset, "--plot-types", plot_types, "--ids-cutoff", str(ids_cutoff), "--genome", genome]
    if rds: args += ["--rds", str(_path(rds, True))]
    else: args += ["--beta-file", str(_path(beta_file, True)), "--meta-file", str(_path(meta_file, True))]
    if prefix: args += ["--prefix", prefix]
    if radar_all: args += ["--radar-all", "TRUE"]
    if rainfall_all: args += ["--rainfall-all", "TRUE"]
    if beeswarm_chr_all: args += ["--beeswarm-chr-all", "TRUE"]
    if skip_plots: args += ["--skip-plots"]
    if verbose: args += ["--verbose"]
    return _run(IMP_CLI, args, output)
@mcp.tool()
def run_methylation_qc(metadata: str, datadir: str, outdir: str = "qc_results", platform: Optional[str] = None, pcutoff: float = 0.05, icutoff: float = 11, plot_types: str = "intensity,detection_pval,probe_coverage,beta_density", no_qc_plots: bool = False, no_qc_report: bool = False, skip_ewastools: bool = False, verbose: bool = False) -> str:
    """Run run_meth_QC.R on metadata and an IDAT directory and return outputs."""
    metadata_path, idat_dir, output = _path(metadata, True), _path(datadir, True), _path(outdir)
    if not metadata_path.is_file() or not idat_dir.is_dir(): raise ValueError("metadata must be a file and datadir must be a directory")
    args = ["--metadata", str(metadata_path), "--datadir", str(idat_dir), "--outdir", str(output), "--pcutoff", str(pcutoff), "--icutoff", str(icutoff), "--plot-types", plot_types]
    if platform: args += ["--platform", platform]
    if no_qc_plots: args += ["--no-qc-plots"]
    if no_qc_report: args += ["--no-qc-report"]
    if skip_ewastools: args += ["--skip-ewastools"]
    if verbose: args += ["--verbose"]
    return _run(QC_CLI, args, output)
@mcp.resource("imprintomer://readme")
def readme() -> str:
    """Expose the project README as an MCP resource."""
    path = ROOT / "README.md"
    return path.read_text(encoding="utf-8") if path.exists() else "README.md not found"
def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--transport", choices=("streamable-http", "stdio"), default="streamable-http")
    parser.add_argument("--host", default=os.getenv("MCP_HOST", "127.0.0.1")); parser.add_argument("--port", type=int, default=int(os.getenv("MCP_PORT", "8000")))
    args = parser.parse_args()
    if args.transport == "stdio": mcp.run(transport="stdio")
    else: mcp.settings.host, mcp.settings.port = args.host, args.port; mcp.run(transport="streamable-http")
if __name__ == "__main__": main()

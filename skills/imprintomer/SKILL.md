---
name: imprintomer
description: Run and interpret imprintomeR methylation QC and imprinting analyses through the MCP tools run_methylation_qc and run_imprintome_analysis. Use when an agent needs to prepare QC results, run an imprintomeR analysis, select probesets/genomes, generate plots, or report output artifacts.
---

# imprintomeR analysis skill

Use the configured imprintomeR MCP server for execution. Do not invent QC summaries or substitute an unrelated methylation workflow when the MCP tools are available.

## Tool routing

- Use `run_methylation_qc` for raw IDAT processing. It requires metadata and an IDAT directory and returns the R exit code, generated files, and the required `*_qcset.rds` path.
- Use `run_imprintome_analysis` for post-QC analysis. It accepts either that QC RDS or a beta matrix plus metadata.
- Use `package_info` to verify the server and package version, and `cli_help` when a parameter is unclear.

## QC workflow

Call `run_methylation_qc` with:

- `metadata`: TSV/CSV containing `Sample_Name` and `Basename`; `Sample_Group` is recommended.
- `datadir`: directory containing the IDAT files.
- `outdir`: dedicated output directory.
- Optional `platform`: `EPIC`, `EPICv2`, `450K`, or automatic detection.
- Optional `pcutoff`, `icutoff`, `plot_types`, `no_qc_plots`, `no_qc_report`, `skip_ewastools`, and `verbose`.

Before proceeding, require `success: true`, `returncode: 0`, and a non-empty `required_outputs` entry ending in `_qcset.rds`. Pass that exact RDS path to the imprintome analysis tool; do not guess its location.

## Imprintome workflow

Call `run_imprintome_analysis` with either:

- `rds`: a QC `MethQcSet` RDS; or
- `beta_file` and `meta_file` together for already prepared data.

Set `outdir` and a descriptive `prefix`. Select:

- `probeset`: `selected`, `NanoImprint`, `Joshi`, `Court`, `Rosenski`, `Jima`, or `chr11p15`.
- `genome`: `hg19` or `hg38`, matching the probeset annotation.
- `ids_cutoff`: numeric IDS threshold, default `0.2`.
- `plot_types`: `default`, `all`, or a comma-separated list.
- `radar_all`, `rainfall_all`, and `beeswarm_chr_all` for multipage all-sample PDFs.
- `skip_plots` only when ordinary plots should be suppressed; explicit all-sample flags remain independent.

Use `verbose=true` when diagnosing a run. Report the returned `success`, R output, and `output_files`. If the run fails, preserve the R stderr and do not claim analysis results.

## Interpretation and reproducibility

Keep the QC and imprintome stages separate. State the selected probeset, genome, IDS cutoff, input mode, and output directory in the analysis report. Check that the returned output files include the expected genome-aware imprintome RDS and result table. Do not mix hg19 and hg38 probesets.

For all-sample plots, expect filenames of the form:

- `<prefix>_<genome>_radar.<probeset>.all.pdf`
- `<prefix>_<genome>_rainfall.<probeset>.all.pdf`
- `<prefix>_<genome>_beeswarm_chr.<probeset>.all.pdf`

Use the MCP server README for connection, client registration, and concrete Claude Code/Codex prompts.

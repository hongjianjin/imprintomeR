---
name: imprintomer
description: Run and interpret imprintomeR methylation QC and genomic-imprinting analyses, including input validation, parameter selection, artifact checks, and reproducible result reporting.
usage: Use when preparing IDAT or beta-matrix inputs, running imprintomeR QC or imprinting analysis, selecting probesets and genome builds, generating plots, or troubleshooting analysis outputs.
version: 1.0.0
validated_against:
  - date: 2026-08-24
    package: imprintomeR
    package_version: 1.1.5
    checks: SKILL.md frontmatter and workflow consistency review
tags:
  - skill
  - category:pipeline
  - domain:genomics
  - domain:epigenomics
  - language:r
---

# imprintomeR analysis skill

## Overview

Guide reproducible methylation-array QC and genomic-imprinting analysis with imprintomeR. Use the configured MCP server to execute the package workflows; the skill provides routing, parameter, validation, and reporting guidance.

## When To Use

Use this skill when the user asks to:

- Run QC from IDAT files and metadata.
- Run imprintome analysis from a QC RDS or beta plus metadata.
- Choose a probeset, genome build, IDS cutoff, or plot set.
- Generate or verify radar, rainfall, or chromosome-beeswarm artifacts.
- Diagnose missing outputs, cache reuse, or QC-to-analysis handoff problems.

## Inputs and Assumptions

- Raw QC requires metadata (TSV/CSV) with `Sample_Name` and `Basename`; `Sample_Group` is recommended.
- QC also requires an IDAT directory with minfi-compatible files.
- Imprintome analysis accepts either a `MethQcSet` RDS or both a beta matrix and metadata file.
- Beta matrices have probes as rows and samples as columns; sample identifiers must align with metadata.
- The execution environment has R, `Rscript`, imprintomeR, and the configured MCP server available.
- Defaults are `pcutoff = 0.05`, `icutoff = 11`, `ids_cutoff = 0.2`, and `genome = hg19`.

## Workflow and Tool Calls

1. Verify the integration with `package_info`; use `cli_help` when a parameter or supported value is unclear.
2. For raw arrays, call `run_methylation_qc` with `metadata`, `datadir`, and a dedicated `outdir`. Set `platform` only when automatic detection should be overridden.
3. Require `success: true`, `returncode: 0`, and a non-empty `required_outputs` entry ending in `_qcset.rds`. Pass that exact path to the next tool; never guess the RDS location.
4. Call `run_imprintome_analysis` with either `rds` or `beta_file` plus `meta_file`, and set `outdir`, `prefix`, `probeset`, `genome`, `ids_cutoff`, and `plot_types` explicitly when reproducibility matters.
5. Set `radar_all`, `rainfall_all`, or `beeswarm_chr_all` to true for multipage all-sample PDFs. `skip_plots` suppresses ordinary plots but does not suppress explicit all-sample outputs.
6. Use `verbose = true` for diagnostics and preserve the returned R stdout/stderr.

Supported probesets are `selected`, `NanoImprint`, `Joshi`, `Court`, `Rosenski`, `Jima`, and `chr11p15`. Supported genome builds are `hg19` and `hg38`; do not mix a probeset annotation with the wrong genome.

## Validation

For QC, confirm:

- `success` is true and `returncode` is zero.
- `required_outputs` contains the exported `*_qcset.rds`.
- The returned output list includes expected QC tables and plots when requested.

For imprintome analysis, confirm:

- `success` is true and `returncode` is zero.
- The output list includes the genome-aware imprintome RDS and requested result table.
- The selected probeset, genome, IDS cutoff, input mode, and output directory are reported.
- Any warnings or R stderr are reported without claiming unsupported conclusions.

## Output Expectations

Standard analysis artifacts include:

```text
<prefix>_<genome>_imprintomeSet.rds
<prefix>_<genome>_results_AnalyzeImprintStatus.<probeset>.tsv
<prefix>_<genome>_radar.<probeset>.<sampleID>.pdf
<prefix>_<genome>_rainfall.<probeset>.<sampleID>.pdf
<prefix>_<genome>_radar.<probeset>.all.pdf
<prefix>_<genome>_rainfall.<probeset>.all.pdf
<prefix>_<genome>_beeswarm_chr.<probeset>.all.pdf
```

Chromosome-beeswarm plots retain only chromosomes with at least five finite probes for a sample. Report skipped samples, missing files, and failed pages explicitly.

## Reproducibility and Safety

Keep QC and imprintome stages separate and use a dedicated output directory per run. Preserve the exact parameters and returned artifact list. Do not expose arbitrary shell execution through the skill; pass validated paths and argument values to the MCP tools only.

For client registration and concrete Claude Code/Codex prompts, read `mcp_server/README.md`.

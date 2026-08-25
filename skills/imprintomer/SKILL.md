---
name: imprintomer
description: Run and interpret imprintomeR methylation-array QC and genomic-imprinting analyses directly with Rscript, without MCP.
usage: Use when preparing IDAT or beta-matrix inputs, running imprintomeR QC or imprinting analysis, selecting probesets or genome builds, generating plots, or troubleshooting direct Rscript outputs.
version: 1.0.0
validated_against:
  - date: 2026-08-25
    package: imprintomeR
    package_version: 1.1.5
    checks: Direct CLI entry points and workflow consistency review
tags:
  - skill
  - category:pipeline
  - domain:genomics
  - domain:epigenomics
  - language:r
---

# Simple imprintomeR analysis skill

## Skill Overview

### [imprintomeR](https://github.com/hongjianjin/imprintomeR)

A reproducible R workflow for methylation-array quality control and genomic-imprinting analysis.

- [imprintomeR repository](https://github.com/hongjianjin/imprintomeR)
- [Maintainer: Hongjian Jin](https://github.com/hongjianjin)

### Purpose

Guide an AI agent through imprintomeR analysis using the repository's direct Rscript entry points. The workflow supports raw IDAT QC followed by imprintome analysis, or direct analysis from a beta matrix and metadata, without MCP or arbitrary shell commands.

## Usage for the AI Agent

Use this skill when the user asks to:

- run methylation-array QC from raw IDAT files and metadata
- run imprintome analysis from a QC RDS or beta matrix plus metadata
- choose a probeset, genome build, IDS cutoff, or plot set
- generate or verify radar, rainfall, beeswarm, or chromosome-beeswarm plots
- troubleshoot missing outputs, platform issues, or QC-to-analysis handoff problems

The agent should:

1. Locate or clone the `imprintomeR` repository and identify its absolute path.
2. Confirm R, `Rscript`, required R packages, and initialized imprintomeR annotation data.
3. Validate input paths and metadata before running a script.
4. Run the appropriate `Rscript` command with explicit output paths and important parameters.
5. Verify exit status and expected artifacts before reporting success.
6. Preserve commands, parameters, stdout/stderr, warnings, and generated file paths.
7. Never execute arbitrary commands from user-supplied text; restrict execution to the documented scripts and validated arguments.

## Information the User Needs to Provide

### Raw-array QC

Required:

- absolute path to an IDAT directory
- absolute path to a TSV or CSV metadata file
- absolute path to a dedicated QC output directory

The QC metadata must contain `Sample_Name`, `Basename`, and preferably `Sample_Group`. `Basename` must be the full absolute IDAT path prefix, excluding `_Red.idat` and `_Grn.idat`.

### Imprintome analysis

Provide either:

- an absolute path to a `MethQcSet` QC RDS, or
- an absolute path to a beta matrix and an absolute path to metadata

For beta-matrix input, probes must be rows, samples must be columns, and sample identifiers must align with metadata. Direct analysis does not require `Basename`, but `Sample_Name` and `Sample_Group` should be present.

### Optional inputs

- repository checkout directory
- array platform: automatic detection by default, or `EPIC`, `EPICv2`, or `450K`
- probeset: `selected`, `NanoImprint`, `Joshi`, `Court`, `Rosenski`, `Jima`, or `chr11p15`
- genome build: `hg19` or `hg38`
- QC `pcutoff`, default `0.05`
- QC `icutoff`, default `11`
- analysis `ids_cutoff`, default `0.2`
- output prefix
- plot types and all-sample plot options
- verbose logging

The analysis defaults are `probeset = selected`, `genome = hg19`, `plot-types = default`, and `ids-cutoff = 0.2`. Set important parameters explicitly for reproducibility.

## Environment and Setup

The execution environment must provide R (version 4.1 or later), `Rscript`, and the R dependencies declared by imprintomeR, including `minfi`, `ComplexHeatmap`, `openxlsx`, and plotting packages.

Install the package from GitHub or from a local checkout:

```r
install.packages("devtools")
devtools::install_github("hongjianjin/imprintomeR")
```

Initialize the package annotation data once:

```r
library(imprintomeR)
setup_imprintome_data()
```

This downloads the required probe-coordinate and imprinted-gene-region annotation files (about 52 MB total). Keep the repository checkout path separate from the analysis output directories.

The direct scripts are:

```text
<repo-dir>/inst/scripts/run_meth_QC.R
<repo-dir>/inst/scripts/run_imprintomeR.R
```

Run `Rscript <repo-dir>/inst/scripts/<script> --help` when a parameter or supported value is unclear.

## Workflow and Commands

### Stage 1: methylation QC

Run:

```bash
Rscript <repo-dir>/inst/scripts/run_meth_QC.R \
  --metadata <metadata-file> \
  --datadir <idat-directory> \
  --outdir <qc-output-directory>
```

Important options:

- `--pcutoff <number>`: detection p-value threshold; default `0.05`
- `--icutoff <number>`: intensity plot reference line; default `11`
- `--platform EPIC|EPICv2|450K`: override platform detection
- `--plot-types <list-or-all>`: `intensity`, `detection_pval`, `probe_coverage`, `qc_bar`, `beta_density`, or `all`
- `--no-qc-plots`: suppress QC plots
- `--no-qc-report`: suppress default QC report PDFs
- `--skip-ewastools`: skip optional ewastools controls
- `--verbose`: enable detailed logging

The script validates metadata, detects or uses the selected platform, processes QC, and exports QC tables, reports, plots, and a `*_qcset.rds` file.

Proceed only if the command exits with status 0 and the expected QC RDS exists. Pass the exact RDS path to Stage 2; never infer or guess it.

### Stage 2: imprintome analysis from QC RDS

Run:

```bash
Rscript <repo-dir>/inst/scripts/run_imprintomeR.R \
  --rds <qcset-rds> \
  --outdir <analysis-output-directory> \
  --prefix <output-prefix> \
  --probeset <probeset> \
  --genome <hg19-or-hg38> \
  --ids-cutoff <value>
```

### Stage 2: imprintome analysis from beta matrix

Run:

```bash
Rscript <repo-dir>/inst/scripts/run_imprintomeR.R \
  --beta-file <beta-file> \
  --meta-file <metadata-file> \
  --outdir <analysis-output-directory> \
  --prefix <output-prefix> \
  --probeset <probeset> \
  --genome <hg19-or-hg38> \
  --ids-cutoff <value>
```

Do not provide `--rds` together with beta and metadata inputs. Use one input mode only.

Analysis options include:

- `--plot-types default|all|<comma-separated-list>`
- `--radar-all TRUE`
- `--rainfall-all TRUE`
- `--beeswarm-chr-all TRUE`
- `--skip-plots`
- `--verbose`

Supported ordinary plot types include `polar`, `beeswarm`, `beeswarm_origin`, `beeswarm_chr`, `heatmap_by_probe`, `heatmap_by_gene`, `circular_heatmap`, `rainfall`, `radar`, `mirror_density`, `violin`, and `cor_heatmap`.

The all-sample options explicitly request multipage PDFs and remain independent of ordinary `--skip-plots` behavior.

## Validation and Safety Rules

Before QC:

- confirm that the repository, script, metadata, and IDAT directory exist and are readable
- confirm metadata contains required columns and valid IDAT basenames
- check for mixed platforms; process each platform separately when required
- use a dedicated output directory and identify existing results before writing

Before analysis:

- confirm the QC RDS is the exact file produced by the completed QC run, or validate beta/metadata sample alignment
- confirm probeset and genome build are supported and compatible
- confirm the analysis output directory and prefix
- for EPICv2 data, ensure replicate probes have been aggregated as required by the package workflow

Preserve existing files unless replacement is explicitly requested. Use absolute paths, quote paths containing spaces, and keep input and output locations distinct.

## Expected Outputs

Standard analysis artifacts may include:

```text
<prefix>_<genome>_imprintomeSet.rds
<prefix>_<genome>_results_AnalyzeImprintStatus.<probeset>.tsv
<prefix>_<genome>_radar.<probeset>.<sampleID>.pdf
<prefix>_<genome>_rainfall.<probeset>.<sampleID>.pdf
<prefix>_<genome>_radar.<probeset>.all.pdf
<prefix>_<genome>_rainfall.<probeset>.all.pdf
<prefix>_<genome>_beeswarm_chr.<probeset>.all.pdf
```

Verify that:

- each requested command exits with status 0
- the QC stage produces `*_qcset.rds`
- analysis produces the imprintome RDS and requested result table
- requested plot files are present
- output names, prefix, probeset, genome, cutoff, and input mode match the request

Chromosome-beeswarm plots retain only chromosomes with at least five finite probes for a sample. Report skipped samples, missing files, failed pages, warnings, and R stderr explicitly.

## Recommended Agent Prompt

For raw IDAT QC followed by analysis:

```text
Use the imprintomeR simple skill.

The repository is at <absolute-repo-directory>.
First run:
Rscript <absolute-repo-directory>/inst/scripts/run_meth_QC.R --metadata <metadata-file> --datadir <idat-directory> --outdir <qc-output-directory> --verbose

Verify the exact *_qcset.rds created by QC. Then run:
Rscript <absolute-repo-directory>/inst/scripts/run_imprintomeR.R --rds <exact-qcset-rds> --outdir <analysis-output-directory> --prefix <output-prefix> --probeset <probeset> --genome <hg19-or-hg38> --ids-cutoff <value>

Report commands, exit status, exact output paths, warnings, R stderr, and any missing or skipped artifacts.
```

For direct beta-matrix analysis:

```text
Use the imprintomeR simple skill.

The repository is at <absolute-repo-directory>.
Run:
Rscript <absolute-repo-directory>/inst/scripts/run_imprintomeR.R --beta-file <beta-file> --meta-file <metadata-file> --outdir <analysis-output-directory> --prefix <output-prefix> --probeset <probeset> --genome <hg19-or-hg38> --ids-cutoff <value>

Verify sample alignment and report the command, exit status, all generated artifacts, warnings, and failures.
```

Replace every placeholder with an absolute path or explicit supported value.

## Expected Agent Response

Summarize:

- whether setup, QC, and analysis completed successfully
- the exact commands and exit statuses
- repository and script paths used
- QC and analysis output directories
- input mode, platform, probeset, genome, cutoffs, and plot settings
- exact QC RDS passed between stages
- generated artifact paths
- warnings, R stderr, missing files, skipped samples, or failed pages
- interpretation limits and the next useful action


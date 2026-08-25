# imprintomeR Agent Skill

An Agent Skills-compatible skill for running the `imprintomeR` R package workflows directly with `Rscript`.

This skill teaches an agent how to:

- validate metadata and methylation-array inputs
- run platform-aware QC from raw IDAT files
- hand the exported `*_qcset.rds` to imprintome analysis
- run imprinting analysis from a QC RDS or beta matrix plus metadata
- generate and verify standard and all-sample plots
- inspect logs, warnings, and output artifacts

## What the user needs to provide

### Raw-array QC

Required:

- an absolute IDAT directory
- a TSV or CSV metadata file
- a dedicated QC output directory

Metadata must contain `Sample_Name` and `Basename`; `Sample_Group` is recommended. `Basename` may be an absolute IDAT prefix or relative to the IDAT directory.

### Imprintome analysis

Provide either:

- an absolute path to a `MethQcSet` QC RDS, or
- an absolute beta-matrix path and metadata path

Beta matrices use probes as rows and samples as columns. Sample identifiers must align with metadata.

Optional parameters include `EPIC`, `EPICv2`, or `450K` platform selection, probeset, genome (`hg19` or `hg38`), `ids_cutoff` (default `0.2`), plot types, output prefix, and all-sample plot flags.

## Workflow defaults and supported values

Unless the user specifies otherwise, use `probeset = selected`, `genome = hg19`, `plot-types = default`, `ids-cutoff = 0.2`, QC `pcutoff = 0.05`, and QC `icutoff = 11`. Supported array platforms are automatic detection, `EPIC`, `EPICv2`, and `450K`.

Supported ordinary plot types are `polar`, `beeswarm`, `beeswarm_origin`, `beeswarm_chr`, `heatmap_by_probe`, `heatmap_by_gene`, `circular_heatmap`, `rainfall`, `radar`, `mirror_density`, `violin`, and `cor_heatmap`.

The all-sample flags `--radar-all TRUE`, `--rainfall-all TRUE`, and `--beeswarm-chr-all TRUE` explicitly generate multipage PDFs. They remain independent of ordinary `--skip-plots` behavior.`r`n`r`n## Environment and setup

The machine running the workflow needs R (>= 4.1), `Rscript`, imprintomeR, and its declared dependencies. From a local checkout:

```bash
git clone https://github.com/hongjianjin/imprintomeR.git
cd imprintomeR
R CMD INSTALL .
```

The direct entry points are:

```text
<repo-dir>/inst/scripts/run_meth_QC.R
<repo-dir>/inst/scripts/run_imprintomeR.R
```

Use `Rscript <script> --help` when a parameter or supported value is unclear.

## Recommended agent prompts

For raw IDAT QC followed by imprintome analysis:

```text
Use the imprintomeR skill.

The repository is at <absolute-repo-directory>.
Run run_meth_QC.R with metadata <metadata-file>, IDAT directory <idat-directory>, and QC output <qc-output-directory>.
Verify that the run succeeded and identify the exact *_qcset.rds created.
Then run run_imprintomeR.R with that exact RDS, output <analysis-output-directory>, prefix <prefix>, probeset selected, genome hg19, and ids-cutoff 0.2.
Report commands, exit statuses, warnings, and exact output paths.
```

For direct beta-matrix analysis:

```text
Use the imprintomeR skill.

The repository is at <absolute-repo-directory>.
Run run_imprintomeR.R with beta file <beta-file>, metadata <metadata-file>, output <analysis-output-directory>, prefix <prefix>, probeset selected, genome hg19, and ids-cutoff 0.2.
Verify sample alignment, exit status, result tables, and requested plot artifacts.
```

## Direct command-line use

QC:

```bash
Rscript <repo-dir>/inst/scripts/run_meth_QC.R \
  --metadata <metadata-file> \
  --datadir <idat-directory> \
  --outdir <qc-output-directory> \
  --platform EPIC \
  --verbose
```

Imprintome analysis from QC RDS:

```bash
Rscript <repo-dir>/inst/scripts/run_imprintomeR.R \
  --rds <qcset-rds> \
  --outdir <analysis-output-directory> \
  --prefix <prefix> \
  --probeset selected \
  --genome hg19 \
  --ids-cutoff 0.2 \
  --plot-types default
```

All-sample plot options are explicit:

```bash
--radar-all TRUE
--rainfall-all TRUE
--beeswarm-chr-all TRUE
```

## Expected outputs

QC must produce a `*_qcset.rds` under the QC output directory. Analysis artifacts commonly include:

```text
<prefix>_<genome>_imprintomeSet.rds
<prefix>_<genome>_results_AnalyzeImprintStatus.<probeset>.tsv
<prefix>_<genome>_radar.<probeset>.<sampleID>.pdf
<prefix>_<genome>_rainfall.<probeset>.<sampleID>.pdf
<prefix>_<genome>_radar.<probeset>.all.pdf
<prefix>_<genome>_rainfall.<probeset>.all.pdf
<prefix>_<genome>_beeswarm_chr.<probeset>.all.pdf
```

Chromosome-beeswarm plots retain only chromosomes with at least five finite probes per sample.

## Validation and troubleshooting

Confirm each command exits with status 0 and inspect stdout/stderr and the run log. Do not report success when the QC RDS, result table, or requested plot is missing. Keep the exact probeset, genome, IDS cutoff, input mode, prefix, and output directory in the report. For EPICv2 data, aggregate replicate probes as required before conversion to `ImprintomeSet`.

If output is missing, run with `--verbose`, call `--help`, verify the installed imprintomeR version, and check that the selected genome resource contains the requested probeset.

## Files in this skill

- [`SKILL.md`](SKILL.md) — core agent instructions and workflow rules.
- [`README.md`](README.md) — this usage guide.

The skill provides guidance only; it does not replace R, the package dependencies, or the direct CLI scripts.

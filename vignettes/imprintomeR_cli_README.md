# imprintomeR Command-Line Workflows

This guide describes the package-installed command-line scripts for running methylation QC and imprinting analysis with `imprintomeR`.

The two scripts are installed under `inst/scripts/` in the source package:

```text
inst/scripts/run_meth_QC.R
inst/scripts/run_imprintomeR.R
```

After installing the package, the scripts can also be located from R:

```bash
Rscript $(Rscript -e 'cat(system.file("scripts/run_meth_QC.R", package="imprintomeR"))') --help
Rscript $(Rscript -e 'cat(system.file("scripts/run_imprintomeR.R", package="imprintomeR"))') --help
```

## Workflow Overview

1. Run `run_meth_QC.R` on raw IDAT files to create a `MethQcSet` and QC output files.
2. Run `run_imprintomeR.R` on the QC RDS, or on beta plus metadata files, to create an `ImprintomeSet`, run imprinting analysis, save plot PDFs, and export result tables.

The recommended end-to-end workflow is:

```bash
Rscript inst/scripts/run_meth_QC.R \
  -m metadata.tsv \
  -b /data/idats \
  -o qc_results \
  --platform EPIC \
  -v

Rscript inst/scripts/run_imprintomeR.R \
  -r qc_results/epic/data/epic_qcset.rds \
  -o imprintome_results \
  --prefix GSE240091 \
  --probeset selected \
  --plot-types default \
  -v
```

## Step 1: Methylation QC CLI

`run_meth_QC.R` processes IDAT files and exports a `MethQcSet` object plus QC tables and plots. By default, it also writes beta-density PDFs from the `MethQcSet` beta matrix and raw minfi density PDFs from `minfi::qcReport()` for all, PASS, and FAIL samples.

### Inputs

Metadata should be TSV or CSV and include:

| Column | Required | Notes |
|--------|----------|-------|
| `Sample_Name` | Yes | Unique sample identifier. |
| `SAMPLE_NAME` | Backward compatible | Accepted and normalized to `Sample_Name`. |
| `Basename` | Yes | IDAT prefix, with or without the `--datadir` parent path. |
| `Sample_Group` | Recommended | Added automatically if missing. |

IDAT files should use minfi-compatible names:

```text
<Basename>_Red.idat
<Basename>_Grn.idat
```

Compressed `.idat.gz` files are accepted. Lowercase `*_red.idat` / `*_green.idat` files are renamed to `*_Red.idat` / `*_Grn.idat` when needed.

### Basic QC Run

```bash
Rscript inst/scripts/run_meth_QC.R \
  -m metadata.tsv \
  -b /data/idats \
  -o qc_results
```

### Useful QC Options

| Option | Default | Description |
|--------|---------|-------------|
| `--platform` | auto-detect | Override platform detection: EPIC, EPICv2, 450K, or 27K. |
| `--pcutoff` / `-p` | 0.05 | Detection p-value threshold used for `Final.QC`. |
| `--icutoff` / `-i` | 11 | Reference line for intensity plots only. Low intensity no longer fails `Final.QC`. |
| `--plot-types` | intensity,detection_pval,probe_coverage,beta_density | QC plots: `intensity`, `detection_pval`, `probe_coverage`, `qc_bar`, `beta_density`, or `all`. |
| `--no-qc-plots` | FALSE | Suppress QC plot generation. |
| `--no-qc-report` | FALSE | Suppress default QC report PDFs: root review PDFs plus secondary reports in `plots/`. |
| `--skip-ewastools` | FALSE | Skip optional ewastools control metrics. |
| `--verbose` / `-v` | FALSE | Print detailed progress messages. |

### QC Outputs

For an EPIC run, the output directory typically contains:

```text
qc_results/
+-- epic/
|   +-- epic_summary.txt
|   +-- epic_qc_table_main.xlsx
|   +-- epic_QC_detection_pval.pdf         # default root review plot
|   +-- epic_QC_probe_coverage.pdf         # default root review plot
|   +-- epic_QC_minfiDensity_all.pdf       # default root minfi density report
|   +-- data/
|   |   +-- epic_qcset.rds
|   |   +-- epic_beta.txt
|   |   +-- epic_meta.txt
|   +-- QC_tables/
|   |   +-- epic_qc_table_extra.xlsx
|   |   +-- epic_qc_matrix.txt
|   |   +-- epic_qc_statistics.txt
|   |   +-- epic_qc_recall_rate.txt
|   |   +-- epic_qc_cutoffs.txt
|   |   +-- epic_qc_ctrl_metrics.txt
|   |   +-- epic_qc_contamination.txt
|   |   +-- epic_qc_predUniqDonor_ID.txt
|   |   +-- epic_qc_qc_report_files.txt
|   +-- plots/
|       +-- epic_QC_intensity.pdf
|       +-- epic_QC_betaDensity_all.pdf    # cache-friendly
|       +-- epic_QC_betaDensity_pass.pdf   # cache-friendly
|       +-- epic_QC_betaDensity_fail.pdf   # if FAIL samples exist
|       +-- epic_QC_minfiDensity_pass.pdf  # fresh IDAT QC only
|       +-- epic_QC_minfiDensity_fail.pdf  # fresh IDAT QC only, if FAIL samples exist
|       +-- qc_intensity.png
|       +-- qc_detection_pval.png
|       +-- qc_probe_coverage.png
|       +-- qc_beta_density.png
+-- run_meth_QC.log
```

The complete QC object is saved as `data/{platform}_qcset.rds`, for example:

```text
qc_results/epic/data/epic_qcset.rds
```

`run_meth_QC.R` reuses this cached RDS only when it is a `MethQcSet`, the platform matches, and the cached `Sample_Name` set matches the current metadata. PNG QC plots and beta-density PDFs can be regenerated from cache. Raw minfi density PDFs require IDAT reload; remove the cached RDS to force a full rerun when `{platform}_QC_minfiDensity_*.pdf` files are needed. If the script warns that `runMethQC()` does not support density-report output, reinstall/update `imprintomeR` so the loaded package version matches the CLI script.

## Step 2: Imprintome Analysis CLI

`run_imprintomeR.R` runs post-QC imprinting analysis. It can start from either a `MethQcSet` RDS or beta plus metadata files.

### Recommended Input: MethQcSet RDS

```bash
Rscript inst/scripts/run_imprintomeR.R \
  -r qc_results/epic/data/epic_qcset.rds \
  -o imprintome_results \
  --prefix GSE240091 \
  --probeset selected \
  -v
```

When `Final.QC` is available in the `MethQcSet`, the runner keeps QC-pass samples using:

```r
qcset_pass <- subsetMethQC(qcset, final_qc = "PASS")
```

If no sample has `Final.QC == "PASS"`, the script stops.

### Alternative Input: Beta and Metadata Files

```bash
Rscript inst/scripts/run_imprintomeR.R \
  -b /data/beta.txt \
  -m /data/meta.txt \
  -o imprintome_results \
  --prefix beta_run \
  --probeset selected
```

The beta matrix should have probes as rows and samples as columns. Metadata should contain `Sample_Name`; `Sample_Group` is preferred.

### Useful Analysis Options

| Option | Default | Description |
|--------|---------|-------------|
| `--rds` / `-r` | NA | Input `MethQcSet` RDS file. |
| `--beta-file` / `-b` | NA | Beta matrix file, required unless `--rds` is used. |
| `--meta-file` / `-m` | NA | Metadata file, required unless `--rds` is used. |
| `--outdir` / `-o` | required | Output directory. |
| `--prefix` / `-p` | basename of `outdir` | Dataset prefix for result, plot, and RDS filenames; the normalized genome is appended automatically. |
| `--probeset` | selected | One of `selected`, `NanoImprint`, `Joshi`, `Court`, `Rosenski`, `Jima`, `chr11p15`. |
| `--plot-types` | default | Comma-separated plot types, `default`, or `all`. |
| `--ids-cutoff` | 0.2 | IDS cutoff passed to `runImprintome()`. |
| `--genome` | hg19 | Genome build for bundled probesets. |
| `--skip-plots` | FALSE | Skip the ordinary plot workflow; explicit `--radar-all` and `--beeswarm-chr-all` outputs still run. |
| `--radar-all` | NULL | Pass `TRUE` to generate one multipage radar PDF containing every sample. |
| `--beeswarm-chr-all` | NULL | Pass `TRUE` to generate one multipage chromosome-beeswarm PDF containing every sample. |
| `--verbose` / `-v` | FALSE | Print detailed progress messages. |

## Plot Types

`--plot-types default` uses the standard workflow plot set from `runImprintomeVisualizations()`:

- `polar`
- `beeswarm_origin`
- `mirror_density`
- `heatmap_by_probe`
- `heatmap_by_gene`
- `radar`
- `beeswarm_chr`
- `rainfall`

`circular_heatmap` is not included in `default`. Request it explicitly when needed:

```bash
Rscript inst/scripts/run_imprintomeR.R \
  -r qc_results/epic/data/epic_qcset.rds \
  -o imprintome_results \
  --prefix GSE240091 \
  --plot-types circular_heatmap
```

`--plot-types all` includes all supported plot types, including `circular_heatmap`, `beeswarm`, `violin`, and `cor_heatmap`.

Plots are saved directly as PDF files and are not embedded in the exported `ImprintomeSet` RDS. This keeps the cached RDS smaller.

### Radar Plots For All Samples

Pass `--radar-all TRUE` to generate one multipage radar PDF with one 8 x 8 inch page per sample:

```bash
Rscript inst/scripts/run_imprintomeR.R \
  -r qc_results/epic/data/epic_qcset.rds \
  -o imprintome_results \
  --prefix GSE240091 \
  --probeset selected \
  --radar-all TRUE
```

When enabled, the ordinary single-sample `radar` entry is removed from the regular plot workflow. All-sample radar generation is explicit and independent of `--skip-plots`. The PDF is written directly under the output directory as `<prefix>_<genome>_radar.<probeset>.all.pdf`. Omitting `--radar-all` preserves the existing single-sample radar behavior.

### Chromosome Beeswarm For All Samples

Pass `--beeswarm-chr-all TRUE` to generate one multipage PDF with one 10 x 4 inch page per sample:

```bash
Rscript inst/scripts/run_imprintomeR.R \
  -r qc_results/epic/data/epic_qcset.rds \
  -o imprintome_results \
  --prefix GSE166531 \
  --probeset chr11p15 \
  --beeswarm-chr-all TRUE
```

When enabled, the ordinary single-sample `beeswarm_chr` entry is removed from the regular plot workflow. Multipage generation is explicit and independent of `--skip-plots`. The PDF is written directly under the output directory as `<prefix>_<genome>_beeswarm_chr.<probeset>.all.pdf`.

Each page shows only chromosomes with at least five usable (finite) probe values for that sample.


## Imprintome Outputs

A typical analysis directory contains:

```text
imprintome_results/
+-- run_imprintomeR.log
+-- GSE240091_hg19_imprintomeSet.rds
+-- GSE240091_hg19_results_AnalyzeImprintStatus.selected.tsv
+-- GSE240091_hg19_polar.selected.pdf
+-- GSE240091_hg19_heatmap_by_gene.selected.pdf
+-- GSE240091_hg19_radar.<sample_id>.pdf
```

The main result table is stored as `AnalyzeImprintStatus.<probeset>` inside `results(x)` and exported as a genome-prefixed TSV file.

Example reload:

```r
library(imprintomeR)
x <- readRDS("imprintome_results/GSE240091_hg19_imprintomeSet.rds")
names(results(x))
status <- results(x)[["AnalyzeImprintStatus.selected"]]
```

## Imprintome RDS Cache Behavior

The runner saves a lean object as:

```text
<prefix>_<genome>_imprintomeSet.rds
```

The object contains beta values, metadata, probeset data, and result tables, but not stored plot objects.

The same dataset and genome share this RDS across probesets. Different genomes use separate cache files. On later runs:

- If the cached RDS contains `AnalyzeImprintStatus.<probeset>` with matching genome and `--ids-cutoff` provenance, analysis is skipped and requested plot/result files are regenerated without overwriting the RDS.
- If the requested probeset result is absent, or its stored `--ids-cutoff` differs, core analysis is rerun for that probeset and the lean RDS is updated. Recalculation replaces that probeset's prior result while preserving other named probeset results.
- Plot PDFs are generated directly and are not saved back into the RDS.

## End-to-End Example For HPC

```bash
module load R/4.2.2

Rscript inst/scripts/run_meth_QC.R \
  -m GSE240091_metadata.tsv \
  -b GSE240091_raw/idats \
  -o GSE240091_qc \
  --platform EPIC \
  --plot-types all \
  -v

Rscript inst/scripts/run_imprintomeR.R \
  -r GSE240091_qc/epic/data/epic_qcset.rds \
  -o GSE240091_imprintome \
  --prefix GSE240091 \
  --probeset selected \
  --plot-types default \
  -v
```

For installed packages, use `system.file()` to avoid hard-coding the source tree path:

```bash
QC_SCRIPT=$(Rscript -e 'cat(system.file("scripts/run_meth_QC.R", package="imprintomeR"))')
IMP_SCRIPT=$(Rscript -e 'cat(system.file("scripts/run_imprintomeR.R", package="imprintomeR"))')

Rscript "$QC_SCRIPT" -m metadata.tsv -b /data/idats -o qc_results -v
Rscript "$IMP_SCRIPT" -r qc_results/epic/data/epic_qcset.rds -o imprintome_results --prefix GSE240091 -v
```

## Troubleshooting

### `imprintomeR` package not found

Install the package into the R library used by the job or Jupyter kernel:

```r
install.packages("/path/to/imprintomeR", repos = NULL, type = "source")
```

### IDAT files not found

Check `Basename` and `--datadir`. `Basename` can be a full IDAT prefix or a prefix relative to `--datadir`.

### No samples with `Final.QC == "PASS"`

The imprintome runner stops because there are no QC-clean samples to analyze. Review `qc_tables(qcset)$QC_matrix` from the QC stage.

### Plot PDFs are missing

Run with `--verbose` and try a smaller plot set first:

```bash
--plot-types polar,heatmap_by_gene
```

Some plots require enough samples, enough probes, or metadata columns such as `Sample_Group`.

## Quick Output Checklist

After QC:

```text
qc_results/<platform>/data/<platform>_qcset.rds
qc_results/<platform>/<platform>_qc_table_main.xlsx
qc_results/<platform>/plots/
```

After imprintome analysis:

```text
imprintome_results/<prefix>_<genome>_imprintomeSet.rds
imprintome_results/<prefix>_<genome>_results_AnalyzeImprintStatus.<probeset>.tsv
imprintome_results/<prefix>_<genome>_<plot_name>.pdf
imprintome_results/<prefix>_<genome>_radar.<probeset>.all.pdf
imprintome_results/<prefix>_<genome>_beeswarm_chr.<probeset>.all.pdf
```

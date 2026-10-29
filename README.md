<h1><img src="images/logo_small.png" alt="imprintomeR Logo" width="200" style="vertical-align: middle; margin-right: 10px;" />imprintomeR</h1>

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23741652.svg)](https://doi.org/10.5281/zenodo.23741652)

imprintomeR measures and visualizes genomic imprinting disturbance from Illumina 450K, EPICv1 and EPICv2 methylation arrays. Starting from IDAT files, it runs quality control (QC) and preprocessing, then scores each sample at imprinting control regions (ICRs):

- **Scores:**
  - The Imprinting Deviation Index (IDI), (β − 0.5) × 2, places each probe on a −1 to 1 scale, where 0 is the half-methylated state expected at an ICR.
  - From the paternal and maternal deviations, the Imprinting Deviation Score (IDS) gives each sample's overall deviation, and the Angle gives its direction. Bootstrap confidence intervals are optional.
- **Per-ICR calls:** each ICR is scored on its own, with a multi-locus summary per sample.
- **Reference centring:** scores can be centred on control samples from the same study.
- **Plots:** polar plots (IDS and Angle), radar plots (median IDI per ICR), rainfall plots (IDI per probe), beeswarm plots and per-ICR heatmaps.

The workflow is built on two S4 classes:

- **MethQcSet:** QC results and preprocessed data for one array platform.
- **ImprintomeSet:** scores and annotations, ready for analysis and plotting.

Every step can be run from R or with the command-line scripts in `inst/scripts/` (see the [command-line guide](vignettes/imprintomeR_cli_README.md)).

## Table of Contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [Workflow](#workflow)
- [Core Formulas](#core-formulas)
- [Main analysis options](#main-analysis-options)
- [Quality control](#quality-control)
- [Bundled probesets](#bundled-probesets)
- [Plots](#plots)
- [Documentation](#documentation)
- [MCP server and agent skill](#mcp-server-and-agent-skill)
- [Test Suite](#test-suite)
- [Maintainers](#maintainers) · [Contact](#contact) · [SessionInfo](#sessioninfo)

## Installation

```r
devtools::install_github("hongjianjin/imprintomeR")
```

The QC dependency [ewastools](https://github.com/hhhh5/ewastools) is not on CRAN; `install_github()` installs it from GitHub automatically (DESCRIPTION `Remotes: hhhh5/ewastools`). The annotation files (about 52 MB: probe annotation and the ICR probe panels, hg19 and hg38) are installed with the package under `inst/extdata/`; if one is missing, imprintomeR prints a note when it loads and `setup_imprintome_data()` downloads it.

hg38 (GRCh38) is the default genome; pass `genome = "hg19"` (CLI `--genome hg19`) for GRCh37 coordinates. Probe IDs, parental-origin labels and `DMR_type` are the same in both builds for every probe-level panel except `Jima` (two extra probes in hg38), so scores do not depend on the build.

## Quick start

```r
library(imprintomeR)

# 1. QC, one array platform at a time
meta  <- LoadMeta("meta.tsv")         # Sample_Name, Sample_Group and Basename (IDAT path prefix)
meta  <- check_platform(meta)         # adds the Platform column
qcset <- runMethQC(meta[meta$Platform == "EPIC", ], outdir = "qc_output", prefix = "epic")
export(qcset, outdir = "qc_output", prefix = "epic", format = c("xlsx", "rds"))   # QC report, all samples

# 2. Imprinting analysis (in a later session: qcset <- readRDS("qc_output/data/epic_qcset.rds"))
qcset <- subsetMethQC(qcset, final_qc = "PASS")   # keep samples that passed QC
# EPICv2 only: qcset <- aggregate_probes(qcset)
x <- as.ImprintomeSet(qcset)          # bundled hg38 panels
x <- runImprintome(x, probeset = "selected")

# 3. Plot and export
plot(x, plot_type = "polar", outFile = "polar.pdf")
export(x, outdir = "imprintome_results", prefix = "study", save_plots = TRUE)
```

Each step is described in [docs/qc.md](docs/qc.md) and [docs/analysis.md](docs/analysis.md).

## Workflow

<p align="center">
  <img src="images/workflow.jpg" alt="imprintomeR workflow" width="720" />
</p>

```
Metadata + IDAT files (one or more platforms)
    ↓
[check_platform(meta)] → detect the array platform of each sample
    ↓
Subset meta by platform
    ↓
[runMethQC(meta_platform)] → read IDATs → normalize beta (noob by default) + detection p-values
                           → QC metrics, Final.QC PASS/FAIL per sample → MethQcSet
    ↓
[subsetMethQC(qcset, final_qc = "PASS")] → keep passing samples
    ↓
[aggregate_probes(qcset)] → EPICv2 only: collapse replicate probes (required)
    ↓
[as.ImprintomeSet(qcset)] → ImprintomeSet with the bundled panels (hg38 by default)
    ↑
    └── or ImprintomeSet(beta, meta, ...) for data already QC-cleaned elsewhere
    ↓
[runImprintome()] → IDS, Angle and Mechanism per sample
                  (+ per-ICR calls and multi-locus summary with icr = TRUE;
                     bootstrap intervals with n_boot)
    ↓
[plot() / export()] → plots and result tables
```

Each `MethQcSet` holds one platform, so cohorts on different arrays are never merged before QC. In code, `check_platform()`, `runMethQC(platform = )` and the `Platform` column use the values `"450K"`, `"EPIC"` (EPICv1) and `"EPICv2"`.

## Core Formulas

- Imprinting Deviation Index (**IDI**): (beta - 0.5) × 2
- Imprinting Deviation Score (**IDS**): √((paternal_median - 0.5)² + (maternal_median - 0.5)²)
- **Deviation Angle**: atan2(maternal_median - 0.5, paternal_median - 0.5)
- With a control reference, 0.5 is replaced by each probe's median beta across the controls: paternal/maternal deviations are medians of (beta − reference), and IDS and Angle are computed from these deviations (see [Reference centring](docs/analysis.md#reference-centring-and-infinium-design-types)).

The paternal and maternal classes come from the probeset's `ORIGIN` annotation, and array beta values are bulk, not allele-specific, measurements. IDS and Angle are therefore descriptive summaries along the annotated parental axes, not parent-of-origin calls. The default IDS cutoff (0.2) and confidence tiers (0.1/0.2/0.4) are exploratory screening conventions; calibrate them on tissue-matched controls where possible ([Uncertainty and calibration](docs/analysis.md#uncertainty-and-calibration)). More on the geometry: [docs/analysis.md](docs/analysis.md).

### Angle Direction Mapping
Each 45-degree sector of the polar plot is labelled with the direction of shift along the annotated paternal and maternal axes, such as paternal gain or maternal loss of methylation, or global hypo- or hypermethylation. Each label covers the 45° sector centred on the angle in the table (for example, Pat-Gain covers 337.5° to 22.5°). Samples with IDS < 0.2 are labelled ROI (retention of imprinting). The labels are exploratory directional summaries of bulk beta values, not parent-of-origin molecular calls; with `n_boot`, `Mechanism_support` reports how stable a sample's label is under resampling.

| Angle (°) | Sector (°) | `Mechanism` label |
|---:|---|---|
| 0 | 337.5 – 22.5 | `Pat-Gain` |
| 45 | 22.5 – 67.5 | `Global-Hyper` |
| 90 | 67.5 – 112.5 | `Mat-Gain` |
| 135 | 112.5 – 157.5 | `Mat-Gain+Pat-Loss` |
| 180 | 157.5 – 202.5 | `Pat-Loss` |
| 225 | 202.5 – 247.5 | `Global-Hypo` |
| 270 | 247.5 – 292.5 | `Mat-Loss` |
| 315 | 292.5 – 337.5 | `Pat-Gain+Mat-Loss` |

## Main analysis options

`runImprintome()` arguments (command-line flags of `run_imprintomeR.R` in brackets). Details and examples: [docs/analysis.md](docs/analysis.md).

| Argument | Default | What it does |
|---|---|---|
| `probeset` [`--probeset`] | `"selected"` | Probe panel to score (see [Bundled probesets](#bundled-probesets)) |
| `dmr_type` [`--dmr-type`] | gametic ICRs for `selected` | `"all"` scores every probe; `"secondary"` reports secondary DMRs separately |
| `reference_group` / `reference_beta` [`--reference-group` / `--reference-file`] | fixed 0.5 | Centre scores on in-cohort or external tissue-matched controls ([Reference centring](docs/analysis.md#reference-centring-and-infinium-design-types)) |
| `infinium_type` [`--infinium-type`] | all probes | `"balanced"` averages type I and type II deviations |
| `icr` [`--icr`] | `FALSE` | Adds per-ICR calls, the multi-locus summary and the `icr_heatmap` plot ([Per-ICR scores](docs/analysis.md#per-icr-scores-and-icr-balanced-ids)) |
| `balance` [`--balance icr`] | probe-pooled | `"icr"` weights each ICR equally in IDS/Angle |
| `n_boot`, `n_perm` | 0 | Bootstrap intervals and `Mechanism_support`; origin permutation test (control reference only) ([Uncertainty](docs/analysis.md#uncertainty-and-calibration)) |
| `ids_cutoff` | 0.2 | IDS below which a sample is labelled ROI; `CalibrateIDS()` derives a cohort cutoff from controls |

## Quality control

`runMethQC()` marks each sample `Final.QC = "PASS"` when both hold:

1. at least 95% of probes are detected at p < `pcutoff` (default 0.05; `runMethQC(..., pcutoff = )` or `run_meth_QC.R --pcutoff`);
2. the ewastools Bisulfite Conversion I Green and Red control metrics are both at least 1 (`CtrlMetrics.QC`); if ewastools cannot run, only criterion 1 applies.

All other metrics (other control metrics, intensities, predicted sex, SNP contamination, donor IDs) are reported, not used. Beta values are noob-normalized by default (`"noob_swan"` and `"raw"` are alternatives). Normalization, QC tables, plots and export files: [docs/qc.md](docs/qc.md).

## Bundled probesets

`probesets_hg19.rds` and `probesets_hg38.rds` hold the same eleven panels: the probe-level `Jima`, `Joshi`, `Court`, `Rosenski`, `selected`, `NanoImprint`, `chr11p15` and `chr20q13` (GNAS) panels, and the region-level `Rosenski_region`, `chr11p15_region` and `chr20q13_region`. Every probe-level panel carries parental-origin (`ORIGIN`), `ICR_name`, `DMR_type` (following Monk et al., 2018) and Infinium design type.

`selected`, the default, keeps the probes present in at least two of `Court`, `Jima`, `Joshi` and `Rosenski` that are on the 450K array and on EPICv1 and/or EPICv2: 782 probes, all on 450K, 742 on EPICv1 and 683 on EPICv2. How the panels and `selected` were built, with the platform table: [docs/probesets.md](docs/probesets.md).

## Plots

`plot(x, plot_type = ...)` on an `ImprintomeSet`:

| Plot type | Shows |
|---|---|
| `polar` (and `auto`) | IDS and Angle of every sample |
| `radar` | Median IDI of each ICR, one sample |
| `rainfall` | IDI of each probe along the genome, one sample |
| `beeswarm`, `beeswarm_origin`, `beeswarm_chr` | Probe beta values by sample, by parental origin, or by chromosome |
| `mirror_density` | Maternal vs paternal beta distributions |
| `violin` | Beta distribution of each sample |
| `heatmap_by_probe`, `heatmap_by_gene`, `circular_heatmap`, `cor_heatmap` | Probe, gene, circular and sample-correlation heatmaps |
| `icr_heatmap` | Per-ICR deviations, samples × ICRs (after `runImprintome(icr = TRUE)`) |

```r
p <- plot(x, plot_type = "polar", result_name = "AnalyzeImprintStatus.selected",
          colorColumn = "Sample_Group", outFile = "polar.pdf")
x <- runImprintomeVisualizations(x, plot_types = "default", probeset = "selected")
```

Colours by parental origin follow the `ORIGIN` annotation (legend "Annotated parental origin"), not allele-specific measurements. QC plots on a `MethQcSet` take `type =` instead of `plot_type =`. All plot types with examples: [docs/plots.md](docs/plots.md).

## Documentation

- [docs/qc.md](docs/qc.md): QC preprocessing, normalization, QC tables, merging and export files
- [docs/analysis.md](docs/analysis.md): `ImprintomeSet`, scoring options, reference centring, per-ICR calls, uncertainty and calibration, export
- [docs/plots.md](docs/plots.md): all plot types with examples
- [docs/probesets.md](docs/probesets.md): bundled panels, how `selected` was built, platform coverage
- [vignettes/imprintomeR_cli_README.md](vignettes/imprintomeR_cli_README.md): command-line QC and analysis
- R vignettes: `vignette("imprintomeset-quickstart")`, `vignette("imprintomeset-results-export")`, `vignette("imprintomeR-workflow-basic")` (core functions without S4 objects)
- Worked GEO examples (GitHub-renderable notebooks, with Markdown versions):
  - [GSE52567.ipynb](vignettes/GSE52567.ipynb) ([Markdown](vignettes/GSE52576.md)): GSE52576, androgenetic and parthenogenetic samples
  - [GSE240091.ipynb](vignettes/GSE240091.ipynb) ([Markdown](vignettes/GSE240091.md)): QC and analysis of an EPIC cohort
  - [GSE74738.ipynb](vignettes/GSE74738.ipynb) ([Markdown](vignettes/GSE74738.md)): 450K placentas scored against their own controls, with per-ICR calls, bootstrap intervals, the origin permutation test and a control-calibrated cutoff

## MCP server and agent skill

An optional MCP server ([mcp_server/README.md](mcp_server/README.md)) exposes the QC and analysis command-line workflows to Claude Code, Codex, Cursor and other MCP clients, through `run_methylation_qc` and `run_imprintome_analysis`. An Agent Skills-compatible skill ([skills/imprintomer/SKILL.md](skills/imprintomer/SKILL.md), [README](skills/imprintomer/README.md)) guides AI agents through those tools; it provides guidance only.

## Test Suite

The testthat suite (`tests/testthat/`) covers the S4 classes, QC, normalization, probeset annotation, genome routing, scoring, reference centring, per-ICR calls, uncertainty, plotting and export: `devtools::test("path/to/imprintomeR")`.

## Maintainers

- **Hongjian Jin** (maintainer), hongjian.jin@stjude.org, ORCID [0000-0003-3833-7170](https://orcid.org/0000-0003-3833-7170)
- **Gang Wu**, gang.wu@stjude.org, ORCID [0000-0002-1678-5864](https://orcid.org/0000-0002-1678-5864)

Center for Applied Bioinformatics, St. Jude Children's Research Hospital, Memphis, TN 38105, USA.

## Contact

- **Bug reports, questions and feature requests:** open an issue at https://github.com/hongjianjin/imprintomeR/issues, with the imprintomeR version (`packageVersion("imprintomeR")`), the command or code you ran and the error message.
- **Other enquiries:** email the maintainer, Hongjian Jin (hongjian.jin@stjude.org).
- **Citing imprintomeR:** use the "Cite this repository" button on GitHub (from `CITATION.cff`) or the Zenodo DOI [10.5281/zenodo.23741652](https://doi.org/10.5281/zenodo.23741652).

## SessionInfo

The R session used to build and test imprintomeR 1.5.0 (R 4.3.3), with the versions of the declared dependencies, is recorded in [vignettes/sessionInfo.md](vignettes/sessionInfo.md); 1.5.2 changes no dependencies.

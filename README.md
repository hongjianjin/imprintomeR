# imprintomeR

imprintomeR provides allele-aware analysis and visualization of genomic imprinting from methylation array data. The package enforces a **preprocessing-first workflow** using formal S4 containers:

- **MethQcSet**: Single-platform QC and preprocessing  
- **ImprintomeSet**: Analysis-ready container for imprinting studies

## Installation

Install the latest development version:

```r
# Using devtools
devtools::install_github("hongjianjin/imprintomeR")

# Or from local source
devtools::install("path/to/imprintomeR")
```

After installation, download required data files:

```r
library(imprintomeR)
setup_imprintome_data()  # Downloads annotation files on first use
```

This downloads two annotation files (total ~52 MB):
- CpG probe coordinates and annotations
- ICR (Imprinted Gene Region) probeset definitions

For more details on data file management, see `data-raw/README.md`.

## Table of Contents

- [Installation](#installation)
- [Architecture: Preprocessing-First Workflow](#architecture-preprocessing-first-workflow)
- [Recommended Workflow](#recommended-workflow)
  - [Step 1: QC Preprocessing (MethQcSet)](#step-1-qc-preprocessing-methqcset--optional-if-data-already-cleaned)
  - [Step 2: Create Analysis Container (ImprintomeSet)](#step-2-create-analysis-container-imprintomeset)
  - [Step 3: Run Imprinting Analysis](#step-3-run-imprinting-analysis)
  - [Step 4–7: Summarize, Visualize, Export](#step-4-7-summarize-visualize-export)
- [Detailed Examples](#detailed-examples)
  - [MethQcSet: Platform-Specific Preprocessing](#methqcset-platform-specific-preprocessing)
  - [ImprintomeSet: Analysis Container](#imprintomeset-analysis-container)
  - [Run Imprinting Analysis](#run-imprinting-analysis)
  - [Summarize & Inspect](#summarize--inspect)
- [Visualization](#visualization)
  - [Available Plot Types](#available-plot-types)
  - [Example Plots](#example-plots)
- [Export Results](#export-results)
- [Testing](#testing)
- [Core Formulas](#core-formulas)
- [Vignettes](#vignettes)

## Architecture: Preprocessing-First Workflow

Raw methylation arrays often come from mixed platforms (450K, EPICv1, EPICv2). The **MethQcSet** container isolates QC processing for a single platform, preventing silent data corruption from cross-platform merging.

```
Metadata + IDAT Files (mixed platforms)
    ↓
[check_platform(meta)] → detect array platform per sample
    ↓
Subset meta by platform
    ↓
[runMethQC(meta_platform)] → load IDAT → extract beta + p-values → QC metrics → MethQcSet
    ↓
Per-platform QC-clean MethQcSet
    ↓
[as.ImprintomeSet()]
    ↓
[runImprintome()] → Analysis results (IDS, Angle, etc.)
    ↓
Visualize & Export
```

## Recommended workflow

### Step 1: QC Preprocessing (MethQcSet) — Optional if Data Already Cleaned

**If you have RAW data:**

`meta.tsv` must be a tab-delimited file with at least `Sample_Name` and `Basename` columns. Additional columns (e.g., group, sex, diagnosis) are carried through and available for plotting.

```
Sample_Name    Basename                                   Sample_Group    SEX
SampleA        /data/idats/202301234567_R01C01            Control         F
SampleB        /data/idats/202301234567_R02C01            Case            M
SampleC        /data/idats/202301234568_R01C01            Control         F
SampleD        /data/idats/202301234568_R02C01            Case            M
```

> `Basename` must be the full path prefix to the IDAT files, i.e. the path without `_Red.idat` / `_Grn.idat`.

```r
library(imprintomeR)

# Load metadata (requires Basename column with IDAT path prefixes)
meta <- LoadMeta("meta.tsv")

# Option A: platform unknown or mixed — detect first
meta <- check_platform(meta)   # reads IDAT probe counts; appends Platform column
table(meta$Platform)           # inspect; split if multiple platforms present

meta_epic <- meta[meta$Platform == "EPIC", ]
# meta_epic looks like:
#   Sample_Name    Basename                              Sample_Group    SEX    Platform
#   SampleA        /data/idats/202301234567_R01C01        Control         F      EPIC
#   SampleC        /data/idats/202301234568_R01C01        Control         F      EPIC
qcset <- runMethQC(meta_epic)  # platform auto-resolved from meta$Platform

# Option B: platform already known
# qcset <- runMethQC(meta, platform = "EPIC")

# Inspect QC results
qc_summary <- qc_summarize(qcset)
str(qc_summary)
# $qc_status : table of Final.QC PASS/FAIL counts
# $qc_tables : names of populated qc_tables keys

# Access QC_matrix directly
qc_matrix <- qc_tables(qcset)[["QC_matrix"]]
table(qc_matrix$Final.QC)

# Visualize QC metrics (all plot() calls return a ggplot2 object)
p_bar  <- plot(qcset, type = "qc_bar",          outFile = "qc_bar.pdf")          # PASS/FAIL bar chart (default)
p_int  <- plot(qcset, type = "intensity",        icutoff = 11,
               outFile = "qc_intensity.pdf")                                       # mMed vs uMed scatter
p_dp   <- plot(qcset, type = "detection_pval",   pcutoff = 0.05,
               outFile = "qc_aveDetPval.pdf")                                    # avg detection p-val per sample
p_cov  <- plot(qcset, type = "probe_coverage",   outFile = "qc_probe_coverage.pdf") # % probes detected per sample
p_sex  <- plot(qcset, type = "predicted_sex",    outFile = "qc_predicted_sex.pdf")  # predicted sex distribution
p_ctrl <- plot(qcset, type = "ctrl_metrics",         outFile = "qc_ctrl_metrics.pdf")   # ewastools scores (if available)
plot(qcset, type = "ctrl_metrics_detail",            outFile = "qc_ctrl_detail")         # per-metric PDFs (Bisulfite/Specificity)

# Export cleaned data
# xlsx: single workbook — meta (+ Platform, Final.QC), QC_matrix,
#   recall_rate, cutoffs, ctrl_metrics, contamination, predUniqDonor_ID
export(qcset, outdir = "qc_output", format = c("xlsx", "rds"))
```

> **Already have QC-cleaned data?** Skip to [Step 2 Option B](#step-2-create-analysis-container-imprintomeset) and construct `ImprintomeSet` directly from `beta` + `meta`.

Key MethQcSet features:

- **Platform validation**: Prevents mixing 450K, EPICv1, EPICv2
- **QC metrics**: Detection p-values, intensity summaries (mMed/uMed/aveMed merged into `QC_matrix`), probe coverage
- **Canonical `qc_tables` keys** (populated by `runMethQC()`):
  - `QC_matrix` — per-sample detection stats, intensity, predictedSex, `Final.QC`
  - `recall_rate` — per-probe % detected across all / PASS / FAIL samples
  - `cutoffs` — QC threshold criteria and values
  - `ctrl_metrics` — control probe metrics (if ewastools available)
  - `contamination` — SNP agreement / sample-swap check (if ewastools available)
  - `predUniqDonor_ID` — predicted unique donors per sample group (if ewastools available)
- **EPICv2 aggregation required**: Replicate probes (e.g. `cg..._TC11`, `cg..._TC12`) must be collapsed to base probe IDs before conversion — `aggregate_probes()` is a required step for EPICv2 (`as.ImprintomeSet()` will error if skipped)
- **Merge operations**: Synchronized metadata/beta alignment (`merge()`)
- **Export workflow**: Write QC tables, beta values, metadata to disk (`export()`)

### Step 2: Create Analysis Container (ImprintomeSet)

Once QC-approved, convert to analysis-ready object:

```r
# Option A: convert from a MethQcSet (recommended — carries platform/assay automatically)

# EPICv2 only: aggregate replicate probes first (required)
# as.ImprintomeSet() will error if this step is skipped for EPICv2.
if (qcset@platform == "EPICv2") {
  qcset <- aggregate_probes(qcset)  # ~937k → ~865k unique base probes
}

x <- as.ImprintomeSet(
  qcset,
  probeset = probesets[["selected"]],
  genome = "hg19"
)

# Option B: build directly from beta + meta (QC already done externally)
probesets <- readRDS(system.file("extdata", "probesets_hg19.rds", package = "imprintomeR"))
meta <- LoadMeta("meta.tsv")
beta <- LoadBeta("cleaned_beta.tsv")   # probes × samples matrix, already QC-filtered

x <- ImprintomeSet(
  beta    = beta,
  meta    = meta,
  probeset = probesets[["selected"]],
  genome  = "hg19",
  assay   = "EPIC"                     # "450K" | "EPIC" | "EPICv2"
)

# Either way, x is ready for analysis
# x now contains: beta, meta, probeset, genome, assay
```

### Step 3: Run Imprinting Analysis

```r
x <- runImprintome(
  x,
  probeset = "selected",
  ids_cutoff = 0.2
)

# Results stored in results(x)
names(results(x))
```

### Step 4-7: Summarize, Visualize, Export

```r
s <- summarize(x)

p <- plot(x, plot_type = "polar", result_name = "AnalyzeImprintStatus.selected",
          colorColumn = "Sample_Group", outFile = "polar.pdf")

manifest <- export(x, outdir = "imprintome_export", save_plots = TRUE)
```

## Detailed Examples

### MethQcSet: Platform-Specific Preprocessing

```r
library(imprintomeR)

# Load metadata with Basename column (IDAT path prefixes)
meta <- LoadMeta("meta.tsv")

# Platform unknown: detect from IDAT files first
meta <- check_platform(meta)
table(meta$Platform)

# Run QC for one platform at a time
meta_epic <- meta[meta$Platform == "EPIC", ]
qcset_epic <- runMethQC(meta_epic)           # platform auto-resolved

meta_450k <- meta[meta$Platform == "450K", ]
qcset_450k <- runMethQC(meta_450k)

# Platform known: pass directly
# qcset <- runMethQC(meta, platform = "EPIC")

# Export QC results
# xlsx: single workbook (prefix_qc_tables.xlsx) with sheets:
#   meta, QC_matrix, recall_rate, cutoffs, ctrl_metrics,
#   contamination, predUniqDonor_ID
# rds:  single complete MethQcSet object (prefix_qcset.rds) for downstream analysis
exported_files <- export(
  qcset_epic,
  outdir = "qc_results",
  format = c("xlsx", "rds")
)
```

The xlsx workbook contains one sheet per table:

&nbsp;

<table style="width:100%; border-collapse:collapse;">
<thead>
<tr>
  <th style="width:18%; text-align:left; border-bottom:2px solid #ccc;">Sheet</th>
  <th style="width:67%; text-align:left; border-bottom:2px solid #ccc;">Content</th>
  <th style="width:15%; text-align:left; border-bottom:2px solid #ccc;">Source</th>
</tr>
</thead>
<tbody>
<tr><td><code>meta</code></td><td>Sample metadata</td><td>always</td></tr>
<tr><td><code>QC_matrix</code></td><td>Per-sample detection stats, intensity (mMed/uMed/aveMed), predictedSex, <code>Final.QC</code></td><td>always</td></tr>
<tr><td><code>recall_rate</code></td><td>Per-probe % detected across all / PASS / FAIL samples</td><td>always</td></tr>
<tr><td><code>cutoffs</code></td><td>QC threshold criteria and values (log2 intensity, detection p-val, % CpG)</td><td>always</td></tr>
<tr><td><code>ctrl_metrics</code></td><td>Control probe metrics + <code>CtrlMetrics.QC</code></td><td>if ewastools available</td></tr>
<tr><td><code>contamination</code></td><td>SNP agreement check for sample swaps</td><td>if ewastools available</td></tr>
<tr><td><code>predUniqDonor_ID</code></td><td>Predicted unique donor IDs per sample group</td><td>if ewastools available</td></tr>
</tbody>
</table>

&nbsp;

Beta values are excluded from xlsx (too large) and saved as `.rds` only.

```r
# Inspect MethQcSet structure
str(qcset_epic)
# Formal class 'MethQcSet' [package "imprintomeR"] with 6 slots
#   @ beta              : num [1:866895, 1:4] 0.152 0.892 0.654 0.723 ...
#   @ meta              :'data.frame': 4 obs. of 4 variables:
#   @ detection_pval    : num [1:866895, 1:4] 0.001 0.001 0.001 0.001 ...
#   @ qc_tables         :List of 5
#     $ QC_matrix      : 'data.frame': 4 obs. of 13 variables (detection stats, intensity, predictedSex, Final.QC)
#     $ recall_rate    : 'data.frame': 866895 obs. of 4 variables (per-probe % detected)
#     $ cutoffs        : 'data.frame': 5 obs. of 2 variables (QC threshold criteria)
#     $ ctrl_metrics   : 'data.frame' (if ewastools available)
#     $ contamination  : 'data.frame' (if ewastools available)
#   @ platform          : chr "EPIC"
#   @ aggregation_status: logi FALSE

# Inspect QC_matrix: includes intensity, predictedSex, Final.QC
qc_matrix <- qc_tables(qcset_epic)[["QC_matrix"]]
head(qc_matrix[, c("Sample_Name", "mMed.Intensity", "aveMed.Intensity",
                    "pctDetectedCpG_dP0.05", "predictedSex", "Final.QC")])

# Per-probe recall
recall <- qc_tables(qcset_epic)[["recall_rate"]]
head(recall[order(recall$pct_detected_all), ])

# QC cutoffs
qc_tables(qcset_epic)[["cutoffs"]]
```

Merge multiple QC-clean single-platform datasets:

```r
# Two single-platform MethQcSet objects (from separate runMethQC() calls)
qcset1 <- runMethQC(meta1, platform = "EPIC")
qcset2 <- runMethQC(meta2, platform = "EPIC")

# Synchronized merge
merged <- merge(qcset1, qcset2, how = "inner")

# Find common elements
common <- find_intersection(qcset1, qcset2, by = c("samples", "probes"))
```

### ImprintomeSet: Analysis Container

Convert QC-clean data to analysis container:

```r
# Load probeset annotations
probesets <- readRDS(system.file("extdata", "probesets_hg19.rds", package = "imprintomeR"))

# Convert from MethQcSet
x <- as.ImprintomeSet(
  qcset,
  probeset = probesets[["selected"]],
  genome = "hg19"
)

# Or construct directly
x <- ImprintomeSet(
  beta = beta,
  meta = meta,
  probeset = probesets[["selected"]],
  genome = "hg19",
  assay = "EPICv1"
)
```

### Run Imprinting Analysis

```r
x <- runImprintome(
  x,
  probeset = "selected",
  ids_cutoff = 0.2
)

res <- results(x)[["AnalyzeImprintStatus.selected"]]
head(res)
```

### Summarize & Inspect

```r
# Inspect ImprintomeSet structure
str(x)
# Formal class 'ImprintomeSet' [package "imprintomeR"] with 7 slots
#   @ beta      : num [1:865, 1:4] 0.152 0.892 0.654 0.723 ...
#   @ meta      :'data.frame': 4 obs. of 4 variables (Sample_Name, Basename, Sample_Group, SEX)
#   @ probeset  :'data.frame': 120 obs. of 8 variables (probeset annotations: Name, UCSC_RefGene_Name, Chromosome, etc.)
#   @ genome    : chr "hg19"
#   @ assay     : chr "EPIC"
#   @ results   :List of 1
#     $ AnalyzeImprintStatus.selected: 'data.frame': 120 obs. of 8 variables (IDS, Angle, IDI, etc.)
#   @ plots     :List of 0 (empty until populated by plot() calls)

# Summarize results
s <- summarize(x)
s$object
s$results
s$plots
```

## Visualization

### Available plot types

- `auto` - smart dispatch
- `polar` - IDS vs Angle scatter
- `mirror_density` - maternal/paternal distributions
- `beeswarm` - cohort probe methylation
- `beeswarm_origin` - origin-split beeswarm
- `beeswarm_chr` - chromosome-faceted beeswarm
- `violin`, `heatmap`, `circular_heatmap`, `cor_heatmap`, `rainfall`, `radar`

### Example plots

```r
# Polar plot
p_polar <- plot(
  x,
  plot_type = "polar",
  result_name = "AnalyzeImprintStatus.selected",
  colorColumn = "SAMPLE_GROUP",
  outFile = "polar.pdf"
)

# Beeswarm by origin (cohort)
p_bee_origin <- plot(
  x,
  plot_type = "beeswarm_origin",
  probeset = "selected",
  SAMPLEID = "Sample_Name",
  outFile = "beeswarm_origin.pdf"
)

# Rainfall plot (single sample)
sample_id1 <- colnames(beta(x))[1]
p_rainfall <- plot(
  x,
  plot_type = "rainfall",
  sample_id = sample_id1,
  probeset = "classifier3",
  outFile = paste0("rainfall_", sample_id1, ".pdf")
)
```

## Export Results

```r
manifest <- export(
  x,
  outdir = "imprintome_results",
  save_plots = TRUE,
  plot_device = "pdf"
)
```

## Testing

imprintomeR includes a comprehensive test pipeline that validates both QC preprocessing (Phase 1) and analysis workflows (Phase 2).

### Phase 1: QC Preprocessing (MethQcSet)

The Phase 1 test validates QC workflows across three scenarios:
- **EPICv1 only** - Single platform, no aggregation required
- **EPICv2 only** - Single platform with probe aggregation (replicate collapse)
- **Mixed EPICv1/EPICv2** - Multi-platform detection and per-platform QC

```bash
# Run Phase 1 QC tests
Rscript test_methqcset_rms.R
```

**Output:**
- `results_epic*/*.qc_tables.xlsx` — Workbook with QC metrics (meta, QC_matrix, recall_rate, cutoffs, ctrl_metrics, etc.)
- `results_epic*/*_qcset.rds` — Complete serialized MethQcSet object for downstream analysis

### Phase 2: ImprintomeSet Analysis

The Phase 2 test validates the full analysis workflow:
- Load QC-cleaned `_qcset.rds` files from Phase 1
- Create ImprintomeSet objects
- Run `runImprintome()` core analysis
- Generate 10+ visualization types
- Export results as XLSX and TSV

```bash
# Run Phase 2 analysis tests (requires Phase 1 RDS files)
Rscript test_imprintomeset.R
```

**Output:**
- `results_epic*/analysis_results.xlsx` — Analysis results (IDS, Angle, mechanism classification)
- `results_epic*/*.pdf` — Visualization plots (polar, beeswarm, violin, heatmap, rainfall, radar, etc.)

### Full Pipeline Test

Run both phases end-to-end with validation and error checking:

```bash
# Complete QC → Analysis pipeline
bash test_full_imprintomeset_pipeline.sh
```

This script:
1. **Phase 1**: Executes `test_methqcset_rms.R` (generates `_qcset.rds` files)
2. **Phase 2**: Executes `test_imprintomeset.R` (loads RDS, runs analysis + visualizations)
3. **Validation**: Confirms all output directories and key files are present
4. **Logging**: Writes timestamped logs to `test_*.log`

### Writing Your Own Tests

To test with your own data:

```r
library(imprintomeR)

# Phase 1: QC
meta <- LoadMeta("your_meta.tsv")
meta <- check_platform(meta)
qcset <- runMethQC(meta[meta$Platform == "EPIC", ])

# Optional: EPICv2 aggregation
if (qcset@platform == "EPICv2") {
  qcset <- aggregate_probes(qcset)
}

export(qcset, outdir = "your_qc_output", format = c("xlsx", "rds"))

# Phase 2: Analysis
qcset <- readRDS("your_qc_output/*_qcset.rds")
x <- as.ImprintomeSet(qcset, probeset = probesets[["selected"]])
x <- runImprintome(x, probeset = "selected", ids_cutoff = 0.2)

# Visualize and export
plot(x, plot_type = "polar", outFile = "polar.pdf")
export(x, outdir = "your_analysis_output", save_plots = TRUE)
```

## Core Formulas

- **IDS**: √((paternal_median - 0.5)² + (maternal_median - 0.5)²)
- **Angle**: Direction from (0.5, 0.5) to (paternal, maternal)
- **IDI**: (beta - 0.5) × 2

## Vignettes

For detailed workflows, see:

- `vignette("imprintomeset-quickstart")` - Quick start
- `vignette("imprintomeR-workflow")` - End-to-end workflow
- `vignette("imprintomeset-results-export")` - Visualization and export

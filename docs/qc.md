# Quality control and preprocessing (MethQcSet)

[← Back to README](../README.md)

QC runs on one array platform at a time and produces a `MethQcSet`. Samples are marked `Final.QC` PASS or FAIL; none are removed until `subsetMethQC()`.

## Step 1: QC Preprocessing (MethQcSet) — Optional if Data Already Cleaned

**If you have RAW data:**

`meta.tsv` must be a tab-delimited file with at least `Sample_Name` and `Sample_Group` columns.

**For QC workflow (Option A — raw IDAT files):** also include `Basename` column (full path prefix to IDAT files).

**For direct analysis (Option B — QC already done externally):** `Basename` is not needed; just `Sample_Name` and `Sample_Group` suffice.

Additional columns (e.g., sex, diagnosis) are carried through and available for plotting.

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

# QC plot/report PDFs are written by default:
#   epic_QC_detection_pval.pdf and epic_QC_probe_coverage.pdf in qc_output/
#   epic_QC_minfiDensity_all.pdf in qc_output/ (raw minfi RGChannelSet)
#   epic_QC_intensity.pdf, epic_QC_betaDensity_all/pass/fail.pdf,
#     and epic_QC_minfiDensity_pass/fail.pdf in qc_output/plots/
# qcset <- runMethQC(meta_epic, outdir = "qc_output", prefix = "epic")
# Use save_qc_report = FALSE to suppress default QC plot/report PDFs.

# Beta normalization (default "noob"; also "noob_swan", or "raw" as in earlier versions).
# The method is recorded in qc_params(qcset)$normalization.
# qcset <- runMethQC(meta_epic, normalization = "noob_swan")

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
p_den  <- plot(qcset, type = "beta_density",      sample_set = "all",
               outFile = "qc_beta_density_all.pdf")                              # beta-value density per sample
p_cov  <- plot(qcset, type = "probe_coverage",   outFile = "qc_probe_coverage.pdf") # % probes detected per sample
p_sex  <- plot(qcset, type = "predicted_sex",    outFile = "qc_predicted_sex.pdf")  # predicted sex distribution
p_ctrl <- plot(qcset, type = "ctrl_metrics",         outFile = "qc_ctrl_matrix_summary.pdf")   # ewastools scores
plot(qcset, type = "ctrl_metrics_detail",            outFile = "qc_ctrl_matrix_detail")         # per-metric PDFs (Bisulfite/Specificity)

# Export cleaned data: two workbooks ({prefix}_qc_table_main.xlsx and
#   QC_tables/{prefix}_qc_table_extra.xlsx) and data/{prefix}_qcset.rds
#   (see Export QC Results)
export(qcset, outdir = "qc_output", prefix = "epic", format = c("xlsx", "rds"))
```

**QC pass criteria.** A sample is `Final.QC = "PASS"` when both hold:

1. at least 95% of probes are detected at p < `pcutoff` (default 0.05, i.e. `pctDetectedCpG_dP0.05 >= 95`; set it with `runMethQC(..., pcutoff = 0.01)` or `run_meth_QC.R --pcutoff 0.01`; detection p-values from `minfi::detectionP()`);
2. `CtrlMetrics.QC` is PASS, which means that the ewastools Bisulfite Conversion I Green and Red control metrics are both at least 1. If the ewastools step cannot run (or `run_meth_QC.R --skip-ewastools` is used), only criterion 1 applies.

All other values are reported for review and do not affect `Final.QC`: the other control metrics (staining, extension, hybridization, specificity and so on), median intensities, predicted sex, SNP contamination and predicted donor IDs. `subsetMethQC(qcset, final_qc = "PASS")` keeps the passing samples.

> **Already have QC-cleaned data?** Skip to [Step 2 Option B](analysis.md#step-2-create-analysis-container-imprintomeset) and construct `ImprintomeSet` directly from `beta` + `meta`.

Key MethQcSet features:

- **Platform validation**: Prevents mixing 450K, EPICv1 and EPICv2
- **QC metrics**: Detection p-values, intensity summaries (mMed/uMed/aveMed merged into `QC_matrix`), probe coverage
- **Default QC plot/report PDFs**: `runMethQC(..., outdir = "qc_output", prefix = "epic")` writes, unless `save_qc_report = FALSE`:
  - review PDFs in `outdir`: `{prefix}_QC_detection_pval.pdf`, `{prefix}_QC_probe_coverage.pdf`, `{prefix}_QC_minfiDensity_all.pdf`;
  - report PDFs in `outdir/plots/`: `{prefix}_QC_intensity.pdf`, `{prefix}_QC_betaDensity_all/pass/fail.pdf`, `{prefix}_QC_minfiDensity_pass/fail.pdf`.
- **Beta normalization** (`runMethQC(..., normalization = )`; CLI `run_meth_QC.R --normalization`):
  - `"noob"` (default): minfi noob background and dye-bias correction;
  - `"noob_swan"`: adds SWAN type I/II adjustment (fixed seed, reproducible);
  - `"raw"`: unnormalized beta.

  All three normalize each sample on its own and work on 450K, EPICv1 and EPICv2. Detection p-values, intensities and predicted sex always use unnormalized data. The method is stored in `qc_params(qcset)$normalization` and carried into `BuildReferenceProfile()` profiles; use the same method for cohorts and the reference profiles they are centred on. EPICv2 needs the `IlluminaHumanMethylationEPICv2manifest` and `IlluminaHumanMethylationEPICv2anno.20a1.hg38` packages (Bioconductor >= 3.19); `runMethQC()` sets the EPICv2 minfi annotation automatically, because earlier minfi releases do not recognize the array.
- **Canonical `qc_tables` keys** (populated by `runMethQC()`):
  - `QC_matrix` — per-sample detection stats, intensity, predictedSex, `Final.QC`. `Final.QC` is PASS when at least 95% of probes are detected at p < `pcutoff` (default 0.05) and, when the ewastools control metrics are available, `CtrlMetrics.QC` is PASS. `CtrlMetrics.QC` fails only on Bisulfite Conversion I Green or Red below 1; the other control metrics are reported, not used.
  - `recall_rate` — per-probe % detected across all / PASS / FAIL samples
  - `cutoffs` — QC threshold criteria with Pass/Fail expressions (probe detection required; intensity and mean detection p-value reported only; control metrics when available)
    - **Core metrics (3 rows):** log2MedianIntensity (reported only), aveDetectionPval (reported only), `pctDetectedCpG_dP<pcutoff>` (>= 95; required)
    - **SNP metrics (1 row):** snps_outliers_aveLogOdds (>-4)
    - **Control metrics (18 rows, from ewastools):** Restoration, Staining, Extension, Hybridization, Target_Removal, Bisulfite_Conversion, Specificity, Non-polymorphic
    - **Columns:** criteria, cutoff, Pass, Fail, Final.QC, CtrlMetrics.QC
    - **Conditional formatting:** Use `SaveTableStyle()` (from `openxlsx`) with `condFmt` parameter to highlight Pass/Fail expressions in Excel exports
  - `ctrl_metrics` — control probe metrics (from ewastools)
  - `contamination` — SNP agreement / sample-swap check (from ewastools)
  - `predUniqDonor_ID` — predicted unique donors per sample group (from ewastools)
- **EPICv2 aggregation required**: Replicate probes (e.g. `cg..._TC11`, `cg..._TC12`) must be collapsed to base probe IDs before conversion — `aggregate_probes()` is a required step for EPICv2 (`as.ImprintomeSet()` will error if skipped)
- **Merge operations**: Synchronized metadata/beta alignment (`merge()`)
- **Export workflow**: Write QC tables, beta values, metadata to disk (`export()`)

## MethQcSet: Platform-Specific Preprocessing

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

# Export QC results (files listed under Export QC Results)
exported_files <- export(qcset_epic, outdir = "qc_results", prefix = "epic",
                         format = c("xlsx", "rds"))
# qc_results/epic_qc_table_main.xlsx, qc_results/QC_tables/epic_qc_table_extra.xlsx,
# qc_results/data/epic_qcset.rds, qc_results/epic_summary.txt
```

Merge multiple QC-clean single-platform datasets:

```r
# Two single-platform MethQcSet objects (from separate runMethQC() calls)
qcset1 <- runMethQC(meta1, platform = "EPIC")
qcset2 <- runMethQC(meta2, platform = "EPIC")

# Synchronized merge
merged <- merge(qcset1, qcset2, how = "inner")

# Find common elements
common_samples <- find_intersection(qcset1, qcset2, by = "samples")
common_probes <- find_intersection(qcset1, qcset2, by = "probes")
```

## Export QC Results

The `export()` method writes QC preprocessing results to **two organized Excel workbooks** for better separation of primary and supplementary data:

```r
export(
  qcset,
  outdir = "qc_output",
  format = c("xlsx", "rds", "txt")  # xlsx (default) | rds | txt | any combination
)
```

**Output files:**

**{prefix}_qc_table_main.xlsx** (primary QC results for review):
- `metadata` — Sample information with Platform and Final.QC columns
- `QC_matrix` — Per-sample QC metrics (intensity, detection p-values, probe coverage, predicted sex)
- `Ctrl_matrix` — Control probe metrics (from ewastools)
- `statistics` — Per-Sample_Group summary table (Total, PASS, FAIL, pass/fail ratios)

**QC_tables/{prefix}_qc_table_extra.xlsx** (supplementary technical results):
- `QC_metrics` — QC decision thresholds (criteria, cutoff values, Final.QC status)
- `contamination` — SNP agreement matrix for sample swap detection (if available)
- `recall_rate` — Per-probe detection statistics across cohort (if available)
- `predUniqDonor_ID` — Predicted unique donors per sample group (if available)

**Additional output:**
- `data/{prefix}_qcset.rds` — Full MethQcSet object (if format includes "rds")
- `data/{prefix}_beta.txt` — Beta values, tab-delimited (if format includes "txt")
- `data/{prefix}_meta.txt` — Metadata, tab-delimited (if format includes "txt")
- `QC_tables/{prefix}_qc_matrix.txt` — QC metrics table, tab-delimited (primary txt file)
- `QC_tables/{prefix}_qc_statistics.txt` — Statistics summary, tab-delimited (primary txt file)
- `QC_tables/{prefix}_qc_*.txt` — Individual QC tables, tab-delimited (supplementary files)
- `{prefix}_summary.txt` — Summary report with optional Notes section

**Statistics sheet:** PASS/FAIL counts and ratios per `Sample_Group`, computed from `QC_matrix` on export and also stored in `statistics(qcset)`. Beta values are not written to xlsx (too large); use the `.rds` or `txt` output.

The "Notes" section of `{prefix}_summary.txt` lists the optional sheets that were not written because their data were missing (for example `Ctrl_matrix`, `contamination` and `predUniqDonor_ID` when ewastools did not run), or states that all documented sheets were created.

ImprintomeSet results are exported with `export(x, ...)` (see [Step 4](analysis.md#step-4-summarize-visualize-export)).

# Imprinting analysis (ImprintomeSet)

[← Back to README](../README.md)

## Score geometry

Subtracting 0.5 moves the hemimethylated state of an imprinting control region to the origin (0, 0) of a plane whose axes are the paternal and maternal median deviations. Each sample is then a deviation vector: IDS is its length, the Euclidean distance from balanced imprinting, and Angle its direction. Without the shift, distance and direction would be measured from a fully unmethylated locus. IDI applies the same shift probe by probe and rescales it to [−1, 1].

The interpretation of the scores and the default cutoffs are described in the [README](../README.md#core-formulas).

## Step 2: Create Analysis Container (ImprintomeSet)

Once QC-approved, convert to analysis-ready object:

```r
probesets <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))

# Option A: convert from a MethQcSet (recommended — carries platform/assay automatically)

# EPICv2 only: aggregate replicate probes first (required)
# as.ImprintomeSet() will error if this step is skipped for EPICv2.
if (qcset@platform == "EPICv2") {
  qcset <- aggregate_probes(qcset)  # ~937k → ~865k unique base probes (median of each replicate group)
  qc_tables(qcset)$Aggregation_report # replicate groups collapsed, unchanged and malformed IDs, all-missing values
}

x <- as.ImprintomeSet(
  qcset,
  probeset = probesets[["selected"]],
  genome = "hg38"                      # default; "hg19" for GRCh37 coordinates
)

# Option B: build directly from beta + meta (QC already done externally)
# Note: Basename column is not needed since QC step is skipped
meta <- LoadMeta("meta.tsv")  # Only needs Sample_Name and Sample_Group
beta <- LoadBeta("cleaned_beta.tsv")   # probes × samples matrix, already QC-filtered

x <- ImprintomeSet(
  beta    = beta,
  meta    = meta,
  probeset = probesets[["selected"]],
  genome  = "hg38",
  assay   = "EPIC"                     # "450K" | "EPIC" (or "EPICv1") | "EPICv2"
)

# Either way, x is ready for analysis
# x now contains: beta, meta, probeset, genome, assay
```

## Step 3: Run Imprinting Analysis

```r
x <- runImprintome(
  x,
  probeset = "selected",
  ids_cutoff = 0.2
)

# Results stored in results(x)
names(results(x))
```

The core `selected` panel is scored on gametic ICRs only by default (`dmr_type = NULL`, recorded as `"gametic"` in the `dmr_type` column). Secondary DMRs are tissue-variable and unmethylated in sperm, so including them can mislabel samples; for example, sperm from GSE52576 scores as "Global-Hypo" with all probes but as androgenetic-like "Pat-Gain+Mat-Loss" with gametic ICRs. Use `dmr_type = "all"` for all probes (the earlier default) or `dmr_type = "secondary"` to report secondary DMRs separately; other panels are scored on all probes unless `dmr_type` is given. From the command line: `--dmr-type all` or `--dmr-type secondary`.

```r
x <- runImprintome(x, probeset = "selected")                       # gametic ICRs (default)
x <- runImprintome(x, probeset = "selected", dmr_type = "all")     # stored as AnalyzeImprintStatus.selected.all
x <- runImprintome(x, probeset = "selected", dmr_type = "secondary")
```

### Reference centring and Infinium design types

Normal tissue does not always sit at 0.5: Infinium type I/II probe differences and tissue-specific secondary DMRs can move healthy samples away from the balanced state. Control samples can replace the fixed 0.5 with a per-probe reference (the median beta of each probe across the controls). The reference is chosen in this order:

1. **External controls** (`reference_beta`): for cohorts with no or too few controls, such as tumour collections. Pass a control beta matrix or file, or a profile built once with `BuildReferenceProfile()` and saved with `saveRDS()`. The controls should match the cohort's tissue, array type and preprocessing; probes missing from the reference are dropped.
2. **In-cohort controls** (`reference_group` values of `Sample_Group`, or `reference_samples`): the best technical match, because the controls share the array and preprocessing with the cases. Each control is scored against the other controls (leave-one-out).
3. **Fixed 0.5**: used only when no controls are supplied, or when fewer than 3 are available (with a warning). At least 5 tissue-matched controls are recommended.

`reference = "controls"` makes a missing control reference an error, and `reference = "fixed"` always uses 0.5. `infinium_type = "I"` or `"II"` scores one probe design type; `"balanced"` computes each parental-class deviation within type I and type II probes separately and averages them, so type composition does not drive the score. Within-array normalization (for example BMIQ) before scoring is still recommended.

```r
# In-cohort controls, Infinium-balanced
x <- runImprintome(x, probeset = "selected", reference_group = "control", infinium_type = "balanced")

# External controls, e.g. tissue-matched public normals
ref <- BuildReferenceProfile(normal_beta)          # per-probe medians, all panels
saveRDS(ref, "adrenal_reference.rds")
x <- runImprintome(x, probeset = "chr11p15", reference_beta = ref)

# Output columns: reference, n_reference_samples, infinium_type,
# paternal_deviation, maternal_deviation (IDS and Angle use these)
```

From the command line: `--reference-group control`, `--reference-file adrenal_reference.rds`, and `--infinium-type balanced`.

### Per-ICR scores and ICR-balanced IDS

The sample-level IDS pools all probes of a parental class, so probe-rich ICRs dominate it and single-locus or single-chromosome defects can be missed. Three complementary views are available:

- **Per-ICR deviations** (`AnalyzeICRStatus()`): for every sample and ICR with at least 3 probes, the median of (beta − reference) over the ICR's probes. Each ICR has one parental origin, so its deviation is a gain or loss on one axis.
  - **Altered call:** |deviation| ≥ 0.075 (`delta_cutoff`) and |z| ≥ 3 (`z_cutoff`) against the controls (`reference_group`/`control_group`).
  - **Thresholds:** the defaults were selected under a prespecified protocol (`benchmark/threshold_selection_protocol.md`) by leave-one-cohort-out cross-validation on six development cohorts and validated on three held-out cohorts. Versions before this used |deviation| ≥ 0.15.
  - **Without controls:** `z` is unavailable and only `delta_cutoff` applies. This setting was not validated; calls are exploratory, and a larger `delta_cutoff` (such as 0.15) is more conservative.
  - **Summary:** `SummarizeICRStatus()` counts altered ICRs per sample and flags multi-locus imprinting disturbance (`MLID`) when altered ICRs lie on at least two chromosomes. The polymorphically imprinted `VTRNA2-1:DMR` is not counted (`exclude_icrs`). With controls from another study, between-study offsets produce non-specific calls, so the flag needs controls from the same study and processing.
  - **ICRs scored:** all annotated ICRs, gametic and secondary; the `DMR_type` column records each ICR's type. This differs from the sample-level default for `selected` (gametic only). Pooling secondary DMRs into a parental class lets their tissue variability shift the class median. Per-ICR, each ICR is scored on its own, against the controls where a cohort has them, so a secondary DMR cannot distort the others. Several diagnostically relevant DMRs are secondary (for example `GNAS A/B:TSS-DMR`, `MEG3:TSS-DMR` and the `SNRPN` DMRs). To restrict to gametic ICRs, set `dmr_type = "gametic"` in `AnalyzeICRStatus()` or `SummarizeICRStatus()`. This is worth doing in cohorts without controls, where the fixed 0.5 reference cannot absorb tissue-specific methylation at secondary DMRs.
  - **Heatmap:** `PlotICRHeatmap()` draws samples × ICRs; non-gametic ICRs are marked with `*`. After `runImprintome(icr = TRUE)`, `plot(x, plot_type = "icr_heatmap")` and `runImprintomeVisualizations()` draw it from the stored `ICRStatus.<probeset>` table.
- **ICR-balanced IDS/Angle** (`balance = "icr"`): the median within each ICR, then the median across the class's ICRs, so that each ICR counts once.
- **Locus panels** (`chr11p15`, `chr20q13`): two-axis IDS/Angle for a single imprinted domain.

```r
icr <- AnalyzeICRStatus(x, probeset = "selected", reference_group = "control")
SummarizeICRStatus(icr)                       # altered ICRs and MLID flag per sample
PlotICRHeatmap(icr, outFile = "icr_heatmap.pdf")
icr_gametic <- AnalyzeICRStatus(x, probeset = "selected", reference_group = "control",
                                dmr_type = "gametic")   # score gametic ICRs only
SummarizeICRStatus(icr, dmr_type = "gametic") # or count gametic ICRs only from the full table
PlotICRHeatmap(icr_gametic, outFile = "icr_gametic_heatmap.pdf")

```

Within `runImprintome()`, `balance` and `icr` are independent. Every call computes one sample-level IDS/Angle table: probe-pooled by default, or ICR-balanced with `balance = "icr"`. `icr = TRUE` adds the per-ICR tables to it.

```r
# Sample-level only (probe-pooled IDS/Angle)
x <- runImprintome(x, probeset = "selected")
# results: AnalyzeImprintStatus.selected

# Sample-level (probe-pooled) + per-ICR calls and multi-locus summary
x <- runImprintome(x, probeset = "selected", icr = TRUE)
# results: AnalyzeImprintStatus.selected, ICRStatus.selected, ICRSummary.selected

# Sample-level (ICR-balanced) only
x <- runImprintome(x, probeset = "selected", balance = "icr")
# results: AnalyzeImprintStatus.selected.icr

# Sample-level (ICR-balanced) + per-ICR calls and multi-locus summary
x <- runImprintome(x, probeset = "selected", balance = "icr", icr = TRUE)
# results: AnalyzeImprintStatus.selected.icr, ICRStatus.selected, ICRSummary.selected

# Both sample-level scores: run twice; the tables have different names, so neither is overwritten
x <- runImprintome(x, probeset = "selected", icr = TRUE)
x <- runImprintome(x, probeset = "selected", balance = "icr")
# results: AnalyzeImprintStatus.selected, AnalyzeImprintStatus.selected.icr, ICRStatus.selected, ICRSummary.selected
```

Result names gain further suffixes for non-default settings, such as `.ref-controls` when scores are centred on controls.

From the command line: `--icr` writes the per-ICR table, its summary and the per-ICR heatmap (`icr_heatmap` plot type), and `--balance icr` the ICR-balanced IDS.

### Uncertainty and calibration

IDS and Angle are reported without confidence intervals or p-values by default, and there is no false-discovery-rate control. Optional resampling quantifies uncertainty:

- **Bootstrap intervals** (`n_boot`): each sample's paternal and maternal deviations are recomputed by a two-stage cluster bootstrap (ICRs resampled with replacement, then probes within each ICR; `resample = "probe"` resamples probes only). The output adds `IDS_lower`/`IDS_upper`, a circular `Angle_lower`/`Angle_upper` interval and `Mechanism_support`, the fraction of replicates in the reported sector. The reference is held fixed, and because IDS is a distance its interval never includes 0.
- **Origin permutation** (`n_perm`): the parental labels are reassigned among probes (or whole ICRs, `permute = "icr"`) and the origin contrast |paternal − maternal deviation| is recomputed; `origin_perm_p` tests whether the deviation depends on the annotated parental origin, so a shift shared by all probes is not significant. **Use it only with a control reference:** against the fixed 0.5, normal tissue already deviates slightly and unequally on the two axes, and with hundreds of probes that offset alone gives small p-values. Probe-level permutation is anti-conservative, and p-values are not adjusted for multiple testing.
- **Calibration** (`CalibrateIDS()`): derives a cohort-specific IDS cutoff from controls (an upper quantile, the maximum, or the Youden-optimal cutoff when cases are given) and adds a robust z-score and the control percentile of each sample.

```r
x <- runImprintome(x, probeset = "chr11p15", reference_group = "control",
                   n_boot = 2000, n_perm = 2000, seed = 1)
res <- results(x)[["AnalyzeImprintStatus.chr11p15.ref-controls"]]
res[, c("Sample_Name", "IDS", "IDS_lower", "IDS_upper", "Mechanism_support", "origin_perm_p")]

cal <- CalibrateIDS(res, controls = "control", method = "quantile", probs = 0.99)
attr(cal, "calibration")   # cutoff, number of controls, control median and maximum IDS
```

## Step 4: Summarize, Visualize, Export

```r
s <- summarize(x)        # imprintomeR::summarize(x) if dplyr is attached after imprintomeR
s$results                # one row per stored result table

p <- plot(x, plot_type = "polar", result_name = "AnalyzeImprintStatus.selected",
          colorColumn = "Sample_Group", outFile = "polar.pdf")

manifest <- export(x, outdir = "imprintome_export", prefix = "imprintome",
                   save_plots = TRUE, plot_device = "pdf")
```

`export()` writes every result table and, with `save_plots = TRUE`, every stored plot; it returns a manifest of the files written. Plot types and options are listed under [Visualization](plots.md#visualization).

## Inspecting the objects

```r
# MethQcSet slots: beta and detection_pval (probes x samples), meta, qc_tables,
# statistics (per-Sample_Group PASS/FAIL counts, filled on export), platform,
# aggregation_status ("none" or "epicv2_aggregated") and qc_params (QC settings)
names(qc_tables(qcset_epic))     # QC_matrix, recall_rate, cutoffs and, from ewastools,
                                 # ctrl_metrics, contamination, predUniqDonor_ID

# QC_matrix: intensity, detection, predicted sex and Final.QC per sample
qc_matrix <- qc_tables(qcset_epic)[["QC_matrix"]]
head(qc_matrix[, c("Sample_Name", "mMed.Intensity", "aveMed.Intensity",
                   "pctDetectedCpG_dP0.05", "predictedSex", "Final.QC")])

statistics(qcset_epic)           # GROUP, Total, PASS, FAIL, PASS.RATIO, FAIL.RATIO

# Per-probe recall (% of samples detecting each probe)
recall <- qc_tables(qcset_epic)[["recall_rate"]]
head(recall[order(recall$pct_detected_all), ])

# QC cutoffs (exported, filtered, as the QC_metrics sheet)
cutoffs_all <- qc_tables(qcset_epic)[["cutoffs"]]

# ImprintomeSet slots: beta (probes x samples), meta, probeset, genome, assay,
# results (named list of result tables) and plots (named list of stored plots)
names(results(x))
res <- results(x)[["AnalyzeImprintStatus.selected"]]   # one row per sample
head(res[, c("Sample_Name", "IDS", "Angle", "Mechanism")])

s <- summarize(x)
s$object; s$results; s$plots
```

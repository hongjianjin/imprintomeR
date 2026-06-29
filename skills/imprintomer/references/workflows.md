# imprintomeR Workflow Reference

## Raw IDAT QC To ImprintomeSet

Use this pattern when metadata includes raw IDAT basenames.

```r
library(imprintomeR)

qcset <- runMethQC(meta, platform = "EPIC")

beta_clean <- subset(qcset, qc_status = "pass")

x <- as.ImprintomeSet(
  beta_clean,
  probeset = "selected",
  genome = "hg19"
)

x <- runImprintome(x, probeset = "selected")
```

Prefer package helpers for subsetting QC-clean data rather than manually assigning into object slots.

## Direct Beta Matrix Workflow

Use this pattern when beta values and metadata are already prepared.

```r
x <- ImprintomeSet(
  beta = beta,
  meta = meta,
  probeset = probesets,
  genome = "hg19",
  assay = "EPIC"
)

x <- runImprintome(x, probeset = "selected")
```

Require sample alignment between `colnames(beta)` and `meta$Sample_Name`.

## Standard Visualization Workflow

Use `runImprintomeVisualizations()` for repeated plot generation.

```r
x <- runImprintomeVisualizations(
  x,
  plot_types = "default",
  probeset = "selected",
  store_plots = TRUE,
  save_plots = FALSE
)
```

Generate individual plot types with the same helper:

```r
x <- runImprintomeVisualizations(
  x,
  plot_types = "radar",
  probeset = "selected",
  store_plots = TRUE,
  save_plots = FALSE
)
```

For batch or CLI workflows, save plot files directly:

```r
runImprintomeVisualizations(
  x,
  plot_types = "default",
  probeset = "selected",
  outdir = "imprintome_output",
  prefix = "study1",
  store_plots = FALSE,
  save_plots = TRUE,
  plot_device = "pdf"
)
```

## Export Workflow

Use `export()` for tables, stored plots, and the RDS object.

```r
manifest <- export(
  x,
  outdir = "imprintome_output",
  prefix = "study1",
  save_plots = TRUE,
  plot_device = "pdf",
  overwrite = TRUE
)
```

When `result_names` is omitted or `NULL`, all available result tables should be exported.

## CLI Scripts

Installed scripts live under `inst/scripts/` in the package source and can be found after installation with:

```r
system.file("scripts", "run_meth_QC.R", package = "imprintomeR")
system.file("scripts", "run_imprintomeR.R", package = "imprintomeR")
```

Use `run_meth_QC.R` for raw IDAT QC and `run_imprintomeR.R` for post-QC imprintome analysis.

The imprintome CLI should:

- Reuse a cached `<prefix>_imprintomeSet.rds` only when it already contains the requested `AnalyzeImprintStatus.<probeset>` result.
- Rerun core analysis if the requested probeset result is missing.
- Save plots directly as PDF files instead of updating the cached RDS with large plot objects.

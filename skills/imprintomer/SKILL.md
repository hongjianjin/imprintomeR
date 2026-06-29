---
name: imprintomer
description: Use when working with the imprintomeR R package, including MethQcSet methylation-array QC, ImprintomeSet imprinting analysis, GEO/vignette workflows, CLI usage, visualization/export behavior, package documentation, and troubleshooting package workflows. Trigger when users ask an AI agent to create, review, update, or explain imprintomeR analyses, vignettes, scripts, or package code.
---

# imprintomeR

## Core Principles

Follow the package workflow and naming conventions already used in the repository.

Use `Sample_Name` as the standard sample identifier in new code, vignettes, result tables, and documentation. Accept `SAMPLE_NAME` only as backwards-compatible input.

Keep QC and imprinting analysis separate:

- Use `MethQcSet` for IDAT loading, platform-aware methylation-array QC, beta values, detection p-values, metadata, and QC tables.
- Use `ImprintomeSet` for analysis-ready beta values, metadata, probesets, imprinting results, visualizations, and export.

Do not make low median intensity fail `Final.QC`; report intensity as a QC metric, but do not require `log2MedianIntensity > 11`.

## Standard Workflow

For end-to-end analyses, use this sequence:

1. Prepare metadata with `Sample_Name`, `Sample_Group`, and `Basename` for raw IDAT workflows.
2. Run platform-aware QC with `runMethQC()`.
3. Use QC-clean beta values when available.
4. Create an `ImprintomeSet`.
5. Run imprinting analysis with `runImprintome()`.
6. Generate visualizations with `runImprintomeVisualizations()`.
7. Export result tables, plots, and the object with `export()`.

For detailed code patterns, read `references/workflows.md`.

## Visualization Rules

`runImprintomeVisualizations(plot_types = "default")` excludes `circular_heatmap`.

The default workflow plots are:

- `polar`
- `beeswarm_origin`
- `mirror_density`
- `heatmap_by_probe`
- `heatmap_by_gene`
- `radar`
- `beeswarm_chr`
- `rainfall`

Request individual plots explicitly:

```r
runImprintomeVisualizations(x, plot_types = "polar")
runImprintomeVisualizations(x, plot_types = "beeswarm_origin")
runImprintomeVisualizations(x, plot_types = "circular_heatmap")
```

When exporting radar plots to PDF, use a `12 x 12` inch default unless the user explicitly requests another size.

## Export Rules

When `result_names = NULL`, export all available result tables.

Use the package export naming scheme:

```text
<prefix>_imprintomeSet.rds
<prefix>_results_<result_name>.tsv
<prefix>_plot_<plot_name>.pdf
```

For CLI workflows, avoid storing large plot objects in cached RDS files. Save plot PDFs directly and keep cached `ImprintomeSet` objects lean.

## Vignette Style

Follow the phase-based style used by the GEO vignettes in `vignettes/`.

Use concise code chunks, explicit QC and imprintome phases, individual `plot_type` examples where helpful, and a final export section.

For Jupyter-friendly plots in notebooks or rendered examples, set `options(repr.plot.width = ..., repr.plot.height = ...)` before printing plots.

## Validation

After package code changes, run focused tests when possible:

```r
testthat::test_file("tests/test-imprintomeset.R")
```

For vignette-only edits, inspect changed chunks for runnable code, consistent `Sample_Name` usage, and accurate output filenames.

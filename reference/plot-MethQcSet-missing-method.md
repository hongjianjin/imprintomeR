# Plot QC Metrics from MethQcSet

Generate QC-stage visualizations from stored QC tables.

## Usage

``` r
# S4 method for class 'MethQcSet,missing'
plot(x, y, type = "qc_bar", icutoff = 11, pcutoff = 0.05, outFile = NULL, ...)
```

## Arguments

- x:

  A `MethQcSet` object.

- y:

  Ignored (for generic compatibility).

- type:

  Character scalar. One of `"qc_bar"` (default), `"intensity"`,
  `"detection_pval"`, `"beta_density"`, `"probe_coverage"`,
  `"predicted_sex"`, `"ctrl_metrics"`, `"ctrl_metrics_detail"`.

- icutoff:

  Numeric. log2 intensity cutoff reference line for `"intensity"` plot
  (default 11).

- pcutoff:

  Numeric. Detection p-value cutoff reference line for
  `"detection_pval"` plot (default 0.05).

- outFile:

  Optional file path to save the plot (format inferred from extension:
  pdf/png/svg).

- ...:

  Additional arguments forwarded to
  [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html).
  For `type = "beta_density"`, supported arguments include `sample_set`
  (`"all"`, `"pass"`, or `"fail"`), `group_col`, `max_points`, and
  `adjust`.

## Value

A ggplot object. Also written to `outFile` when provided.

## Details

**Plot types:**

- `qc_bar`:

  PASS / FAIL sample count bar chart from `QC_matrix$Final.QC`.

- `intensity`:

  Scatter of mMed.Intensity vs uMed.Intensity per sample, colored by
  `Final.QC`, with a horizontal reference line at `icutoff`.

- `detection_pval`:

  Per-sample average detection p-value dot plot, colored by `Final.QC`,
  with a horizontal reference line at `pcutoff`.

- `probe_coverage`:

  Per-sample percent of probes detected (dP \< 0.05), colored by
  `Final.QC`, with a reference line at 95%.

- `predicted_sex`:

  Bar chart of predicted sex counts from `QC_matrix$predictedSex`.

- `beta_density`:

  Processed beta-value density curves per sample, optionally restricted
  to all, PASS, or FAIL samples via `sample_set`. This plot is generated
  from the cached `MethQcSet` beta matrix and is complementary to raw
  [`minfi::qcReport()`](https://rdrr.io/pkg/minfi/man/qcReport.html)
  density output.

- `ctrl_metrics`:

  Per-sample dot chart of `CtrlMetrics.QC` from `ctrl_metrics`. Returns
  `NULL` silently if `ctrl_metrics` is absent.

- `ctrl_metrics_detail`:

  One jitter-dot plot per control-probe metric (Bisulfite Conversion,
  Specificity, Non-polymorphic). `outFile` is used as a path prefix;
  individual files are saved as
  `{prefix}_ctrl_matrix_detail_{Metric}.pdf`. Returns a named list of
  ggplot objects.

All types return `NULL` with a message if the required data are not yet
present.

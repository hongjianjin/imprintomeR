# Calibrate the IDS Cutoff on Control Samples

Derives a cohort-specific IDS cutoff from control samples of the same
tissue, platform and preprocessing, and expresses each sample's IDS
relative to the control distribution. The package default cutoff (0.2)
is exploratory; control IDS depends on tissue and sample type, so a
cutoff calibrated on matched controls is preferable when such controls
exist.

## Usage

``` r
CalibrateIDS(
  results,
  controls,
  method = c("quantile", "max", "youden"),
  probs = 0.99,
  cases = NULL
)
```

## Arguments

- results:

  A data frame returned by
  [`AnalyzeImprintStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeImprintStatus.md)
  (for example `results(x)[["AnalyzeImprintStatus.selected"]]`), with
  columns `Sample_Name` and `IDS`.

- controls:

  Control samples: `Sample_Group` value(s), sample names, or a logical
  vector along the rows of `results`.

- method:

  How the cutoff is derived:

  - `"quantile"` (default): the `probs` quantile of control IDS;

  - `"max"`: the maximum control IDS;

  - `"youden"`: the cutoff maximizing sensitivity + specificity between
    `cases` and controls (requires `cases`). Candidate cutoffs lie
    midway between adjacent observed IDS values; among tied optima the
    middle one is taken.

- probs:

  Quantile used by `method = "quantile"` (default 0.99).

- cases:

  Optional case samples, given like `controls`. Required for `"youden"`;
  when given, the area under the ROC curve (cases versus controls) is
  reported.

## Value

`results` with added columns `IDS_z` (robust z-score,
`(IDS - median) / MAD` of the controls, with the MAD floored at 0.01),
`IDS_control_percentile` (percentage of controls with a lower or equal
IDS) and `Status_calibrated` (`"Imprinting Alteration"` when
`IDS > cutoff`, otherwise `"Normal"`; for `"youden"`, `IDS >= cutoff`).
The attribute `calibration` is a one-row data frame with the method,
cutoff, number of controls, control median and maximum IDS, and the AUC
and Youden sensitivity/specificity when cases are given.

## Details

Control IDS should come from the same scoring run as the cases. With a
control reference (`reference_group` or `reference_samples` in
[`AnalyzeImprintStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeImprintStatus.md))
each control is scored leave-one-out, so its IDS is an honest estimate
of control variation; with the fixed 0.5 reference the control IDS
measures the controls' offset from 0.5.

## Examples

``` r
res <- data.frame(Sample_Name = paste0("S", 1:8),
                  Sample_Group = rep(c("control", "case"), each = 4),
                  IDS = c(0.03, 0.05, 0.04, 0.08, 0.30, 0.12, 0.45, 0.26))
cal <- CalibrateIDS(res, controls = "control", method = "max", cases = "case")
#> Warning: Calibration on 4 controls; at least 5 tissue-matched controls are recommended.
attr(cal, "calibration")
#>   method probs cutoff n_controls control_median control_max n_cases AUC
#> 1    max    NA   0.08          4          0.045        0.08       4   1
#>   sensitivity specificity
#> 1           1           1
```

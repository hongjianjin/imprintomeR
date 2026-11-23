# Prepare Cutoffs Table for Export (Internal)

Internal helper to remove specific columns from cutoffs table for
QC_metrics sheet.

## Usage

``` r
.prepare_cutoffs_for_export(cutoffs)
```

## Arguments

- cutoffs:

  data.frame with columns: criteria, cutoff, Pass, Fail, Final.QC,
  CtrlMetrics.QC.

## Value

Filtered data.frame with columns: criteria, cutoff, Final.QC only.
Returns NULL if input is NULL or not a data.frame.

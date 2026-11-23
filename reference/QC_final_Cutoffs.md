# QC Final Cutoffs for Conditional Formatting

Data frame defining pass/fail expressions for QC_matrix sheet. Used by
SaveTableStyle() to apply conditional formatting (colors) to Excel
output.

## Usage

``` r
QC_final_Cutoffs
```

## Format

A data frame with columns:

- `Control`: Column name in QC_matrix (e.g., "pctDetectedCpG_dP0.05")

- `Threshold`: Threshold value (used for warning highlighting on
  "Final.QC" fields)

- `Pass`: Expression for pass condition (e.g., "\>95")

- `Fail`: Expression for fail condition (e.g., "\<=95")

## Details

Pass expressions are formatted as R expressions (e.g., "\>95", "\>=11").
Fail expressions should be the logical inverse of Pass.

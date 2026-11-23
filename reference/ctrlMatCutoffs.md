# Control Metrics Cutoffs for Conditional Formatting

Data frame defining pass/fail expressions for ctrl_metrics sheet. Used
by SaveTableStyle() to apply conditional formatting (colors) to Excel
output.

## Usage

``` r
ctrlMatCutoffs
```

## Format

A data frame with columns:

- `Control`: Column name in ctrl_metrics (e.g.,
  "Bisulfite_Conversion_I_Green")

- `Threshold`: Threshold value (used for warning highlighting)

- `Pass`: Expression for pass condition (e.g., "\>1")

- `Fail`: Expression for fail condition (e.g., "\<=1")

## Details

Rows cover Bisulfite Conversion, Specificity, Non-polymorphic controls,
and overall QC status. Most control metrics use \>1 threshold for PASS,
\<=1 for FAIL.

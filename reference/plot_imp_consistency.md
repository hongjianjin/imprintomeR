# Plot Imprinting Deviation against Tumor Purity

Scatter plot of observed deviation against tumour purity, with the line
expected for a clonal loss of imprinting (slope 0.5).

## Usage

``` r
plot_imp_consistency(df)
```

## Arguments

- df:

  Data frame from `validate_imprinting_fit()` with columns `Purity`,
  `Observed_Dev`, `Status` and `Fit_Score`.

## Value

A ggplot object.

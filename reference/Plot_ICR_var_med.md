# Plot ICR-Level Variance and Median Drift

Plot ICR-Level Variance and Median Drift

## Usage

``` r
Plot_ICR_var_med(
  plot_data,
  outFile = NULL,
  project = "cohort",
  style = "beeswarm",
  min_cpg = 3
)
```

## Arguments

- plot_data:

  Data frame returned by ICR variance calculations.

- outFile:

  Optional output file path.

- project:

  Project/cohort label used in the title.

- style:

  Plot style: `"beeswarm"` or `"boxplot"`.

- min_cpg:

  Minimum CpG count required per ICR.

## Value

A ggplot object.

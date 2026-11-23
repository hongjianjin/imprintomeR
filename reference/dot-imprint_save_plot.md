# Save Plot Conditionally and Return Plot Object

Internal helper to standardize optional file saving while always
returning the plot object.

## Usage

``` r
.imprint_save_plot(
  plot_obj,
  outFile = NULL,
  width = NULL,
  height = NULL,
  units = "in",
  limitsize = TRUE
)
```

## Arguments

- plot_obj:

  A ggplot object.

- outFile:

  Optional output file path. If `NULL`, nothing is written.

- width, height:

  Optional numeric width/height in inches.

- units:

  Units passed to `ggsave`.

- limitsize:

  Passed to `ggsave`.

## Value

The input `plot_obj`.

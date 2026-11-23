# Export ImprintomeSet Outputs to Disk

Writes the `ImprintomeSet` object, selected result tables, and
optionally stored plots to `outdir`. Data-frame/matrix results are
exported as TSV; other result objects are saved as RDS. Plot export
supports ggplot-compatible, ComplexHeatmap, recorded, and file-backed
plot objects as plot files when possible; other plot object types are
serialized as RDS.

## Usage

``` r
# S4 method for class 'ImprintomeSet'
export(
  x,
  outdir,
  result_names = NULL,
  save_plots = FALSE,
  plot_names = NULL,
  plot_device = "pdf",
  width = NULL,
  height = NULL,
  overwrite = TRUE,
  prefix = "imprintome",
  ...
)
```

## Arguments

- x:

  An `ImprintomeSet` object.

- outdir:

  Output directory.

- result_names:

  Character vector of result names to export. `NULL` means all.

- save_plots:

  Logical; whether to export plot objects in `plots(x)`.

- plot_names:

  Character vector of plot names to export when `save_plots=TRUE`.
  `NULL` means all stored plots.

- plot_device:

  Graphics device for ggplot export (`"pdf"` or `"png"`).

- width:

  Plot width in inches. `NULL` uses the figure size recorded by the plot
  (radar plots from `PlotRadar()` record a square size that leaves room
  for their labels, about 17 in for the `selected` panel), otherwise
  plot-specific defaults (`12` for radar plots, otherwise `8`).

- height:

  Plot height in inches. `NULL` uses the recorded figure size as for
  `width`, otherwise plot-specific defaults (`12` for radar plots,
  otherwise `6`).

- overwrite:

  Logical; overwrite existing files.

- prefix:

  Filename prefix for exported files, including result tables, the saved
  `ImprintomeSet` object, and plot files.

- ...:

  Reserved for future extensions.

## Value

A data.frame manifest with one row per exported object.

## Examples

``` r
if (FALSE) { # \dontrun{
manifest <- export(x, outdir = "imprintome_export", prefix = "imprintome", save_plots = TRUE)
head(manifest)
} # }
```

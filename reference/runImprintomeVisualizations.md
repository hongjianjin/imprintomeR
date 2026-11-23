# Run Standard ImprintomeSet Visualizations

Generate a standard set of `ImprintomeSet` plots using the object-first
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) dispatcher.
Successful plots can be stored in `plots(x)` and/or written to disk.
Direct-draw plots, such as circular heatmaps, are captured as
file-backed plot objects when possible.

## Usage

``` r
runImprintomeVisualizations(
  x,
  plot_types = "default",
  probeset = "selected",
  result_name = NULL,
  sample_id = NULL,
  prefix = "imprintome",
  outdir = NULL,
  save_plots = FALSE,
  store_plots = TRUE,
  overwrite = TRUE,
  SAMPLEID = "Sample_Name",
  annoColumn = "Sample_Group",
  sectionColumn = "Sample_Group",
  colorColumn = "Sample_Group",
  rainfall_probeset = "selected",
  chr = NULL,
  plot_device = "pdf",
  verbose = TRUE,
  ...
)
```

## Arguments

- x:

  An `ImprintomeSet` object.

- plot_types:

  Character vector of plot types. Use `"default"` for the standard
  workflow set, or `"all"` for all supported non-auto plot types.
  `"icr_heatmap"` draws
  [`PlotICRHeatmap()`](https://hongjianjin.github.io/imprintomeR/reference/PlotICRHeatmap.md)
  from the per-ICR table stored by `runImprintome(icr = TRUE)`;
  `"default"` and `"all"` include it when that table is present.

- probeset:

  Probeset name passed to plot backends.

- result_name:

  Optional result table name for result-driven plots.

- sample_id:

  Optional sample ID for sample-level plot types.

- prefix:

  Filename prefix used when `save_plots = TRUE`.

- outdir:

  Output directory used when `save_plots = TRUE`.

- save_plots:

  Logical; write plot files while generating plots.

- store_plots:

  Logical; store successful plot objects in `plots(x)`.

- overwrite:

  Logical; overwrite existing plot files.

- SAMPLEID:

  Metadata column used for sample labels.

- annoColumn:

  Metadata column used for heatmap annotation.

- sectionColumn:

  Metadata column used for circular heatmap sections.

- colorColumn:

  Result column used for polar plot colors.

- rainfall_probeset:

  Probeset used for rainfall plots.

- chr:

  Chromosome focus for `beeswarm_chr`; `NULL` uses all chromosomes.

- plot_device:

  File extension for saved plots. Currently only `"pdf"` is supported
  because several plotting backends write PDF devices directly.

- verbose:

  Logical; print progress messages.

- ...:

  Additional arguments passed to
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html).

## Value

The updated `ImprintomeSet`. A data.frame describing attempted plots is
attached as `attr(x, "visualization_manifest")`.

## Examples

``` r
if (FALSE) { # \dontrun{
x <- runImprintomeVisualizations(x, prefix = "GSE240091")
names(plots(x))
} # }
```

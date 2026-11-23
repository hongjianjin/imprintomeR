# Plot ImprintomeSet Results

S4 plotting method for `ImprintomeSet` objects. The method prioritizes
precomputed plots stored in `plots(x)` and otherwise generates a default
polar plot from result tables containing `IDS` and `Angle`. Default
generation uses
[`PlotPolar()`](https://hongjianjin.github.io/imprintomeR/reference/PlotPolar.md)
to preserve existing plot semantics.

## Usage

``` r
# S4 method for class 'ImprintomeSet,missing'
plot(x, y, ...)
```

## Arguments

- x:

  An `ImprintomeSet` object.

- y:

  Unused. Kept for
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html)
  compatibility.

- ...:

  Optional named arguments:

  - `plot_type`: one of `"auto"`, `"polar"`, `"mirror_density"`,
    `"beeswarm"`, `"beeswarm_origin"`, `"beeswarm_chr"`, `"violin"`,
    `"heatmap_by_probe"`, `"heatmap_by_gene"`, `"circular_heatmap",`
    `"cor_heatmap"`, `"rainfall"`, `"radar"`, `"icr_heatmap"`.

  - `plot_name`: specific stored plot name in `plots(x)`.

  - `result_name`: specific results table name in `results(x)`.
    `plot_type = "icr_heatmap"` draws
    [`PlotICRHeatmap()`](https://hongjianjin.github.io/imprintomeR/reference/PlotICRHeatmap.md)
    from the per-ICR table `ICRStatus.<probeset>` stored by
    `runImprintome(icr = TRUE)` (or from `result_name` when it names an
    [`AnalyzeICRStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeICRStatus.md)
    table); `limit` sets the colour limit (default 0.4).

  - `colorColumn`: grouping column for
    [`PlotPolar()`](https://hongjianjin.github.io/imprintomeR/reference/PlotPolar.md)
    (default `"Sample_Group"`; if missing from result data,
    automatically created with all samples grouped as `"All"`).

  - `title`: plot title (default `"ImprintomeR:Polar"`).

  - `palette`: palette passed to
    [`PlotPolar()`](https://hongjianjin.github.io/imprintomeR/reference/PlotPolar.md)
    (default `"default"`).

  - `alpha`: point alpha passed to
    [`PlotPolar()`](https://hongjianjin.github.io/imprintomeR/reference/PlotPolar.md)
    (default `0.5`).

  - `legend.position`, `legend.nrow`, `legend.ncol`, `legend.page`,
    `legend.page.threshold`, `legend.text.size`: optional polar legend
    controls passed to
    [`PlotPolar()`](https://hongjianjin.github.io/imprintomeR/reference/PlotPolar.md);
    crowded PDF legends can be written to a separate legend-only page
    with `legend.page = TRUE` or `legend.page = "auto"`.

  - `SAMPLEID`: metadata column used for sample labels in selected plot
    types (default `"Sample_Name"`).

  - `max_samples`: maximum number of samples shown by
    `plot_type = "beeswarm_origin"` or `plot_type = "mirror_density"`
    (default `100`; use `Inf` to plot all).

  - `probeset`: probeset name used by `"mirror_density"`, `"beeswarm"`,
    `"violin"`, `"heatmap_by_probe"`, `"heatmap_by_gene"`,
    `"circular_heatmap",` `"cor_heatmap"`, `"rainfall"`, and `"radar"`
    (default `"selected"`).

  - `sample_id`: explicit sample ID used by rainfall/radar plot types.
    The radar plot draws one spoke per curated ICR, in genomic order
    clockwise from the top; probes outside curated ICRs are not drawn
    (see
    [`AggregateByLocus()`](https://hongjianjin.github.io/imprintomeR/reference/AggregateByLocus.md)
    with `by = "icr", icr_only = TRUE`).

  - `chr`: chromosome label used by `plot_type = "beeswarm_chr"` (e.g.
    `"chr11"` or `"11"`; default uses all chromosomes).

  - `prefix`: output prefix used by `plot_type = "cor_heatmap"`.

  - `sectionColumn`: metadata grouping column used by
    `plot_type = "circular_heatmap"` (default `"Sample_Group"`; if
    column doesn't exist in metadata: uses `Sample_Name` if available,
    otherwise creates it with all samples grouped as `"all"`).

  - `Samples`: character vector of sample names to include (applied with
    `plot_type = "circular_heatmap"`, default: all samples).

  - `format`, `res`: output format (`"pdf"` or `"png"`; default inferred
    from `outFile`) and raster resolution in dpi (default 300) for
    `plot_type = "circular_heatmap"`.

  - `outFile`: optional file path for saving output.

  - `width`: optional width in inches when saving stored plots.

  - `height`: optional height in inches when saving stored plots.

## Value

Plot object returned by the selected backend function. For example,
`ggplot` objects for polar/beeswarm/violin/radar paths, or
backend-specific objects for heatmap/correlation paths.

## Examples

``` r
if (FALSE) { # \dontrun{
p <- plot(x)
p <- plot(x, plot_name = "polar.default")
p <- plot(x, result_name = "AnalyzeImprintStatus.selected", outFile = "polar.pdf")
p <- plot(x, plot_type = "beeswarm", probeset = "selected", SAMPLEID = "Sample_Name")
p <- plot(x, plot_type = "beeswarm_origin", probeset = "selected", SAMPLEID = "Sample_Name")
p <- plot(x, plot_type = "beeswarm_chr", probeset = "selected",
          sample_id = colnames(beta(x))[1], chr = "chr11")
p <- plot(x, plot_type = "heatmap_by_gene", probeset = "selected", outFile = "heatmap_gene.pdf")
p <- plot(x, plot_type = "mirror_density", probeset = "selected")
p <- plot(x, plot_type = "circular_heatmap", probeset = "selected", sectionColumn = "Sample_Name")
p <- plot(x, plot_type = "rainfall", sample_id = colnames(beta(x))[1])
} # }
```

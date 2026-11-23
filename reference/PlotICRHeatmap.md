# Heatmap of Per-ICR Deviations

Tiles of the per-ICR deviation from
[`AnalyzeICRStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeICRStatus.md),
samples in rows (grouped by `Sample_Group`) and ICRs in columns
(maternal then paternal, by chromosome position). Altered ICRs are
marked with a dot. A colour bar above the samples shows each ICR's
annotated parental origin (legend "Annotated parental origin").

## Usage

``` r
PlotICRHeatmap(
  icr_table,
  title = "Per-ICR deviation",
  limit = 0.4,
  outFile = NULL,
  width = NULL,
  height = NULL,
  show_sample_names = "auto",
  dpi = 200
)
```

## Arguments

- icr_table:

  Output of
  [`AnalyzeICRStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeICRStatus.md).

- title:

  Plot title.

- limit:

  Colour-scale limit for the deviation (default 0.4).

- outFile:

  Optional output path; the format follows the extension (`.pdf`,
  `.png`, `.jpg`, ...).

- width, height:

  Size in inches. By default (`NULL`) the size follows the data: about
  0.3 in per ICR and 0.12 in per sample plus margins (at least 6 x 5
  in), so large cohorts stay readable; heights beyond 50 in are allowed.

- show_sample_names:

  Show sample names on the y axis: `"auto"` (default; hidden above 300
  samples, where the group strips still label the groups), `TRUE` or
  `FALSE`.

- dpi:

  Resolution for raster formats (default 200).

## Value

A ggplot object; its size in inches is stored in the attribute
`imprintomeR_figure_size` (width, height) and used by
[`export()`](https://hongjianjin.github.io/imprintomeR/reference/export.md).

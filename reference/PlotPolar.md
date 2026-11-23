# Plot Imprintome Polar Coordinates

Plot Imprintome Polar Coordinates

## Usage

``` r
PlotPolar(
  data,
  outFile = NULL,
  colorColumn = "Sample_Group",
  title = "ImprintomeR:Polar",
  subtitle = NULL,
  palette = "default",
  alpha = 0.8,
  legend.position = "auto",
  legend.nrow = NULL,
  legend.ncol = NULL,
  legend.page = "auto",
  legend.page.threshold = 16,
  legend.text.size = 8,
  control_groups = "auto",
  label_width = 30
)
```

## Arguments

- data:

  Data frame containing `Angle` and `IDS` plus grouping columns.

- outFile:

  Optional output file path.

- colorColumn:

  Column name used for point fill grouping.

- title:

  Plot title.

- subtitle:

  Optional plot subtitle.

- palette:

  Palette name passed to
  [`GetColors()`](https://hongjianjin.github.io/imprintomeR/reference/GetColors.md).

- alpha:

  Point alpha.

- legend.position:

  Legend position. Use `"auto"` to place small legends at the bottom and
  large legends on a separate PDF page when exporting.

- legend.nrow:

  Number of legend rows for bottom legends. `NULL` uses an automatic
  value based on the number of groups.

- legend.ncol:

  Number of legend columns for separate legend pages. `NULL` uses an
  automatic value based on the number of groups.

- legend.page:

  Logical or `"auto"`; when saving a PDF, write crowded legends to a
  second legend-only page.

- legend.page.threshold:

  Number of groups above which `"auto"` uses a separate legend page for
  PDF export.

- legend.text.size:

  Legend text size.

- control_groups:

  Groups drawn in a fixed grey and on top of the other points. `"auto"`
  (default) uses groups whose name contains "control" or "normal"
  (case-insensitive); `NULL` for none.

- label_width:

  Legend labels longer than this many characters are wrapped.

## Value

A ggplot object.

## Details

Colours are assigned to the sorted group names, so a group keeps its
colour across plots of the same cohort. Larger groups are drawn first so
that small groups stay visible. The radial axis extends beyond 0.8 when
a sample's IDS is larger.

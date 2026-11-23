# Beeswarm Plot of Methylation by Sample

Beeswarm Plot of Methylation by Sample

## Usage

``` r
BetaBeePlot(
  beta,
  meta = NULL,
  SAMPLEID = "Sample_Name",
  outFile = NULL,
  alpha = 1,
  orderByGroup = FALSE,
  ylab = expression("Methylation (" * beta * ")"),
  xlab = "ID",
  legend = TRUE,
  title = "ImprintomeR: beeswarm",
  subtitle = NULL,
  width = NULL,
  height = NULL
)
```

## Arguments

- beta:

  Numeric beta matrix with probes as rows and samples as columns.

- meta:

  Sample metadata containing `Sample_Name` and grouping columns.

- SAMPLEID:

  Metadata column used as x-axis sample label.

- outFile:

  Optional output file path.

- alpha:

  Point alpha.

- orderByGroup:

  Logical; whether to order samples by group.

- ylab:

  Y-axis label.

- xlab:

  X-axis label.

- legend:

  Logical; include legend page in saved output.

- title, subtitle:

  Plot title and optional subtitle.

- width, height:

  Optional image dimensions in inches for saving; `NULL` sizes the image
  from the number of samples.

## Value

A patchwork/ggplot object.

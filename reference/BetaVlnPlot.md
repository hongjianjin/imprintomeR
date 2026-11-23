# Violin Plot of Methylation Distributions by Sample

Violin Plot of Methylation Distributions by Sample

## Usage

``` r
BetaVlnPlot(
  beta,
  meta = NULL,
  SAMPLEID = "Sample_Name",
  outFile = NULL,
  alpha = 1
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

  Violin alpha.

## Value

A ggplot object.

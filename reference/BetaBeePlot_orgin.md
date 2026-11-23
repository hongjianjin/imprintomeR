# Beeswarm Plot Split by Probe Category/Origin

Beeswarm Plot Split by Probe Category/Origin

## Usage

``` r
BetaBeePlot_orgin(
  beta,
  meta,
  SAMPLEID = "Sample_Name",
  outFile = NULL,
  alpha = 0.5,
  probesets = NULL,
  useNA = FALSE,
  width = NULL,
  height = NULL,
  group = "ORIGIN",
  genome = "hg38"
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

- probesets:

  Optional probeset name; `NULL` uses the array annotation.

- useNA:

  Logical; keep NA category values.

- width, height:

  Optional image dimensions for saving.

- group:

  Annotation column used to define categories.

- genome:

  Genome build of the probeset annotation, "hg38" (default) or "hg19".

## Value

A ggplot object.

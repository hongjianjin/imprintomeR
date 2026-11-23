# Beeswarm Plot for a Single Chromosome by Origin

Beeswarm Plot for a Single Chromosome by Origin

## Usage

``` r
BetaBeePlot_single_chr(
  beta,
  meta,
  SAMPLEID = "Sample_Name",
  outFile = NULL,
  alpha = 0.5,
  chr = "chr11",
  probeset = "chr11p15",
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

- chr:

  Chromosome label (e.g., `chr11`).

- probeset:

  Probeset name used for annotation lookup.

- genome:

  Genome build of the probeset annotation, "hg38" (default) or "hg19".

## Value

A ggplot object.

# Rainfall Plot of Probe-Level Imprinting Deviation

Plots the probe-level imprinting deviation index, IDI = (beta - 0.5) x
2, of one sample along the genome, faceted by chromosome and coloured by
the annotated parental origin.

## Usage

``` r
PlotRainfall(
  beta,
  sampleID,
  title = "Imprinting Rainfall Plot",
  probeset = c("selected", "NanoImprint", "Joshi", "Court", "Rosenski", "Jima",
    "chr11p15", "chr20q13"),
  outFile = NULL,
  genome = "hg38"
)
```

## Arguments

- beta:

  Probe-by-sample beta matrix or data frame with probe IDs as row names.

- sampleID:

  Name of the sample column to plot.

- title:

  Plot title.

- probeset:

  Probeset panel (default `"selected"`).

- outFile:

  Optional output file path (12 x 6 inches).

- genome:

  Genome build of the probeset annotation, "hg38" (default) or "hg19".

## Value

A ggplot object.

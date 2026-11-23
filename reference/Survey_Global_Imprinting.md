# Per-Chromosome Imprinting Survey of One Sample

Computes IDS, Angle and Mechanism separately for each chromosome of a
probeset panel, from the paternal and maternal median beta of the
chromosome's probes (fixed 0.5 reference).

## Usage

``` r
Survey_Global_Imprinting(
  beta,
  sampleID,
  probeset = c("selected", "NanoImprint", "Joshi", "Court", "Rosenski", "Jima",
    "chr11p15", "chr20q13"),
  min_probes = 10,
  ids_cutoff = 0.2,
  genome = "hg38"
)
```

## Arguments

- beta:

  Probe-by-sample beta matrix or data frame.

- sampleID:

  Name of the sample column to survey.

- probeset:

  Probeset panel (default `"selected"`).

- min_probes:

  Minimum number of probes of a parental class on a chromosome; with
  fewer, that class's median is set to 0.5 (default 10). Chromosomes
  with fewer in both classes are dropped.

- ids_cutoff:

  IDS cutoff for the `Status` column (default 0.2).

- genome:

  Genome build of the probeset annotation, `"hg19"` or `"hg38"`
  (default).

## Value

Data frame with one row per chromosome: probe counts, parental medians,
consistency, deviations, `IDS`, `Angle`, `Status`, `Confidence`
(exploratory IDS bands) and `Mechanism` (ROI below `ids_cutoff`).

## See also

[`Survey_Global_Imprinting_Batch()`](https://hongjianjin.github.io/imprintomeR/reference/Survey_Global_Imprinting_Batch.md)
for all samples.

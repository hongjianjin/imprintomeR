# Per-Chromosome Imprinting Survey of a Cohort

Applies the per-chromosome survey of
[`Survey_Global_Imprinting()`](https://hongjianjin.github.io/imprintomeR/reference/Survey_Global_Imprinting.md)
to every sample.

## Usage

``` r
Survey_Global_Imprinting_Batch(
  betaFile,
  metaFile = NULL,
  subset = "all",
  probeset = c("selected", "NanoImprint", "Joshi", "Court", "Rosenski", "Jima",
    "chr11p15", "chr20q13"),
  min_probes = 10,
  ids_cutoff = 0.2,
  genome = "hg38"
)
```

## Arguments

- betaFile:

  Beta matrix, data frame or file path (probes by samples).

- metaFile:

  Metadata data frame or file path with `Sample_Name`.

- subset:

  `"all"` (default) or one chromosome (for example `"chr11"`) to survey.

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

Data frame with one row per sample and chromosome: `Sample_Name`,
`Sample_Group` and `ID2` when available, `Chromosome`, `n_mat`, `n_pat`,
`IDS`, `Status`, `Mechanism` and `Angle`.

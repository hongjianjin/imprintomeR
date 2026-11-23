# Subset a Beta Matrix to a Probeset

Keeps the probes of a beta matrix that belong to a bundled probeset
panel, or to the probes of the `selected` panel on one chromosome.

## Usage

``` r
SubsetBeta_By_Probeset(
  beta,
  probeset = probeset_options,
  prefix = NULL,
  genome = "hg38"
)
```

## Arguments

- beta:

  Probe-by-sample beta matrix or data frame with probe IDs as row names.

- probeset:

  Name of a bundled panel (for example `"selected"` or `"chr11p15"`), a
  chromosome such as `"chr11"` (probes of the `selected` panel on it),
  or `NULL` to return `beta` unchanged.

- prefix:

  Optional file prefix; if given, the subset is written to
  `<prefix>_subset_by_<probeset>_beta.txt` unless that file already
  exists.

- genome:

  Genome build of the probeset annotation, `"hg19"` or `"hg38"`
  (default).

## Value

A list with `beta`, the subset beta values, and `probesets`, the panel
annotation of the matched probes (`NULL` when `probeset` is `NULL`).

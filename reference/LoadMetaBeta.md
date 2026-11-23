# Load Matched Metadata and Beta Matrix

Loads metadata and beta tables, keeps only intersecting samples, and
optionally subsets probes by named probeset.

## Usage

``` r
LoadMetaBeta(metaFile, betaFile = NULL, probeset = NULL)
```

## Arguments

- metaFile:

  Metadata data frame or file path.

- betaFile:

  Beta matrix/data frame or file path.

- probeset:

  Optional probeset name passed to `SubsetBeta_By_Probeset`.

## Value

A list with `meta`, `beta`, and `probesets`.

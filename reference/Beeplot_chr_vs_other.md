# Beeswarm Plot by Chromosome vs Others for Each Sample

Creates one panel per sample showing methylation distribution split into
two groups (target chromosome and others), colored by category/origin.

## Usage

``` r
Beeplot_chr_vs_other(
  dat,
  meta,
  group.by = "chr",
  color.by = "CATEGORY",
  outFile = NULL,
  verbose = FALSE
)
```

## Arguments

- dat:

  Data frame/matrix with sample columns plus grouping columns.

- meta:

  Metadata data frame containing `Sample_Name` and optional `ID2`.

- group.by:

  Column in `dat` used for faceting (default: `"chr"`).

- color.by:

  Column in `dat` used for point color (default: `"CATEGORY"`).

- outFile:

  Output PDF path.

- verbose:

  Logical; print sample-level progress.

## Value

`NULL`, writing plots to `outFile` as side effect.

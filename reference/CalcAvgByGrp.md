# Calculate Row-Wise Group Means

Computes per-row average values in `dat` for each `Sample_Group` defined
in `meta`, matching samples by `meta$Sample_Name` to column names in
`dat`.

## Usage

``` r
CalcAvgByGrp(dat, meta = NULL)
```

## Arguments

- dat:

  Numeric matrix/data frame with probes/features in rows and samples in
  columns.

- meta:

  Metadata data frame containing at least `Sample_Name` and
  `Sample_Group`.

## Value

Data frame of row-wise group means, one column per group.

# Find Matching Column Index/Indices

Find Matching Column Index/Indices

## Usage

``` r
idx_matching_column(df, columns, ignore.case = T)
```

## Arguments

- df:

  Data frame to query.

- columns:

  Character vector of candidate column names.

- ignore.case:

  Logical; case-insensitive matching when `TRUE`.

## Value

Integer vector of matching indices or `NULL` if none matched.

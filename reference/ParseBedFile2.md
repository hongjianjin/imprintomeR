# Parse BED File with Optional Annotation Columns

Parses BED-like input, normalizes coordinates, drops duplicate/invalid
rows, and returns both BED coordinates and optional trailing annotation
columns.

## Usage

``` r
ParseBedFile2(bedFile)
```

## Arguments

- bedFile:

  Path to BED file.

## Value

A list with `bed` (3-column data frame) and `anno` (optional data
frame).

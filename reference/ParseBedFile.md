# Parse, Sort, and Normalize BED File

Ensures `chr` prefix, sorts by genomic coordinates, writes a sorted BED
copy, and returns BED regions as `chr:start-end` strings.

## Usage

``` r
ParseBedFile(bedFile)
```

## Arguments

- bedFile:

  Path to BED file.

## Value

Character vector of BED regions.

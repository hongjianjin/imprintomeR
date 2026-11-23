# Load and Standardize Beta Matrix

Accepts beta input as data frame, `.rds`, or tab-delimited text.
Normalizes row IDs and handles optional `.Ave_Beta` sample suffixes.

## Usage

``` r
LoadBeta(input)
```

## Arguments

- input:

  Data frame or file path.

## Value

Beta matrix/data frame with probe IDs as row names.

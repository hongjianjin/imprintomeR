# Compute Imprinting Deviation Score (IDS)

Computes the Euclidean distance from the balanced imprinting state
\\(0.5, 0.5)\\ using paternal and maternal median methylation.

## Usage

``` r
compute_ids(paternal_median, maternal_median)
```

## Arguments

- paternal_median:

  Numeric vector of paternal median beta values.

- maternal_median:

  Numeric vector of maternal median beta values.

## Value

Numeric vector of IDS values.

## Details

Formula: \\IDS = sqrt((paternal_median - 0.5)^2 + (maternal_median -
0.5)^2)\\

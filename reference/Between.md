# Test Whether Values Lie in an Interval

Test Whether Values Lie in an Interval

## Usage

``` r
Between(values, low_cutoff = 0.3, high_cutoff = 0.7)
```

## Arguments

- values:

  Numeric vector.

- low_cutoff:

  Lower bound, exclusive (default 0.3).

- high_cutoff:

  Upper bound, inclusive (default 0.7).

## Value

Logical vector, `TRUE` where `low_cutoff < values <= high_cutoff`.

# Compute Mechanism Angle from Maternal/Paternal Medians

Computes directional angle in degrees from deviations relative to 0.5,
using `atan2(maternal_dev, paternal_dev)` and normalizing to `[0, 360)`.

## Usage

``` r
compute_angle(paternal_median, maternal_median)
```

## Arguments

- paternal_median:

  Numeric vector of paternal median beta values.

- maternal_median:

  Numeric vector of maternal median beta values.

## Value

Numeric vector of angles in degrees, normalized to `[0, 360)`.

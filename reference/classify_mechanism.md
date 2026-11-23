# Classify Imprinting Mechanism from Angle

Maps angle values to 8 mechanism sectors using a 22.5 degree shift and
45 degree bins. Optionally applies ROI override when IDS is provided.

## Usage

``` r
classify_mechanism(angle_degrees, ids = NULL, roi_cutoff = 0.2)
```

## Arguments

- angle_degrees:

  Numeric vector of angles in degrees `[0, 360)`.

- ids:

  Optional numeric vector of IDS values; when provided, entries with
  `ids < roi_cutoff` are labeled as `"ROI"`.

- roi_cutoff:

  Numeric ROI threshold used only when `ids` is provided.

## Value

Character vector of mechanism labels.

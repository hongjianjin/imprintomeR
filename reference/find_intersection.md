# Find Common Samples or Probes Between MethQcSet Objects

Identify common samples or probes between two `MethQcSet` objects.

## Usage

``` r
find_intersection(x, y, by = c("samples", "probes"))
```

## Arguments

- x:

  A `MethQcSet` object.

- y:

  A `MethQcSet` object.

- by:

  Character, "samples" (default) to find common samples, or "probes" for
  common probes.

## Value

Character vector of common identifiers (sample names or probe IDs).

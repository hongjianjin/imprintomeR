# Extract Probes Overlapping Input BED Region(s)

Unified implementation for probe extraction from either in-memory BED
coordinates (`bed`) or BED file input (`bedFile`). This harmonizes
legacy `ExtractProbesByBeds()` and `ExtractProbesByBeds2()` behavior.

## Usage

``` r
ExtractProbesByBeds(
  bed = NULL,
  bedFile = NULL,
  probes.all = NULL,
  assay = NULL,
  version = "HG19",
  verbose = FALSE,
  file = NULL
)
```

## Arguments

- bed:

  Character vector of BED regions (`chr:start-end`) or a 3-column
  BED-like data frame. Used when `bedFile` is `NULL`.

- bedFile:

  Optional BED file path. When provided, this mode is used.

- probes.all:

  Optional annotation table. If `NULL`, loads
  `inst/extdata/anno.uniq_harmonized.liftover.rds`.

- assay:

  Optional assay filter.

- version:

  Genome build label (`"HG19"` or `"HG38"`) used to select annotation
  columns.

- verbose:

  Logical passed to `bedr` helpers.

- file:

  Optional output path for writing tab-delimited results.

## Value

Data frame of matched probes. In `bedFile` mode, returns region-aware
output compatible with legacy `ExtractProbesByBeds2()`.

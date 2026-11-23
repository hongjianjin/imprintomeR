# Aggregate Platform-Specific Probes

Apply platform-specific probe aggregation. Currently supports EPICv2
aggregation (multiple measurements per base CpG to single representative
value).

## Usage

``` r
# S4 method for class 'MethQcSet'
aggregate_probes(x, method = c("median", "mean"), ...)
```

## Arguments

- x:

  A `MethQcSet` object.

- method:

  Character, aggregation method ("median" or "mean"). Default: "median".

- ...:

  Additional arguments (reserved for future use).

## Value

A `MethQcSet` object with:

- Updated `beta` slot (aggregated if platform=="EPICv2", unchanged
  otherwise)

- Updated `detection_pval` slot (if present)

- Updated `aggregation_status` slot

- An aggregation report in `qc_tables(x)$Aggregation_report`

If platform is not "EPICv2", returns object unchanged with message.

## Details

For EPICv2 data, this method calls
[`aggregate_beta_epicv2()`](https://hongjianjin.github.io/imprintomeR/reference/aggregate_beta_epicv2.md)
to consolidate multiple probe measurements (e.g., cg06373096_TC11,
cg06373096_TC12) into a single value per base probe ID (cg06373096).
This is essential before merging EPICv2 data with EPICv1 or 450K
cohorts.

The aggregation report (columns `metric`, `n`, `description`) counts the
replicate groups collapsed, identifiers kept unchanged, malformed
identifiers (kept or removed) and values missing because all replicates
were missing; see
[`aggregate_beta_epicv2()`](https://hongjianjin.github.io/imprintomeR/reference/aggregate_beta_epicv2.md).
A one-line summary is also printed as a message.

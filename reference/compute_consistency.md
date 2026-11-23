# Compute Allelic Consistency Metrics Per Sample

Calculates paternal/maternal concordance and average consistency for
each sample based on direction relative to a reference (0.5 by default).

## Usage

``` r
compute_consistency(
  paternal_beta,
  maternal_beta,
  sample_ids,
  paternal_reference = 0.5,
  maternal_reference = 0.5
)
```

## Arguments

- paternal_beta:

  Numeric matrix/data frame of paternal probes (rows) by samples
  (columns).

- maternal_beta:

  Numeric matrix/data frame of maternal probes (rows) by samples
  (columns).

- sample_ids:

  Character vector of sample IDs to evaluate.

- paternal_reference, maternal_reference:

  Reference methylation that direction is measured against: a scalar
  (default `0.5`), a per-probe vector, or a probe-by-sample matrix with
  the same layout as the beta input.

## Value

Data frame with columns `pat_cons`, `mat_cons`, and `consistency`.

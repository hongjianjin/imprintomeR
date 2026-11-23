# Summarize a MethQcSet Object

Generate a comprehensive inventory of a `MethQcSet` object including
sample counts, probe counts, QC status summary, and aggregation state.

## Usage

``` r
qc_summarize(x, ...)
```

## Arguments

- x:

  A `MethQcSet` object.

- ...:

  Additional arguments (reserved for future use).

## Value

A named list with:

- `platform`: Platform identifier

- `n_samples`: Number of samples

- `n_probes`: Number of probes

- `aggregation_status`: Current aggregation state

- `qc_status`: Summary of QC pass/fail counts (if qc_matrix present)

- `missing_values`: Count of missing values in beta matrix

- `qc_tables`: Names of QC tables stored

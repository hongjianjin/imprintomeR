# Multi-Locus Summary of Per-ICR Deviations

Summarizes
[`AnalyzeICRStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeICRStatus.md)
output per sample: the numbers of ICRs scored and called altered (gains
and losses), the altered ICRs and their chromosomes, and a multi-locus
flag. A sample is flagged `MLID` when its altered ICRs lie on at least
`min_chromosomes` different chromosomes, so that neighbouring ICRs of
one locus (for example the two DIRAS3 DMRs) count once.

## Usage

``` r
SummarizeICRStatus(
  icr_table,
  min_chromosomes = 2L,
  dmr_type = NULL,
  exclude_icrs = "VTRNA2-1:DMR"
)
```

## Arguments

- icr_table:

  Output of
  [`AnalyzeICRStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeICRStatus.md).

- min_chromosomes:

  Minimum number of chromosomes with an altered ICR for the multi-locus
  flag (default 2).

- dmr_type:

  Optional `DMR_type` values to summarize, for example `"gametic"`;
  `NULL` (default) uses every ICR in the table.

- exclude_icrs:

  ICRs left out of the counts and the multi-locus flag. The default
  excludes `VTRNA2-1:DMR` (nc886), a polymorphically imprinted,
  metastable DMR that is unmethylated in a sizeable fraction of healthy
  individuals. Its per-ICR deviations stay in the
  [`AnalyzeICRStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeICRStatus.md)
  table. Use `NULL` to count every ICR.

## Value

Data frame with one row per sample: `n_icrs`, `n_altered`, `n_gain`,
`n_loss`, `n_altered_chromosomes`, `altered_icrs`, `MLID`, and
`max_abs_deviation`.

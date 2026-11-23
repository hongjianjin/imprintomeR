# Aggregate EPICv2 Probes to Base Probe IDs

EPICv2 arrays report multiple measurements per base CpG probe (e.g.,
cg06373096_TC11, cg06373096_TC12, ..., cg06373096_TC110 all measure
cg06373096). This function aggregates repeated measurements into a
single representative value per unique probe ID.

## Usage

``` r
aggregate_beta_epicv2(beta_df, method = c("median", "mean"))
```

## Arguments

- beta_df:

  A data.frame with a `TargetID` column (probe IDs) and numeric columns
  (beta values, detection p-values, etc.). Can be coerced from matrix.

- method:

  Character, one of `c("median", "mean")`. Aggregation method for
  numeric columns. Default: `"median"`.

## Value

A data.frame with the same structure as `beta_df`, but with:

- `TargetID` column: base probe IDs (suffixes removed)

- Numeric columns: aggregated values (median or mean across replicates)

If no EPICv2-style suffixes are detected (`_[TB].\d+$`), returns
`beta_df` unchanged (with a message). In both cases the attribute
`aggregation_report` holds a data.frame (`metric`, `n`, `description`)
counting the identifiers: `input_rows`, `output_ids`,
`replicate_groups_collapsed` (base IDs built from two or more rows),
`replicate_rows_collapsed`, `suffix_stripped_single` (base IDs from a
single suffixed row), `unchanged_ids` (IDs without a replicate suffix,
kept as they are), `malformed_kept` (IDs with surrounding white space or
an underscore suffix that is not a replicate suffix; kept unchanged),
`malformed_dropped` (missing or empty IDs; removed), `all_missing_cells`
(aggregated values that are missing because every replicate was missing)
and `all_missing_ids` (output IDs missing in every column).

## Details

The function detects EPICv2 probe suffixes matching the pattern
`_[TB].\d+$` (e.g., `_TC11`, `_TB01`). If found, the suffix is stripped
and values are aggregated by base probe ID. Numeric columns are
aggregated using the chosen method, ignoring missing values; a group
whose values are all missing stays missing. All other columns are
dropped.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Load EPICv2 beta matrix
  beta_df <- read.delim("epicv2_beta.txt")
  
  # Aggregate to base probes
  beta_agg <- aggregate_beta_epicv2(beta_df, method = "median")
  
  # Check result
  dim(beta_agg)  # Fewer rows (unique base probes)
} # }
```

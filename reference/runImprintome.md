# Run Core Imprintome Analysis

User-facing entry point for running the core IDS/Angle/mechanism
workflow on an `ImprintomeSet` object using existing
[`AnalyzeImprintStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeImprintStatus.md)
logic.

## Usage

``` r
# S4 method for class 'ImprintomeSet'
runImprintome(
  x,
  probeset = "selected",
  ids_cutoff = 0.2,
  result_name = NULL,
  dmr_type = NULL,
  reference = c("auto", "controls", "fixed"),
  reference_group = NULL,
  reference_samples = NULL,
  reference_beta = NULL,
  infinium_type = c("all", "I", "II", "balanced"),
  balance = c("probe", "icr"),
  min_probes = 3L,
  icr = FALSE,
  delta_cutoff = 0.175,
  z_cutoff = 2,
  n_boot = 0L,
  n_perm = 0L,
  conf_level = 0.95,
  resample = c("icr", "probe"),
  permute = c("icr", "probe"),
  resample_reference = FALSE,
  seed = NULL,
  ...
)
```

## Arguments

- x:

  An `ImprintomeSet` object.

- probeset:

  Character scalar probeset name (for example, `"selected"`).

- ids_cutoff:

  Numeric IDS cutoff passed to
  [`AnalyzeImprintStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeImprintStatus.md).

- result_name:

  Optional name for storing output in `results(x)`.

- dmr_type:

  `DMR_type` selection passed to
  [`AnalyzeImprintStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeImprintStatus.md).
  `NULL` (default) uses the panel default: gametic ICRs only for the
  core `selected` panel, all probes for other panels. Use `"all"` for
  all probes or, for example, `"secondary"` to score secondary DMRs
  separately. An explicit value is added to the default result name (for
  example `AnalyzeImprintStatus.selected.all`); the `dmr_type` column of
  the result records the selection applied.

- reference, reference_group, reference_samples, reference_beta:

  Reference centring options passed to
  [`AnalyzeImprintStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeImprintStatus.md).
  By default (`"auto"`), external controls (`reference_beta`) or
  in-cohort controls (`reference_group`/`reference_samples`) are used
  when supplied, and the fixed 0.5 reference only when no controls are
  available.

- infinium_type:

  Infinium design types to score (`"all"`, `"I"`, `"II"` or
  `"balanced"`), passed to
  [`AnalyzeImprintStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeImprintStatus.md).

- balance:

  `"probe"` (default) or `"icr"` for the ICR-balanced sample-level
  IDS/Angle, passed to
  [`AnalyzeImprintStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeImprintStatus.md);
  `"icr"` adds `.icr` to the default result name.

- min_probes:

  Minimum probes per ICR for ICR-balanced and per-ICR scoring (default
  3).

- icr:

  Logical. If `TRUE`, also score each ICR with
  [`AnalyzeICRStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeICRStatus.md)
  (all annotated ICRs, with the same reference) and store the per-ICR
  table as `ICRStatus.<probeset>` and its per-sample multi-locus summary
  ([`SummarizeICRStatus()`](https://hongjianjin.github.io/imprintomeR/reference/SummarizeICRStatus.md))
  as `ICRSummary.<probeset>`.

- delta_cutoff, z_cutoff:

  Thresholds for altered-ICR calls, passed to
  [`AnalyzeICRStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeICRStatus.md)
  when `icr = TRUE` (defaults 0.175 and 2).

- n_boot, n_perm, conf_level, resample, permute, resample_reference,
  seed:

  Bootstrap uncertainty intervals and permutation null for IDS and
  Angle, passed to
  [`AnalyzeImprintStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeImprintStatus.md)
  (off by default; see its Uncertainty section). The added columns
  record the settings; result names are unchanged. The permutation
  p-value is interpretable only with a control reference.

- ...:

  Reserved for future compatibility.

## Value

Updated `ImprintomeSet` object with analysis table stored in
`results(x)`.

## Examples

``` r
if (FALSE) { # \dontrun{
beta_mat <- matrix(runif(200), nrow = 20)
rownames(beta_mat) <- paste0("cg", sprintf("%08d", seq_len(20)))
colnames(beta_mat) <- c("S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "S10")

meta_df <- data.frame(
  Sample_Name = colnames(beta_mat),
  Sample_Group = rep(c("A", "B"), each = 5),
  stringsAsFactors = FALSE
)

probeset_df <- data.frame(
  NAME = rownames(beta_mat),
  stringsAsFactors = FALSE
)

x <- ImprintomeSet(
  beta = beta_mat,
  meta = meta_df,
  probeset = probeset_df,
  genome = "hg19",
  assay = "EPICv1"
)

x <- runImprintome(x, probeset = "selected", ids_cutoff = 0.2)
head(results(x)[["AnalyzeImprintStatus.selected"]])
} # }
```

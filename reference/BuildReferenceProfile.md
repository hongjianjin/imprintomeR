# Build a Reusable Control Reference Profile

Summarizes a set of control samples into per-probe median beta values.
The result can be passed as `reference_beta` to
[`AnalyzeImprintStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeImprintStatus.md)
or
[`runImprintome()`](https://hongjianjin.github.io/imprintomeR/reference/runImprintome.md),
so that one tissue-matched control set (for example public normal
samples) can centre cohorts that have no controls of their own. Save it
with [`saveRDS()`](https://rdrr.io/r/base/readRDS.html) to reuse it
across studies.

## Usage

``` r
BuildReferenceProfile(
  beta,
  samples = NULL,
  probeset = NULL,
  genome = "hg38",
  normalization = NULL
)
```

## Arguments

- beta:

  Probe-by-sample beta matrix, data frame, file path, a `MethQcSet`
  (EPICv2 data must be aggregated first with
  [`aggregate_probes()`](https://hongjianjin.github.io/imprintomeR/reference/aggregate_probes-MethQcSet-method.md)),
  or an `ImprintomeSet`.

- samples:

  Optional character vector of control sample names; `NULL` uses all
  samples.

- probeset:

  Optional probeset name. The profile is limited to its probes. `NULL`
  (default) keeps every probe of every probe-level panel of `genome`, so
  one profile serves all panels.

- genome:

  Genome build of the probeset annotation, `"hg19"` or `"hg38"` (default
  `"hg38"`). Ignored when `beta` is an `ImprintomeSet`, whose own genome
  is used.

- normalization:

  Beta normalization of the control data, for example `"noob"` (see
  [`runMethQC()`](https://hongjianjin.github.io/imprintomeR/reference/runMethQC.md)).
  Taken from `qc_params(beta)$normalization` when `beta` is a
  `MethQcSet` and this argument is `NULL`. It is recorded in the profile
  and reported in the `reference` column of scoring results, so that a
  profile can be matched to cohorts preprocessed the same way.

## Value

Named numeric vector of per-probe median beta values, with attributes
`n_samples`, `genome`, `probeset`, and `normalization` (`"unspecified"`
when unknown).

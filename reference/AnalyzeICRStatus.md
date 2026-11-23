# Per-ICR Imprinting Deviations

Scores each imprinting control region (ICR) of a panel separately. For
every sample and ICR with at least `min_probes` probes, the deviation is
the median over the ICR's probes of `beta - reference`
(`median(beta) - 0.5` with the fixed reference). Each ICR has a single
parental origin, so its deviation lies on one axis: a gain or loss of
methylation on the paternal or maternal axis. Two-axis IDS/Angle for a
single imprinted domain is obtained by scoring a locus panel such as
`chr11p15` or `chr20q13` with
[`AnalyzeImprintStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeImprintStatus.md).

## Usage

``` r
AnalyzeICRStatus(
  betaFile,
  metaFile = NULL,
  probeset = "selected",
  genome = "hg38",
  dmr_type = NULL,
  reference = c("auto", "controls", "fixed"),
  reference_group = NULL,
  reference_samples = NULL,
  reference_beta = NULL,
  control_group = reference_group,
  control_samples = reference_samples,
  min_probes = 3L,
  delta_cutoff = 0.175,
  z_cutoff = 2
)
```

## Arguments

- betaFile:

  Data frame/matrix or file path containing probe-by-sample beta values,
  or an `ImprintomeSet` object.

- metaFile:

  Metadata data frame or file path. Must be provided unless `betaFile`
  is an `ImprintomeSet`.

- probeset:

  Character scalar naming a probeset key.

- genome:

  Genome build of the probeset annotation, `"hg19"` or `"hg38"` (default
  `"hg38"`). Ignored when `betaFile` is an `ImprintomeSet`, whose own
  genome is used.

- dmr_type:

  `DMR_type` values to score. `NULL` (default) scores every annotated
  ICR, gametic and secondary alike; the `DMR_type` column of the result
  records each ICR's type.

- reference:

  How the balanced reference state is defined.

  - `"auto"` (default): use control samples when they are supplied,
    either external (`reference_beta`) or in-cohort (`reference_group`/
    `reference_samples`). Fall back to the fixed 0.5 only when no
    controls are given, or when fewer than 3 are available (with a
    warning).

  - `"controls"`: require a control reference; too few controls is an
    error.

  - `"fixed"`: always use 0.5, the original behaviour.

  With controls, each probe's reference is the median beta of that probe
  across the controls. Paternal and maternal deviations are medians of
  `beta - reference`, and IDS and Angle are computed from these
  deviations instead of from `median - 0.5`.

- reference_group:

  Optional `Sample_Group` value(s) whose samples form an in-cohort
  control reference. Each control is itself scored against the other
  controls (leave-one-out).

- reference_samples:

  Optional character vector of in-cohort control sample names, used
  instead of `reference_group`.

- reference_beta:

  Optional external control reference, used when the cohort has no (or
  too few) controls. It can be one of:

  - a probe-by-sample beta matrix or data frame;

  - a beta file path;

  - a per-probe profile from
    [`BuildReferenceProfile()`](https://hongjianjin.github.io/imprintomeR/reference/BuildReferenceProfile.md),
    given as the object or as an `.rds` path.

  It should match the cohort's tissue, array type and preprocessing.
  Probes absent from the reference are dropped.

- control_group, control_samples:

  In-cohort controls used to standardize deviations (`z`). Default to
  `reference_group` and `reference_samples`. Without controls, `z` is
  `NA` and calls use `delta_cutoff` only.

- min_probes:

  Minimum number of probes for an ICR to be scored (default 3).

- delta_cutoff:

  Minimum absolute deviation for an altered call (default 0.175).

- z_cutoff:

  Minimum absolute z-score for an altered call when controls are
  available (default 2), or `NULL` for no z criterion.

## Value

Data frame with one row per sample and ICR: sample metadata, `probeset`,
`ICR_name`, `ORIGIN`, `DMR_type`, `CHR`, `start`, `n_probes`,
`median_beta`, `reference` (median reference beta), `deviation`,
`abs_deviation`, `z`, `direction` (`"gain"` or `"loss"`) and `altered`.
Settings are stored in attribute `icr_settings`.

## Details

An ICR is called altered when `abs(deviation) >= delta_cutoff` and, if
`z_cutoff` is set and control samples are available, also
`abs(z) >= z_cutoff`. Both criteria are symmetric, so gains and losses
are called alike. For sample `i` and ICR `k`, with deviation `d[i, k]`,

`z[i, k] = (d[i, k] - median(d[C, k])) / max(SD(d[C, k]), 0.02)`,

where `C` is the set of controls, excluding `i` when `i` is itself a
control. The standard deviation is floored at 0.02 so that very
homogeneous controls do not inflate `z`. When the controls also form the
reference, each control's deviation is computed leave-one-out as well,
so control z-scores are out-of-sample in the same way as those of cases.
`z` is reported whenever at least 3 controls are available; with fewer
than 10 a warning notes that the control median and SD are unstable.

The defaults (`delta_cutoff = 0.175`, `z_cutoff = 2`) were selected
under the prespecified threshold-selection protocol in the package
repository (`benchmark/`, amendment 5), by leave-one-cohort-out
cross-validation on six development cohorts with leave-one-out control
z-scores, and evaluated in three additional cohorts. Earlier versions
used `delta_cutoff = 0.075` with `z_cutoff = 3` (control z-scores
computed in-sample), and before that `delta_cutoff = 0.15`. The
thresholds were selected with control samples (in-cohort, or external
controls of the same tissue and platform), so that the z criterion
applies. Without controls `z` is `NA` and only `delta_cutoff` is
applied; that setting was not evaluated and calls are exploratory.

## See also

[`SummarizeICRStatus()`](https://hongjianjin.github.io/imprintomeR/reference/SummarizeICRStatus.md)
for the per-sample multi-locus summary and
[`PlotICRHeatmap()`](https://hongjianjin.github.io/imprintomeR/reference/PlotICRHeatmap.md).

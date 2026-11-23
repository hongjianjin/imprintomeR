# Comprehensive Imprinting Analysis for a Sample Cohort

Computes maternal/paternal medians, IDS, angle, mechanism, status, and
confidence per sample for a selected probeset. Supports both legacy
beta/meta inputs and object-first `ImprintomeSet` input.

## Usage

``` r
AnalyzeImprintStatus(
  betaFile,
  metaFile,
  probeset = probeset_options,
  ids_cutoff = 0.2,
  genome = "hg38",
  dmr_type = NULL,
  reference = c("auto", "controls", "fixed"),
  reference_group = NULL,
  reference_samples = NULL,
  reference_beta = NULL,
  infinium_type = c("all", "I", "II", "balanced"),
  balance = c("probe", "icr"),
  min_probes = 3L,
  n_boot = 0L,
  n_perm = 0L,
  conf_level = 0.95,
  resample = c("icr", "probe"),
  permute = c("icr", "probe"),
  resample_reference = FALSE,
  seed = NULL
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

- ids_cutoff:

  Numeric scalar threshold used to call imprinting alteration by IDS.

- genome:

  Genome build of the probeset annotation, `"hg19"` or `"hg38"` (default
  `"hg38"`). Ignored when `betaFile` is an `ImprintomeSet`, whose own
  genome is used.

- dmr_type:

  `DMR_type` values to score:

  - `NULL` (default): the panel default. The core `selected` panel is
    scored on gametic ICRs only (`"gametic"`); every other panel, and
    any panel without a `DMR_type` column, is scored on all probes.

  - `"all"`: all probes, including secondary DMRs (the earlier default
    for `selected`).

  - one or more `DMR_type` values, for example `"gametic"` or
    `"secondary"` (secondary DMRs reported separately). Requires a
    `DMR_type` column in the probeset.

  The `dmr_type` output column records the selection that was applied.

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

- infinium_type:

  Infinium probe design types to score:

  - `"all"` (default): all probes;

  - `"I"` or `"II"`: only that design type;

  - `"balanced"`: compute each parental-class deviation separately
    within type I and type II probes, then average them.

  Anything other than `"all"` requires an `INFINIUM_DESIGN_TYPE` column
  in the probeset.

- balance:

  How probes are pooled into each parental class:

  - `"probe"` (default): the median over all probes of the class, so
    that probe-rich ICRs weigh more;

  - `"icr"`: ICR-balanced, the median within each ICR (see
    [`AnalyzeICRStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeICRStatus.md))
    followed by the median across the class's ICRs, so that each ICR
    counts once. Requires an `ICR_name` column; probes outside annotated
    ICRs are not used. Cannot be combined with
    `infinium_type = "balanced"`.

- min_probes:

  Minimum number of probes for an ICR to count when `balance = "icr"`
  (default 3).

- n_boot:

  Number of bootstrap replicates for confidence intervals of IDS and
  Angle (default 0, none). Several hundred to a few thousand are
  typical.

- n_perm:

  Number of permutations for the parental-label null of the origin
  contrast (default 0, none). Use it only with a control reference (see
  Uncertainty).

- conf_level:

  Confidence level of the bootstrap intervals (default 0.95).

- resample:

  Bootstrap resampling unit within each parental class:

  - `"icr"` (default): two-stage cluster bootstrap. ICRs are resampled
    with replacement, then probes within each drawn ICR, so that
    correlated probes of one ICR are not treated as independent. Probes
    outside annotated ICRs count as their own cluster, and a class with
    a single ICR (for example IC1 or IC2 of `chr11p15`) reduces to
    resampling its probes. Requires an `ICR_name` column; otherwise
    `"probe"` is used, with a message.

  - `"probe"`: probes are resampled within the class (within Infinium
    design types for `infinium_type = "balanced"`, within ICRs for
    `balance = "icr"`). This ignores within-ICR correlation and gives
    narrower intervals.

- permute:

  Permutation unit for the null:

  - `"icr"` (default): whole ICRs are reassigned; requires at least two
    annotated ICRs in each parental class. Always used with
    `balance = "icr"`. With `a` paternal and `b` maternal ICRs there are
    only `choose(a + b, a)` distinct assignments, which bounds the
    smallest attainable p-value; a warning is given below 100. When the
    default cannot be used (a panel with one ICR per class, such as
    `chr11p15`), the test falls back to `"probe"` with a warning;

  - `"probe"`: the parental labels of probes are shuffled, keeping the
    numbers of paternal and maternal probes (per design type for
    `infinium_type = "balanced"`). Correlated probes are exchanged
    individually, so p-values are anti-conservative.

- resample_reference:

  With `n_boot > 0` and in-cohort controls (`reference_group` or
  `reference_samples`), also resample the controls in each replicate and
  recompute the reference from them (each control again leave-one-out),
  so the intervals include the uncertainty of the reference itself.
  Default `FALSE` holds the reference fixed. Ignored, with a message,
  for the fixed 0.5 or an external reference.

- seed:

  Optional random seed for `n_boot`/`n_perm`, for reproducible results;
  the caller's random number stream is restored afterwards.

## Value

Data frame with sample-level imprinting metrics and labels.
`paternal_deviation` and `maternal_deviation` are the coordinates that
IDS and Angle are computed from. `reference` and `n_reference_samples`
describe the reference used. `balance` records the pooling; with
`balance = "icr"`, the columns `n_paternal_icrs` / `n_maternal_icrs`
give the numbers of ICRs used. With `n_boot > 0`, the columns
`IDS_lower`, `IDS_upper`, `Angle_lower`, `Angle_upper`,
`Mechanism_support`, `n_boot`, `resample` and `resample_reference` are
added, and `Status_interval`: `"above cutoff"`
(`IDS_lower >= ids_cutoff`), `"below cutoff"` (`IDS_upper < ids_cutoff`)
or `"borderline"` (the interval spans the cutoff); with `n_perm > 0`,
`origin_perm_p`, `n_perm` and `permute` (see Uncertainty). Calibrate the
IDS cutoff on controls with
[`CalibrateIDS()`](https://hongjianjin.github.io/imprintomeR/reference/CalibrateIDS.md).

Samples with IDS below `ids_cutoff` get `Status = "Normal"` and
`Mechanism = "ROI"`. `Confidence` labels IDS with fixed exploratory
screening bands (\< 0.1 "High (Normal)", 0.1-0.2 "Low (Normal)", 0.2-0.4
"Moderate (Alteration)", \>= 0.4 "High (Alteration)"); the bands do not
change with `ids_cutoff` and are not a measure of statistical certainty.
For that, use `Status_interval` (with `n_boot`) or calibrate on controls
with
[`CalibrateIDS()`](https://hongjianjin.github.io/imprintomeR/reference/CalibrateIDS.md).

## Uncertainty

With `n_boot > 0`, each sample's paternal and maternal deviations are
recomputed on resampled probes (see `resample`), and percentile
intervals are reported for IDS (`IDS_lower`, `IDS_upper`) and Angle
(`Angle_lower`, `Angle_upper`, a circular interval around the observed
angle, read clockwise from lower to upper). `Mechanism_support` is the
fraction of replicates in the reported `Mechanism` sector (including
`"ROI"`), a measure of label stability. These are bootstrap uncertainty
intervals, not tests. By default they are conditional on the reference:
the controls are not resampled, so with few controls they understate the
total uncertainty; set `resample_reference = TRUE` to resample in-cohort
controls as well. Because IDS is a distance, its interval never includes
0 and is biased upward for samples near balanced imprinting, so it
describes stability and ranking rather than testing against 0; the Angle
interval is uninformative when the IDS interval reaches the ROI zone.

With `n_perm > 0`, `origin_perm_p` tests whether the sample's deviation
depends on the parental-origin annotation, as an imprinting defect does,
rather than being shared by all probes. The statistic is the origin
contrast `|paternal_deviation - maternal_deviation|`, which is zero for
a shift common to both classes (Global-Hyper, Global-Hypo) and large for
single-axis or opposite-axis deviations; the p-value is
`(1 + #{contrast_perm >= contrast}) / (1 + n_perm)` after reassigning
the parental labels. IDS itself is not used, because when one class has
many more probes, shuffled labels give both classes the majority's
deviation. With `permute = "probe"` correlated probes are exchanged
individually, so p-values are anti-conservative. p-values are per sample
and not adjusted for multiple testing.

`origin_perm_p` is interpretable only with a control reference
(`reference_group`, `reference_samples` or `reference_beta`). Against
the fixed 0.5 reference, normal tissue already deviates slightly, and by
different amounts, on the paternal and maternal axes (Infinium probe
design, tissue-specific methylation); with hundreds of probes, such a
baseline offset alone yields small p-values, so most normal samples
would be flagged. With tissue-matched controls the baseline is removed
and the test addresses the sample's own departure from it. The bootstrap
intervals are meaningful with either reference.

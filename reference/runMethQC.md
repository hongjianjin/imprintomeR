# Load IDAT Files, Run Quality Control, and Create a MethQcSet

Factory function that reads IDAT files for all samples in `meta`,
extracts normalized beta values and detection p-values via minfi,
constructs a `MethQcSet` object, and computes QC metrics. Returns a
fully populated `MethQcSet`.

## Usage

``` r
runMethQC(
  meta,
  platform = NA,
  pcutoff = 0.05,
  normalization = c("noob", "noob_swan", "raw"),
  save_qc_report = TRUE,
  plot_types = c("intensity", "detection_pval", "probe_coverage", "beta_density"),
  outdir = ".",
  prefix = NULL,
  ...
)
```

## Arguments

- meta:

  A `data.frame` with columns:

  Sample_Name

  :   Sample identifiers (required)

  Basename

  :   IDAT file path prefix, e.g. `/path/to/idats/Sentrix_ID`
      (required). Files `Sentrix_ID_Red.idat` and `Sentrix_ID_Grn.idat`
      must exist at that path.

  Platform

  :   (optional) Platform string. Used by platform resolution when
      `platform = NA`.

- platform:

  Platform string (`"EPIC"`, `"EPICv2"`, `"450K"`) or `NA` (default).
  Resolution rules:

  `NA` + `Platform` column in meta with one unique value

  :   Auto-use that value. Run `check_platform(meta)` first to populate
      this column.

  `NA` + `Platform` column in meta with multiple values

  :   Error with instructions to subset meta by platform and re-call.

  `NA` + no `Platform` column in meta

  :   Error with instructions to run `check_platform(meta)` first.

  Explicit string (e.g. `"EPIC"`)

  :   Use provided value; any existing `Platform` column in meta is
      ignored.

- pcutoff:

  Detection p-value threshold for `Final.QC` (default 0.05): at least
  95% of probes must be detected at p \< `pcutoff`.

- normalization:

  Beta-value normalization:

  - `"noob"` (default): background and dye-bias correction
    (`minfi::preprocessNoob(dyeMethod = "single")`);

  - `"noob_swan"`: noob followed by SWAN, which adjusts Infinium type
    I/II differences
    ([`minfi::preprocessSWAN()`](https://rdrr.io/pkg/minfi/man/preprocessSwan.html),
    run with a fixed seed so results are reproducible);

  - `"raw"`: unnormalized beta
    ([`minfi::preprocessRaw()`](https://rdrr.io/pkg/minfi/man/preprocessRaw.html)),
    the behaviour of earlier package versions.

- save_qc_report:

  Logical. If `TRUE`, write package-native QC plot PDFs and
  density-report PDFs. Default: `TRUE`.

- plot_types:

  Character vector or comma-separated string of package-native QC plot
  types to write when `save_qc_report = TRUE`. The default is
  `c("intensity", "detection_pval", "probe_coverage", "beta_density")`;
  beta density writes all, PASS, and FAIL sample PDFs. Use `NULL`,
  `character(0)`, or `"none"` to skip package-native QC plot PDFs.

- outdir:

  Directory for QC plot/report PDFs. Default: `"."`.

- prefix:

  Filename prefix for QC plot/report PDFs. If `NULL`, the resolved
  platform name is used.

- ...:

  Additional arguments passed to
  [`minfi::read.metharray.exp()`](https://rdrr.io/pkg/minfi/man/read.metharray.exp.html).

## Value

A `MethQcSet` object with:

- `beta` slot populated from
  [`minfi::getBeta()`](https://rdrr.io/pkg/minfi/man/MethylSet-class.html)
  after `normalization`

- `detection_pval` slot populated from
  [`minfi::detectionP()`](https://rdrr.io/pkg/minfi/man/detectionP.html)

- `qc_tables` slot populated with QC metrics

- `platform` slot set to the resolved platform string

- `qc_params` slot recording `normalization` and the minfi
  `array_annotation`

## Details

Beta values are normalized with `normalization`; all three methods work
on 450K, EPIC and EPICv2 arrays and normalize each sample on its own, so
a sample's beta values do not depend on which other samples are in the
cohort. Detection p-values, probe intensities and predicted sex are
always computed from the unnormalized data. The method is recorded in
`qc_params(x)$normalization`. Normalization changes beta values and
hence IDS, so compare cohorts, and build reference profiles
([`BuildReferenceProfile()`](https://hongjianjin.github.io/imprintomeR/reference/BuildReferenceProfile.md)),
with the same method.

EPICv2 arrays are not recognized by minfi releases before Bioconductor
3.19; for platform `"EPICv2"` (or an unrecognized array with more than
1.1 million probes) the minfi annotation is set to
`IlluminaHumanMethylationEPICv2` / `20a1.hg38`. This requires the
`IlluminaHumanMethylationEPICv2manifest` and
`IlluminaHumanMethylationEPICv2anno.20a1.hg38` packages.

`Final.QC` in `qc_tables(x)$QC_matrix` is `"PASS"` when at least 95% of
probes are detected at p \< `pcutoff` (default 0.05) and, when the
control-probe metrics could be computed, `CtrlMetrics.QC` is `"PASS"`.
`CtrlMetrics.QC` is `"FAIL"` only when Bisulfite Conversion I Green or
Red falls below its threshold (1). The other control metrics are
reported in `qc_tables(x)$ctrl_metrics` but do not fail a sample.

The control-probe metrics (Illumina BeadArray Controls Reporter), SNP
genotype calls, sample-swap check (`contamination`: sample pairs whose
genotype agreement contradicts `Donor_ID`, or `Sample_Name` when absent)
and predicted donors follow the ewastools methods (Heiss and Just, 2018)
and give the same results as ewastools 1.8.2; ewastools itself is not
needed.

## See also

[`check_platform()`](https://hongjianjin.github.io/imprintomeR/reference/check_platform.md)
to detect and annotate platforms before calling this function;
[MethQcSet](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-class.md)
for the returned object.

## Examples

``` r
if (FALSE) { # \dontrun{
# Case 1: Known single-platform cohort
meta <- read.table("meta.tsv", header = TRUE, sep = "\t")
qcset <- runMethQC(meta, platform = "EPIC")

# Default QC plot/report PDFs:
#   epic_QC_detection_pval.pdf, epic_QC_probe_coverage.pdf
#   epic_QC_minfiDensity_all.pdf
#   plots/epic_QC_intensity.pdf
#   plots/epic_QC_betaDensity_all/pass/fail.pdf
#   plots/epic_QC_minfiDensity_pass/fail.pdf
qcset <- runMethQC(meta, platform = "EPIC",
                   outdir = "qc_output",
                   prefix = "epic")

# Case 2: Platform unknown - detect first, then run QC
meta <- check_platform(meta)
table(meta$Platform)  # inspect

meta_epic <- meta[meta$Platform == "EPIC", ]
qcset_epic <- runMethQC(meta_epic)  # platform auto-resolved from meta$Platform

meta_450k <- meta[meta$Platform == "450K", ]
qcset_450k <- runMethQC(meta_450k)
} # }
```

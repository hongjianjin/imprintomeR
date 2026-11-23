# Export MethQcSet Data

Write QC tables, beta values, and metadata to disk in various formats.

## Usage

``` r
# S4 method for class 'MethQcSet'
export(x, outdir, format = c("xlsx", "rds"), prefix = "methqcset", ...)
```

## Arguments

- x:

  A `MethQcSet` object.

- outdir:

  Directory where files will be written.

- format:

  Character vector of output formats: `"xlsx"` (default, requires
  openxlsx), `"rds"`, or `"txt"` (tab-delimited). Multiple formats can
  be combined.

- prefix:

  Character, prefix for output filenames (default: "methqcset").

- ...:

  Additional arguments (reserved for future use).

## Value

Invisibly returns a character vector of written file paths.

## Details

**xlsx output (recommended):** QC results are written into organized
output locations. Root-level files include `{prefix}_qc_table_main.xlsx`
and `{prefix}_summary.txt`; supplementary tables go under `QC_tables/`,
and large data objects go under `data/`:

`{prefix}_qc_table_main.xlsx` (primary QC results):

- `metadata` sheet: Sample metadata augmented with Platform and Final.QC
  columns.

- `QC_matrix` sheet: Per-sample QC metrics (intensity, detection p-val,
  coverage, sex, etc.).

- `Ctrl_matrix` sheet: control-probe metric scores (if available).

- `statistics` sheet: Per-Sample_Group summary (Total, PASS, FAIL, and
  ratios).

`QC_tables/{prefix}_qc_table_extra.xlsx` (supplementary/technical
results):

- `QC_metrics` sheet: Cutoff thresholds and decision rules (filtered to:
  criteria, cutoff, Final.QC).

- `contamination` sheet: SNP agreement matrix for sample swap detection
  (if available).

- `recall_rate` sheet: Per-probe detection statistics across cohort (if
  available).

- `predUniqDonor_ID` sheet: Predicted unique donors per Sample_Group (if
  available).

Beta values are excluded from xlsx (too large); they are retained in the
RDS object and optionally written as `data/{prefix}_beta.txt` when
`format = "txt"`.

**rds output:** Entire MethQcSet object is saved as
`data/{prefix}_qcset.rds` for programmatic access.

**txt output:** Tab-delimited beta/metadata files are written to
`data/`; QC table text files are written to `QC_tables/`.

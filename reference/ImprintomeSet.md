# Construct an ImprintomeSet Object

Construct an ImprintomeSet Object

## Usage

``` r
ImprintomeSet(
  beta,
  meta,
  probeset,
  genome,
  assay,
  results = list(),
  plots = list(),
  auto_group = FALSE
)
```

## Arguments

- beta:

  Matrix or data.frame of beta values (rows = probes, columns =
  samples). A probe-ID column named `NAME`, `TargetID`, or `ID` in a
  data.frame is moved into the row names.

- meta:

  data.frame containing sample metadata. Must include `Sample_Name`;
  `Sample_Group` is required unless `auto_group=TRUE`.

- probeset:

  data.frame or list containing probeset annotation.

- genome:

  Character scalar for genome build (for example, `"hg19"` or `"hg38"`).

- assay:

  Character scalar for assay type (for example, `"450K"`, `"EPICv1"`,
  `"EPICv2"`).

- results:

  Optional named list of result objects.

- plots:

  Optional named list of plot objects.

- auto_group:

  Logical. If `TRUE` and `Sample_Group` column is missing, auto-creates
  it with value `"Unknown"` for all samples (Tier C: minimal metadata).
  Default: `FALSE`.

## Value

An object of class `ImprintomeSet`.

## Details

**Three metadata tiers supported:**

- **Tier A (QC-ready):** Sample_Name + Sample_Group + Basename (for
  runMethQC)

- **Tier B (Analysis-ready):** Sample_Name + Sample_Group (default
  requirement)

- **Tier C (Auto-group):** Sample_Name only (if `auto_group=TRUE`;
  Sample_Group auto-created with "Unknown")

# Convert MethQcSet to ImprintomeSet

Convert a QC-clean, single-platform `MethQcSet` to an analysis-ready
`ImprintomeSet` for downstream imprintome analysis.

## Usage

``` r
# S4 method for class 'MethQcSet'
as.ImprintomeSet(x, probeset = NULL, genome = "hg38", ...)
```

## Arguments

- x:

  A `MethQcSet` object.

- probeset:

  Optional data.frame or list of probe set annotation. If NULL, the
  bundled probeset panels for `genome` are loaded
  (`probesets_<genome>.rds`).

- genome:

  Character scalar for genome build ("hg19" or "hg38"). Default: "hg38".

- ...:

  Additional arguments (reserved for future use).

## Value

An `ImprintomeSet` object with:

- `beta`: Beta matrix from x@beta

- `meta`: Sample metadata from x@meta

- `probeset`: Probe annotation data

- `assay`: Array assay type derived from x@platform

- `genome`: Genome build

- `qc`: QC tables from x@qc_tables (stored for reference)

- `results`: Empty (to be populated by runImprintome)

- `plots`: Empty (to be populated by plotting functions)

## Details

**Validation checks:**

- Ensures single platform (platform-specific check)

- Validates samples have non-missing QC status (if QC_matrix present)

- Warns if EPICv2 aggregation status is not confirmed

**Probeset Loading:** If probeset is NULL, the named list of bundled
probeset panels for `genome` (hg19 or hg38) is loaded. Probe IDs are
shared across 450K, EPIC, and EPICv2 (after aggregation), so the same
panels serve every platform.

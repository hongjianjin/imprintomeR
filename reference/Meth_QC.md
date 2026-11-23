# Summarize Core Methylation Array QC Metrics

Creates a deterministic QC bundle from matched metadata/beta inputs and
optional detection p-values or a minfi object. The returned list is
designed Not intended for direct storage in ImprintomeSet (QC data is
handled by MethQcSet).

## Usage

``` r
Meth_QC(
  betaFile,
  metaFile = NULL,
  detection_p = NULL,
  minfi_object = NULL,
  assay = NULL,
  p_cutoff = 0.05,
  mean_detection_cutoff = 0.03,
  intensity_cutoff = 11
)
```

## Arguments

- betaFile:

  Beta matrix/data.frame, file path, or an `ImprintomeSet`.

- metaFile:

  Optional metadata data.frame or file path. Not required when
  `betaFile` is an `ImprintomeSet`.

- detection_p:

  Optional detection p-value matrix/data.frame with samples in columns.

- minfi_object:

  Optional minfi object used to derive methylated and unmethylated
  intensity medians.

- assay:

  Optional assay label. When omitted and `betaFile` is an
  `ImprintomeSet`, `assay(betaFile)` is used.

- p_cutoff:

  Detection p-value threshold used for per-sample recall.

- mean_detection_cutoff:

  Mean detection p-value threshold for PASS/FAIL.

- intensity_cutoff:

  Minimum average median intensity for PASS/FAIL.

## Value

Named list containing `metadata_qc`, `beta_qc`, optional `detection_qc`,
optional `detection_recall_rate`, optional `intensity_qc`, and merged
`sample_qc`.

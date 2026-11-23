# MethQcSet S4 Class

Formal container for preprocessing/QC data within a single methylation
array platform.

## Details

The MethQcSet represents a cohort of samples from a single array
platform (450K, EPIC, EPICv2, or mouse) after preprocessing and QC. It
holds metadata, beta values, detection p-values, QC results tables, and
platform/aggregation state information. This object precedes
ImprintomeSet in the analysis workflow and serves as the
preprocessing/QC container.

## Slots

- `meta`:

  data.frame of sample metadata. Must include `Sample_Name` column. Row
  order must match beta column order.

- `platform`:

  Character scalar indicating platform ("450K", "EPIC", "EPICv2",
  "mouse").

- `beta`:

  Matrix of beta values (rows = probes, columns = samples).

- `detection_pval`:

  Matrix or NULL. Detection p-values, same dims/order as beta.

- `qc_tables`:

  Named list of QC result data.frames. Canonical keys (populated by
  [`runMethQC()`](https://hongjianjin.github.io/imprintomeR/reference/runMethQC.md)):
  `QC_matrix`, `ctrl_metrics`, `recall_rate`, `contamination`,
  `predUniqDonor_ID`, `cutoffs`, and optional `qc_report_files`.
  [`aggregate_probes()`](https://hongjianjin.github.io/imprintomeR/reference/aggregate_probes-MethQcSet-method.md)
  adds `Aggregation_report`.

- `aggregation_status`:

  Character scalar: "none", "epicv2_aggregated", or other flag.

- `qc_params`:

  Named list of QC parameters used (pcutoff, method, etc.).

- `statistics`:

  data.frame or NULL. Per-group QC statistics (GROUP, Total, PASS, FAIL,
  PASS.RATIO, FAIL.RATIO). Populated on export when Sample_Group is
  present in metadata.

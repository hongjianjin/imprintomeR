# Construct a MethQcSet Object

Create a preprocessing/QC container for a single-platform methylation
array cohort.

## Usage

``` r
MethQcSet(
  meta,
  platform,
  beta,
  detection_pval = NULL,
  qc_tables = list(),
  aggregation_status = "none",
  qc_params = list()
)
```

## Arguments

- meta:

  data.frame containing sample metadata with `Sample_Name` column.

- platform:

  Character scalar for platform identifier ("450K", "EPIC", "EPICv2",
  "mouse").

- beta:

  Matrix of beta values (rows = probes, columns = samples).

- detection_pval:

  Optional matrix of detection p-values, same dims as beta.

- qc_tables:

  Optional named list of QC result data.frames.

- aggregation_status:

  Character scalar indicating aggregation state (default: "none").

- qc_params:

  Optional named list of QC parameters used.

## Value

An object of class `MethQcSet`.

# Compute Per-Group QC Statistics (Internal)

Internal helper to compute sample counts and PASS/FAIL ratios per
Sample_Group.

## Usage

``` r
.compute_statistics(qc_matrix, meta)
```

## Arguments

- qc_matrix:

  data.frame with columns: Sample_Name (or SAMPLE_NAME), Final.QC.

- meta:

  data.frame with columns: Sample_Name, and optionally Sample_Group.

## Value

data.frame with columns: GROUP, Total, PASS, FAIL, PASS.RATIO,
FAIL.RATIO. Returns NULL if Final.QC column missing or all-NA.

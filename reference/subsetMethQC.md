# Subset a MethQcSet by QC Status or Sample Names

Create a valid `MethQcSet` containing only selected samples. By default,
this keeps samples with `Final.QC == "PASS"` from
`qc_tables(x)[["QC_matrix"]]`, making it convenient to carry QC-clean
beta values into
[`as.ImprintomeSet()`](https://hongjianjin.github.io/imprintomeR/reference/as.ImprintomeSet-MethQcSet-method.md).

## Usage

``` r
subsetMethQC(x, final_qc = "PASS", sample_names = NULL)
```

## Arguments

- x:

  A `MethQcSet` object.

- final_qc:

  Character vector of `Final.QC` values to keep. Defaults to `"PASS"`.
  Ignored when `sample_names` is supplied.

- sample_names:

  Optional character vector of sample names to keep.

## Value

A valid `MethQcSet` subset to the requested samples.

## Examples

``` r
if (FALSE) { # \dontrun{
qcset_pass <- subsetMethQC(qcset)
beta_pass <- beta(qcset_pass)
} # }
```

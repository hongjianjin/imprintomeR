# Compute QC Metrics on a MethQcSet

Internal method. Compute QC metrics from beta values and detection
p-values, storing results in qc_tables. Called internally by
[`runMethQC()`](https://hongjianjin.github.io/imprintomeR/reference/runMethQC.md).

## Usage

``` r
# S4 method for class 'MethQcSet'
computeQC(x, detection_pval = NULL, pcutoff = 0.05, ...)
```

## Arguments

- x:

  A `MethQcSet` object.

- detection_pval:

  Optional matrix of detection p-values. If NULL, uses x@detection_pval.

- pcutoff:

  Detection p-value threshold (default 0.05): a sample passes when at
  least 95% of its probes are detected at p \< `pcutoff`. The per-probe
  recall rate uses the same threshold.

- ...:

  Additional arguments (reserved for future use).

## Value

A `MethQcSet` object with updated qc_tables and qc_params.

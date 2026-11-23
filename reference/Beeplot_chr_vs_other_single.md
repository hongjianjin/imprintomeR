# Generate Chromosome-vs-Others Beeswarm PDFs

For each chromosome in `chrs`, splits probes into target chromosome vs
others and delegates plotting to
[`Beeplot_chr_vs_other()`](https://hongjianjin.github.io/imprintomeR/reference/Beeplot_chr_vs_other.md).

## Usage

``` r
Beeplot_chr_vs_other_single(
  input,
  chrs = "chr1,chr11",
  prefix = NULL,
  probeset = "selected",
  genome = "hg38"
)
```

## Arguments

- input:

  List containing `beta` and `meta` elements.

- chrs:

  Comma-separated chromosome string (e.g. `"chr1,chr11"`).

- prefix:

  Output prefix used to build per-chromosome PDF names.

- probeset:

  Probeset name.

- genome:

  Genome build of the probeset annotation, "hg38" (default) or "hg19".

## Value

`NULL`, writing plots to files as side effects.

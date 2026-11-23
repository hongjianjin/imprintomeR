# Extract Probes Annotated to Genes

Returns the probes whose UCSC RefGene annotation names any of the given
genes.

## Usage

``` r
ExtractProbesByGenelist(
  genes = NULL,
  probes.all = NULL,
  assay = "EPICV1",
  version = "HG19",
  promoterOnly = FALSE,
  file = NULL
)
```

## Arguments

- genes:

  Character vector of gene symbols (required).

- probes.all:

  Optional annotation data frame (see
  [`AnnotateProbe2Gene()`](https://hongjianjin.github.io/imprintomeR/reference/AnnotateProbe2Gene.md));
  `NULL` (default) uses the bundled annotation.

- assay:

  Array type (not used for the lookup; kept for compatibility).

- version:

  Genome build of the coordinates, `"HG19"` (default) or `"HG38"`.

- promoterOnly:

  Logical; if `TRUE`, only probes annotated to a TSS200 region are
  returned.

- file:

  Optional path of a tab-separated file to write the result to.

## Value

Data frame with columns `NAME`, `CHR_<version>`, `MAPINFO_<version>`,
`UCSC_REFGENE_NAME` and `UCSC_REFGENE_GROUP`.

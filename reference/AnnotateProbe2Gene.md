# Annotate Probes with Genomic Position and Gene

Looks up probes in the bundled harmonized array annotation and returns
their position and UCSC RefGene annotation.

## Usage

``` r
AnnotateProbe2Gene(
  probeIDs,
  probes.all = NULL,
  assay = "EPICV1",
  version = "HG19",
  verbose = FALSE,
  file = NULL
)
```

## Arguments

- probeIDs:

  Character vector of probe IDs.

- probes.all:

  Optional annotation data frame with columns `NAME`, `CHR_<version>`,
  `MAPINFO_<version>`, `UCSC_REFGENE_NAME` and `UCSC_REFGENE_GROUP`;
  `NULL` (default) uses the bundled annotation.

- assay:

  Array type (not used for the lookup; kept for compatibility).

- version:

  Genome build of the coordinates, `"HG19"` (default) or `"HG38"`.

- verbose:

  Not used; kept for compatibility.

- file:

  Optional path of a tab-separated file to write the result to.

## Value

Data frame with columns `NAME`, `CHR_<version>`, `MAPINFO_<version>`,
`UCSC_REFGENE_NAME` and `UCSC_REFGENE_GROUP` for the probes found.

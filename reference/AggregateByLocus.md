# Aggregate Beta Matrix by Imprinting Locus

Aggregates probe-level beta values into locus-level medians. Probes are
grouped by chromosome, annotated parental origin and either their
nearest gene (`by = "gene"`) or their curated ICR (`by = "icr"`). Loci
are returned in genomic order: by chromosome (1-22, X, Y), then by the
position of the locus' first probe (`MAPINFO`); without `MAPINFO`, by
label within a chromosome.

## Usage

``` r
AggregateByLocus(
  beta,
  probeset = "selected",
  genome = "hg38",
  by = c("gene", "icr"),
  icr_only = FALSE
)
```

## Arguments

- beta:

  Numeric beta matrix/data frame with probe IDs as row names and samples
  in columns.

- probeset:

  Character probeset key present in the bundled probeset file for
  `genome` (`probesets_<genome>.rds`).

- genome:

  Genome build of the probeset panels, `"hg19"` or `"hg38"` (default
  `"hg38"`).

- by:

  How probes are grouped into loci:

  - `"gene"` (default): by nearest gene (`Closest_TSS_gene_name`); loci
    are labelled `chr_origin_gene`.

  - `"icr"`: by curated ICR (`ICR_name`), so each ICR forms one locus
    whatever the nearest-gene labels of its probes; probes outside
    curated ICRs are grouped by nearest gene. Loci are labelled
    `chr_origin_ICR` (for example `chr11_paternal_H19/IGF2:IG-DMR`).
    Panels without an `ICR_name` column are grouped by nearest gene,
    with a message.

- icr_only:

  With `by = "icr"`, keep only the curated ICRs and leave out probes
  outside them (default `FALSE`). Radar plots use `by = "icr"` with
  `icr_only = TRUE`, one spoke per curated ICR.

## Value

Data frame with aggregated loci as rows and samples as columns.

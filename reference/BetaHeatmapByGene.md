# Heatmap of Beta Values Aggregated by Gene Symbol

Aggregates probe-level beta values to gene-level means by
`Closest_TSS_gene_name` from the selected probeset, then generates a
heatmap visualization. Genes with the same symbol are aggregated via
median across probes.

## Usage

``` r
BetaHeatmapByGene(
  beta,
  meta = NULL,
  probeset = "selected",
  SAMPLEID = "Sample_Name",
  annoColumn = "Sample_Group",
  clusterRows = TRUE,
  clusterColumns = TRUE,
  outFile = NULL,
  imgSizeFactor = 0.5,
  genome = "hg38"
)
```

## Arguments

- beta:

  Numeric beta matrix/data.frame with probe IDs as row names and samples
  as columns.

- meta:

  Optional sample metadata data frame with `Sample_Name` and
  `Sample_Group` columns.

- probeset:

  Character probeset key (default `"selected"`). Must be present in the
  probeset annotation of `genome`.

- SAMPLEID:

  Metadata column name used as sample label in heatmap (default
  `"Sample_Name"`).

- annoColumn:

  Annotation column for heatmap top annotation (default
  `"Sample_Group"`).

- clusterRows:

  Logical; cluster genes (rows) hierarchically (default `TRUE`).

- clusterColumns:

  Logical; cluster samples (columns) hierarchically (default `TRUE`).

- outFile:

  Optional output PDF file path. If provided, heatmap is saved to disk.

- imgSizeFactor:

  Numeric scaling factor for saved image dimensions (default `0.5`).

- genome:

  Genome build of the probeset annotation, "hg38" (default) or "hg19".

## Value

Invisibly returns the
[`ComplexHeatmap::Heatmap`](https://rdrr.io/pkg/ComplexHeatmap/man/Heatmap.html)
object (or NULL if no output file and function exits silently).

## Details

**Aggregation Logic:** Probes are matched to the selected probeset by
`NAME`. Probes are grouped by their `Closest_TSS_gene_name` annotation.
Beta values within each gene are aggregated per sample using the median
function, producing one row per unique gene symbol.

**Colors & Annotations:** Uses a red-blue color palette spanning the
observed beta range. Sample groups are annotated at the top with
automatic color assignment via `standardColors()`.

**Clustering:** If `clusterRows = TRUE`, genes are clustered via
Euclidean distance and Ward linkage. If `clusterRows = FALSE`, genes are
sorted by their row names.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Load beta and metadata
  beta <- LoadBeta("beta.txt")
  meta <- LoadMeta("meta.txt")

  # Generate gene-level heatmap
  BetaHeatmapByGene(beta, meta, probeset = "selected",
    outFile = "gene_heatmap.pdf")
} # }
```

# Per-ICR Methylation Variance per Sample

Summarizes the probes of each imprinted region per sample: the median
beta and the variance of beta across the region's probes
(`ImpVar_Score`), a measure of within-region heterogeneity. Regions are
either the loci of a bundled probeset (probes grouped by chromosome,
parental origin and nearest gene) or the intervals of a BED file.

## Usage

``` r
Calculate_impvar(
  betaFile,
  metaFile = NULL,
  icr.bed = NULL,
  probeset = NULL,
  assay = c("450K", "EPICv1", "EPICv2"),
  genome = c("hg38", "hg19"),
  outFile = NULL
)
```

## Arguments

- betaFile:

  Beta matrix, data frame or file path (probes by samples).

- metaFile:

  Metadata data frame or file path with `Sample_Name`.

- icr.bed:

  Path of a BED file of regions, used when `probeset` is `NULL`.
  Requires the Bioconductor packages GenomicRanges and rtracklayer.

- probeset:

  Name of a bundled probeset whose loci define the regions.

- assay:

  Array type used to filter the annotation for `icr.bed`: `"450K"`,
  `"EPICv1"` or `"EPICv2"`.

- genome:

  Genome build, `"hg38"` (default) or `"hg19"`.

- outFile:

  Optional path of a tab-separated file to write the result to.

## Value

Data frame with one row per sample and region: `Sample_Name`,
`Sample_Group` and `ID2` when available, `icr_name`, `ImpVar_Score`
(`NA` for regions with one probe), `Median_Beta` and `CpG_Count`.

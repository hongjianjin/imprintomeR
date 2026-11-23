# Example data: GSE52576 beta values and metadata

Small example bundled with imprintomeR for trying the package without
downloading data: the beta values of the 782 probes of the `"selected"`
ICR panel for the 28 samples of GEO series GSE52576 (Court et al., 2014;
Illumina 450K), and their metadata. The samples include normal tissues,
androgenetic hydatidiform moles (paternal genome only), parthenogenetic
embryonic stem cells (maternal genome only) and leukocytes with
genome-wide paternal or maternal uniparental disomy.

## Usage

``` r
imprintome_example(which = c("beta", "meta"), path = FALSE)
```

## Arguments

- which:

  `"beta"` or `"meta"`.

- path:

  If `TRUE`, return the path of the tab-delimited file instead of its
  contents (for example to pass to `run_imprintomeR.R --beta` /
  `--meta`).

## Value

For `"beta"`, a numeric matrix with probes in rows (row names are probe
IDs) and samples in columns (GSM accessions); for `"meta"`, a
`data.frame` with `Sample_Name` (GSM accession), `Sample_Group` (GEO
source name), `title`, `health_state` and `gender`. With `path = TRUE`,
a file path.

## Details

The files were built from the GEO series matrix (beta values as
deposited) by `data-raw/GSE52576_example.R` in the package source.

## References

Court F, et al. Genome-wide parent-of-origin DNA methylation analysis
reveals the intricacies of human imprinting and suggests a germline
methylation-independent mechanism of establishment. Genome Res.
2014;24:554-569.

## Examples

``` r
beta <- imprintome_example("beta")
meta <- imprintome_example("meta")
dim(beta)
#> [1] 782  28
table(meta$Sample_Group)
#> 
#>                       Adult Brain                       Fetal Brain 
#>                                 1                                 1 
#>                 Hydatidiform mole                        Leukocytes 
#>                                 4                                 5 
#>                             Liver                            Muscle 
#>                                 1                                 1 
#>                          Pancreas                             Sperm 
#>                                 1                                 2 
#>         Term placenta- fetal side        human embryonic stem cells 
#>                                 4                                 4 
#> parthenogenetic activated oocytes 
#>                                 4 
imprintome_example("beta", path = TRUE)
#> [1] "/home/runner/work/_temp/Library/imprintomeR/extdata/GSE52576_selected_beta.tsv"
```

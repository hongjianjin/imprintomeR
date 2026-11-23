# Setup imprintomeR Data Files

Downloads required annotation data files for the imprintomeR package.
When files are missing, attaching the package prints a note pointing
here.

## Usage

``` r
setup_imprintome_data(force = FALSE, verbose = TRUE)
```

## Arguments

- force:

  Logical. If TRUE, re-download files even if they exist.

- verbose:

  Logical. If TRUE, print download progress.

## Value

Invisibly returns TRUE if successful, FALSE otherwise.

## Details

The imprintomeR package requires three annotation files:

- `anno.uniq_harmonized.liftover.rds` (~52 MB): CpG probe annotations
  with hg19 and hg38 coordinates

- `probesets_hg19.rds` (~110 KB): ICR probeset panels, GRCh37/hg19
  coordinates

- `probesets_hg38.rds` (~115 KB): ICR probeset panels, GRCh38/hg38
  coordinates

Missing files are downloaded from the `main` branch of the
hongjianjin/imprintomeR GitHub repository and cached in the installed
package's `extdata/` directory.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Download any missing files
  setup_imprintome_data()

  # Force re-download
  setup_imprintome_data(force = TRUE)
} # }
```

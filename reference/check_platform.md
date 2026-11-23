# Detect Array Platform from IDAT Files and Annotate Metadata

Reads IDAT files for each sample in `meta` and detects the Illumina
array platform by reading probe count from the raw channel data. Appends
`Platform`, `Array_Size`, `Manifest`, and `Status` columns to `meta`.

## Usage

``` r
check_platform(meta, max_retries = 5)
```

## Arguments

- meta:

  A `data.frame` with required column `Basename` (path prefix to IDAT
  files, e.g. `/path/to/idats/Sentrix_ID`). A `Sample_Name` column is
  used for messaging; if absent, row numbers are used.

- max_retries:

  Integer. Number of read attempts per sample before marking as
  `"Failed"`. Default: 5.

## Value

`meta` with four columns appended:

- Platform:

  Detected platform: `"EPIC"`, `"EPICv2"`, `"450K"`, `"27K"`, or `NA`

- Array_Size:

  Number of probes in the raw IDAT

- Manifest:

  Manifest string from array annotation (may be `NA`)

- Status:

  `"Success"` or `"Failed"`

## Details

Use this function before
[`runMethQC()`](https://hongjianjin.github.io/imprintomeR/reference/runMethQC.md)
when the platform is unknown or when you need to check whether a cohort
spans multiple array types.

Platform is inferred from array size using the same logic as
`meth_check_platform.R::CheckPlatform()`:

- `> 1,100,000` probes → `"EPICv2"`

- `> 1,000,000` probes → `"EPIC"`

- `> 400,000` probes → `"450K"`

- `> 20,000` probes → `"27K"`

If the annotation string disagrees with the array size, the array-size
inference is used and a warning is issued.

## Examples

``` r
if (FALSE) { # \dontrun{
meta <- read.table("meta.tsv", header = TRUE, sep = "\t")
meta_updated <- check_platform(meta)
table(meta_updated$Platform)

# Split by platform before running QC
meta_epic <- meta_updated[meta_updated$Platform == "EPIC", ]
qcset <- runMethQC(meta_epic)
} # }
```

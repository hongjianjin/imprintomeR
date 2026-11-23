# Circular Heatmap of Beta Values

Generates a circular/radial heatmap visualization of beta values using
ComplexHeatmap and circlize packages.

## Usage

``` r
BetaCircularHeatmap(
  beta,
  meta = NULL,
  probes.all = NULL,
  probeset = NULL,
  genome = "hg38",
  version = toupper(genome),
  SAMPLEID = "Sample_Name",
  sectionColumn = "Sample_Group",
  sectionLabels = NULL,
  outFile = NULL,
  nchars = 5,
  format = NULL,
  res = 300
)
```

## Arguments

- beta:

  Matrix or data.frame of beta values (rows = probes, columns =
  samples).

- meta:

  Optional data.frame of sample metadata with `SAMPLEID` column.

- probes.all:

  Optional probe annotation data.

- probeset:

  Character scalar for probeset name or NULL.

- genome:

  Genome build of the probeset coordinates, "hg38" (default) or "hg19".

- version:

  Coordinate columns used from `probes.all` (`CHR_<version>`,
  `MAPINFO_<version>`); defaults to the upper-case `genome`.

- SAMPLEID:

  Column name for sample identifiers (default "Sample_Name").

- sectionColumn:

  Column name for grouping samples into sections. Use "Sample_Name" to
  show each sample as its own section, or "Sample_Group" to group
  multiple samples. Circular heatmaps work best with 1-5 sections.

- sectionLabels:

  Optional custom section labels.

- outFile:

  Optional output file path. The extension selects the format when
  `format` is `NULL`: `.png` writes a raster image, anything else a
  vector PDF.

- nchars:

  Number of characters to show in gene labels (default 5). Note: This
  applies to gene names only, not group labels which are shown in full.

- format:

  Output format, `"pdf"` (vector) or `"png"` (raster), or `NULL`
  (default) to infer it from `outFile`. Raster output keeps file size
  independent of the numbers of probes and samples, which suits large
  cohorts.

- res:

  Resolution in dots per inch for raster output (default 300).

## Value

Invisibly returns the heatmap object.

## Details

**Crowding considerations:**

- Circular heatmaps are optimized for small numbers of samples (1-5 per
  section).

- For 5-10+ samples per section, consider using
  `plot_type = "heatmap_by_probe"` instead (rectangular heatmap) which
  handles many samples better.

- Each section represents a unique value in `sectionColumn`.

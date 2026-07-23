# Data Files for imprintomeR

This directory documents the package data resources in `inst/extdata/` and how to prepare them for release.

## Files

- **download_data.R** - helper notes and a small copy function for release assets.

## Current extdata Resources

The package uses these annotation and example files:

1. **anno.uniq_harmonized.liftover.rds**
   - Illumina 450K/EPIC probe annotation with hg19 coordinates.

2. **probesets_hg19.rds**
   - Curated hg19 probesets for array-based imprinting analysis.
   - Current sets: `Jima`, `Joshi`, `Court`, `Rosenski`, `selected`, `NanoImprint`, `chr11p15`, and `Rosenski_region`.
   - `selected` contains 606 cross-platform 450K/EPIC probes.
   - `Rosenski_region` contains 72 refined region-level iDMRs.

3. **probesets_hg38.rds**
   - hg38 probesets for region-level WGBS/ONT workflows.
   - Current set: `Rosenski_region`.

4. **Rosenski_refined_iDMRs_hg19.bed** and **Rosenski_refined_iDMRs_hg38.bed**
   - Refined Rosenski iDMR regions formatted for region-level methylation summaries.
   - Used by `parse_WGBS_to_region_beta.R`, `parse_ONT_bedMethyl.R`, and `LoadWGBSRegionBeta()`.

5. **Rosenski_iDMRs_mean_beta.hg19.tsv**
   - Small example region-level beta table compatible with `LoadWGBSRegionBeta()`.

## Setup

For installed packages, data files should be available through:

```r
system.file("extdata", "probesets_hg19.rds", package = "imprintomeR")
system.file("extdata", "probesets_hg38.rds", package = "imprintomeR")
```

If using the on-demand download workflow, run:

```r
library(imprintomeR)
setup_imprintome_data()
```

## Developer Notes

When preparing files for a GitHub release:

1. Confirm the shipped probesets and row counts:

   ```r
   p19 <- readRDS("inst/extdata/probesets_hg19.rds")
   p38 <- readRDS("inst/extdata/probesets_hg38.rds")
   data.frame(genome = "hg19", probeset = names(p19), rows = vapply(p19, nrow, integer(1)))
   data.frame(genome = "hg38", probeset = names(p38), rows = vapply(p38, nrow, integer(1)))
   ```

2. Run `prepare_data_for_release()` from `download_data.R`.
3. Upload the copied files as release assets.
4. If on-demand downloads are used, update the URLs in `R/zzz.R`.

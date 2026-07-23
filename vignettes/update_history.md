# imprintomeR Update History

This file summarizes major user-facing improvements by package version.

## Version 1.2.0

### Region-Level WGBS/ONT Workflow

- Added support for region-summarized WGBS and ONT methylation analysis.
- Added `LoadWGBSRegionBeta()` to load region beta tables with `chr`, `start`, `end`, and sample beta columns.
- Added hg19 and hg38 Rosenski refined iDMR region resources:
  - `inst/extdata/Rosenski_refined_iDMRs_hg19.bed`
  - `inst/extdata/Rosenski_refined_iDMRs_hg38.bed`
- Added region-level `Rosenski_region` (72 refined iDMRs) and `chr11p15_region` (8 chr11p15 iDMRs; OSBPL5 excluded) signatures for both hg19 and hg38 workflows.

### New Command-Line Support

- Updated `inst/scripts/run_imprintomeR.R` to support region-level sequencing input:
  - `-B`, `--WGBS-beta-file`
  - `--genome hg19|hg38`
  - `--probeset Rosenski_region` or `--probeset chr11p15_region`
- Added direct CLI workflow from region beta table plus metadata to `ImprintomeSet`, `runImprintome()`, visualizations, and export.

### New Region-Beta Parser Scripts

- Added `inst/scripts/parse_ONT_bedMethyl.R` for ONT/modkit bedMethyl files.
  - Supports `.bedmethyl` and `.bedmethyl.gz`.
  - Supports phased and non-phased files.
  - Aggregates `N_mod / N_valid_cov` over Rosenski hg38 regions.
- Added `inst/scripts/parse_WGBS_to_region_beta.R` for short-read WGBS methylation calls.
  - Supports `bismark_coverage`.
  - Supports `bismark_cytosine`.
  - Supports `wgbstools_beta2bed`.
  - Supports generic `bed_beta` input.

### Region-Safe Analysis and Visualization

- Updated analysis and plotting internals to support region-level rows in addition to Illumina probe IDs.
- For `probeset = "Rosenski_region"` or `probeset = "chr11p15_region"`, `runImprintomeVisualizations(..., plot_types = "default")` now uses the region-safe default set:
  - `polar`
  - `beeswarm_origin`
  - `heatmap_by_gene`
  - `radar`

### Documentation and Tests

- Added `vignettes/wgbs-region-workflow.Rmd`.
- Updated `README.md` with a WGBS Region-Based Workflow section.
- Updated `vignettes/imprintomeR_cli_README.md` with WGBS/ONT CLI examples.
- Documented that `Rosenski_refined_iDMRs_hg19.withCpG.bed` is a generated `wgbstools convert -L` intermediate, not a package extdata file.
- Added tests for `LoadWGBSRegionBeta()`, `chr11p15_region`, and Rosenski region visualization behavior.

## Version 1.1.0

### Core Package and Documentation Maturation

- Standardized package versioning and release notes around the main `imprintomeR` workflow.
- Added and refined package skill documentation under `skills/imprintomer/`.
- Improved README and vignette links for public workflows and command-line usage.

### Visualization and Export Improvements

- Improved `runImprintomeVisualizations()` behavior and plot export workflows.
- Removed `circular_heatmap` from the default visualization set; it is now requested explicitly when needed.
- Improved plot export behavior, including direct plot PDF saving without unnecessarily inflating saved `ImprintomeSet` RDS files.
- Improved radar plot PDF sizing defaults for better label readability.

### Probeset Resource Cleanup

- Reduced and curated packaged hg19 probesets to the supported set used by current workflows.
- Updated `inst/extdata/probesets_hg19.rds` after probeset shrinkage and cleanup.
- Updated data documentation to describe curated probeset resources.

### CLI and Workflow Improvements

- Published command-line scripts under `inst/scripts/`.
- Added `vignettes/imprintomeR_cli_README.md` for command-line QC and imprintomeR workflows.
- Improved `run_imprintomeR.R` caching logic so existing lean `ImprintomeSet` RDS files can be reused when they already contain the requested analysis result.
- Added direct plot-file generation without updating cached `ImprintomeSet` objects after visualization.

### MethQcSet and QC Workflow Improvements

- Standardized QC result naming around `Sample_Name`, while retaining backward-compatible input support for `SAMPLE_NAME`.
- Removed low-intensity failure from final required QC pass/fail criteria.
- Added and reorganized default QC plots, including intensity, detection p-value, beta density, and probe coverage outputs.
- Improved QC output directory organization with clearer `plots`, `QC_tables`, and `data` locations.

## Version 1.0.x

### Initial Stable Workflow

- Established the S4 container workflow with `MethQcSet` and `ImprintomeSet`.
- Added methylation-array QC workflow from IDAT files to QC-clean beta matrices.
- Added imprinting analysis with IDS, Angle, IDI, mechanism labels, and status classification.
- Added core visualization types including polar plots, radar plots, beeswarm plots, mirror density plots, rainfall plots, and heatmaps.
- Added export support for result tables, plots, and saved `ImprintomeSet` objects.
- Added public GEO example workflows and vignettes for reproducible analyses.

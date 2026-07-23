# Data file preparation and download guide
#
# This script documents how the data files used by imprintomeR are prepared
# and copied for release upload or manual setup.

# ============================================================================
# Required Data Files for imprintomeR
# ============================================================================
#
# 1. anno.uniq_harmonized.liftover.rds
#    - CpG probe annotations from Illumina EPIC/HM450K arrays
#    - Contains genomic coordinates (hg19 liftover)
#    - Source: Derived from minfi/IlluminaHumanMethylation packages
#
# 2. probesets_hg19.rds
#    - ICR probeset definitions for array and region-level workflows
#    - Contains: NAME, CHR, MAPINFO, ORIGIN, Closest_TSS_gene_name
#    - Current sets: Jima, Joshi, Court, Rosenski, selected,
#      NanoImprint, chr11p15, Rosenski_region
#    - Source: Custom curation from published imprinting literature
#
# 3. probesets_hg38.rds
#    - hg38 probeset definitions for region-level WGBS/ONT workflows
#    - Current set: Rosenski_region
#
# 4. Rosenski_refined_iDMRs_hg19.bed and Rosenski_refined_iDMRs_hg38.bed
#    - Refined Rosenski iDMR regions used for WGBS/ONT aggregation
#
# 5. Rosenski_iDMRs_mean_beta.hg19.tsv
#    - Small example region-level beta table for LoadWGBSRegionBeta()

# ============================================================================
# For Package Development: Prepare Files for GitHub Release
# ============================================================================
#
# Option A: Upload to GitHub Releases
# 1. Create a new release at https://github.com/hongjianjin/imprintomeR/releases
# 2. Upload these files as release assets:
#    - anno.uniq_harmonized.liftover.rds
#    - probesets_hg19.rds
#    - probesets_hg38.rds
#    - Rosenski_refined_iDMRs_hg19.bed
#    - Rosenski_refined_iDMRs_hg38.bed
#    - Rosenski_iDMRs_mean_beta.hg19.tsv
# 3. Update the download URLs in R/zzz.R setup_imprintome_data() if these
#    files should be downloaded on demand.
#
# Option B: Use Zenodo for permanent archival
# 1. Upload files to Zenodo.org
# 2. Get persistent DOI
# 3. Update download URLs in R/zzz.R
#
# Option C: Keep files in inst/extdata with Git LFS
# 1. Initialize Git LFS: git lfs install
# 2. Track files: git lfs track "inst/extdata/*.rds"
# 3. Commit normally: files will be managed by Git LFS

# ============================================================================
# For Package Users: Download Data Files
# ============================================================================
#
# Automatic:
#   After installing imprintomeR, run:
#   > imprintomeR::setup_imprintome_data()
#
# Manual:
#   1. Download files from GitHub Releases or package extdata
#   2. Place in inst/extdata if building locally
#   3. Or use setup_imprintome_data(force = TRUE) for supported downloads

# ============================================================================
# Example: Prepare Files for Release
# ============================================================================

prepare_data_for_release <- function(output_dir = "~/Desktop/imprintomeR_data") {
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  source_files <- c(
    "inst/extdata/anno.uniq_harmonized.liftover.rds",
    "inst/extdata/probesets_hg19.rds",
    "inst/extdata/probesets_hg38.rds",
    "inst/extdata/Rosenski_refined_iDMRs_hg19.bed",
    "inst/extdata/Rosenski_refined_iDMRs_hg38.bed",
    "inst/extdata/Rosenski_iDMRs_mean_beta.hg19.tsv"
  )

  for (src in source_files) {
    if (file.exists(src)) {
      file.copy(src, file.path(output_dir, basename(src)), overwrite = TRUE)
      cat("Prepared:", basename(src), "\n")
    } else {
      warning("Missing source file: ", src, call. = FALSE)
    }
  }

  cat("\nFiles ready for upload to GitHub Releases:\n")
  cat("- Location:", output_dir, "\n")
  cat("- Update download URLs in R/zzz.R after uploading, if needed\n")
}

# ============================================================================
# Information
# ============================================================================
#
# GitHub Release URL pattern:
# https://github.com/hongjianjin/imprintomeR/releases/download/vX.Y.Z/FILENAME
#
# For more info on managing large files with Git:
# https://git-lfs.com/
# https://docs.github.com/en/repositories/working-with-files/managing-large-files

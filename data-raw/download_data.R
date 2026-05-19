# Data file preparation and download guide
# 
# This script documents how the large data files are prepared and downloaded.
# Run this to prepare files for release or manual data setup.

# ============================================================================
# Required Data Files for imprintomeR
# ============================================================================
# 
# 1. anno.uniq_harmonized.liftover.rds (52 MB)
#    - CpG probe annotations from Illumina EPIC/HM450K arrays
#    - Contains genomic coordinates (hg19 liftover)
#    - Source: Derived from minfi/IlluminaHumanMethylation packages
#
# 2. probesets_hg19.rds (256 KB)
#    - ICR (Imprinted Gene Region) probeset definitions
#    - Contains: NAME, CHR, MAPINFO, ORIGIN (maternal/paternal), 
#               Closest_TSS_gene_name
#    - Source: Custom curation from published imprinting literature

# ============================================================================
# For Package Development: Prepare Files for GitHub Release
# ============================================================================
#
# Option A: Upload to GitHub Releases (recommended)
# 1. Create a new release at https://github.com/hongjianjin/imprintomeR/releases
# 2. Upload these files as release assets:
#    - anno.uniq_harmonized.liftover.rds
#    - probesets_hg19.rds
# 3. Update the download URLs in R/zzz.R setup_imprintome_data() function
#
# Option B: Use Zenodo for permanent archival
# 1. Upload files to Zenodo.org (free archival)
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
# Automatic (recommended):
#   After installing imprintomeR, run:
#   > imprintomeR::setup_imprintome_data()
#
# Manual:
#   1. Download files from GitHub Releases
#   2. Place in: ~/.imprintomeR/data/ (or inst/extdata if building locally)
#   3. Or use setup_imprintome_data(force = TRUE) to re-download

# ============================================================================
# Current Setup: Option 2 Implementation
# ============================================================================
#
# The imprintomeR package uses Option 2 (On-Demand Download):
# - .gitignore excludes *.rds files from git (lean repository)
# - R/zzz.R .onLoad() hook checks for missing files on startup
# - Users call setup_imprintome_data() to download if needed
# - Files cached in inst/extdata after first download

# Example: Prepare files for release
# ============================================================================

prepare_data_for_release <- function(output_dir = "~/Desktop/imprintomeR_data") {
  """
  Prepare data files for GitHub release upload.
  Files should be placed in GitHub Releases or external storage.
  """
  
  dir.create(output_dir, showWarnings = FALSE)
  
  # Copy required files
  source_files <- c(
    "inst/extdata/anno.uniq_harmonized.liftover.rds",
    "inst/extdata/probesets_hg19.rds"
  )
  
  for (src in source_files) {
    if (file.exists(src)) {
      file.copy(src, file.path(output_dir, basename(src)), overwrite = TRUE)
      cat("Prepared:", basename(src), "\n")
    }
  }
  
  cat("\nFiles ready for upload to GitHub Releases:\n")
  cat("- Location:", output_dir, "\n")
  cat("- Update download URLs in R/zzz.R after uploading\n")
}

# ============================================================================
# Information
# ============================================================================
#
# GitHub Release URL pattern:
# https://github.com/hongjianjin/imprintomeR/releases/download/v0.1.0/FILENAME
#
# For more info on managing large files with Git:
# https://git-lfs.com/
# https://docs.github.com/en/repositories/working-with-files/managing-large-files

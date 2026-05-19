# Package initialization and data setup

.onLoad <- function(libname, pkgname) {
  # Check for required data files
  required_files <- c(
    "anno.uniq_harmonized.liftover.rds",
    "probesets_hg19.rds"
  )

  extdata_dir <- system.file("extdata", package = pkgname)
  missing_files <- character(0)

  for (file in required_files) {
    file_path <- file.path(extdata_dir, file)
    if (!file.exists(file_path)) {
      missing_files <- c(missing_files, file)
    }
  }

  if (length(missing_files) > 0) {
    packageStartupMessage(
      "Note: Some data files are missing from inst/extdata.\n",
      "Run setup_imprintome_data() to download them, or see:\n",
      "?setup_imprintome_data for manual download instructions."
    )
  }
}

#' Setup imprintomeR Data Files
#'
#' Downloads required annotation data files for the imprintomeR package.
#' This is automatically called during package load if files are missing.
#'
#' @param force Logical. If TRUE, re-download files even if they exist.
#' @param verbose Logical. If TRUE, print download progress.
#'
#' @details
#' The imprintomeR package requires two large annotation files:
#' - `anno.uniq_harmonized.liftover.rds` (52 MB): CpG probe annotations and genomic coordinates
#' - `probesets_hg19.rds` (256 KB): ICR probeset definitions
#'
#' These files are stored externally and downloaded on demand to keep the
#' repository lean. They are cached in `inst/extdata/` after download.
#'
#' @return Invisibly returns TRUE if successful, FALSE otherwise.
#'
#' @examples
#' \dontrun{
#'   # Automatically called on package load if files are missing
#'   setup_imprintome_data()
#'
#'   # Force re-download
#'   setup_imprintome_data(force = TRUE)
#' }
#'
#' @export
setup_imprintome_data <- function(force = FALSE, verbose = TRUE) {
  extdata_dir <- system.file("extdata", package = "imprintomeR")

  # Data file URLs (placeholder - update with actual hosting location)
  data_urls <- list(
    anno.uniq_harmonized.liftover.rds = "https://github.com/hongjianjin/imprintomeR/releases/download/v0.1.0/anno.uniq_harmonized.liftover.rds",
    probesets_hg19.rds = "https://github.com/hongjianjin/imprintomeR/releases/download/v0.1.0/probesets_hg19.rds"
  )

  success <- TRUE

  for (fname in names(data_urls)) {
    fpath <- file.path(extdata_dir, fname)

    # Skip if file exists and force = FALSE
    if (file.exists(fpath) && !force) {
      if (verbose) cat("✓", fname, "already exists\n")
      next
    }

    if (verbose) cat("Downloading", fname, "...\n")

    tryCatch(
      {
        download.file(data_urls[[fname]], fpath, mode = "wb", quiet = !verbose)
        if (verbose) cat("✓", fname, "downloaded successfully\n")
      },
      error = function(e) {
        cat("✗ Error downloading", fname, ":", conditionMessage(e), "\n")
        cat("  Manual download:", data_urls[[fname]], "\n")
        success <<- FALSE
      }
    )
  }

  if (success && verbose) {
    cat("\n✓ All data files ready!\n")
  }

  invisible(success)
}

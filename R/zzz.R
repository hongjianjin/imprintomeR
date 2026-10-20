# Package initialization and data setup

.onLoad <- function(libname, pkgname) {
  # Check for required data files
  required_files <- c(
    "anno.uniq_harmonized.liftover.rds",
    "probesets_hg19.rds",
    "probesets_hg38.rds"
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
#' The imprintomeR package requires three annotation files:
#' - `anno.uniq_harmonized.liftover.rds` (~52 MB): CpG probe annotations with hg19 and hg38 coordinates
#' - `probesets_hg19.rds` (~110 KB): ICR probeset panels, GRCh37/hg19 coordinates
#' - `probesets_hg38.rds` (~115 KB): ICR probeset panels, GRCh38/hg38 coordinates
#'
#' Missing files are downloaded from the `main` branch of the
#' hongjianjin/imprintomeR GitHub repository and cached in the installed
#' package's `extdata/` directory.
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

  # Data files are served from the repository's main branch.
  base_url <- "https://raw.githubusercontent.com/hongjianjin/imprintomeR/main/inst/extdata/"
  data_files <- c("anno.uniq_harmonized.liftover.rds", "probesets_hg19.rds", "probesets_hg38.rds")
  data_urls <- as.list(stats::setNames(paste0(base_url, data_files), data_files))

  success <- TRUE

  # The annotation file is ~52 MB; allow more than R's default 60 s timeout.
  old_timeout <- getOption("timeout")
  options(timeout = max(600, old_timeout))
  on.exit(options(timeout = old_timeout), add = TRUE)

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
        # Download to a temporary file so an interrupted download never leaves
        # a partial file that a later call would treat as already present.
        tmp <- tempfile(fileext = ".rds")
        on.exit(unlink(tmp), add = TRUE)
        utils::download.file(data_urls[[fname]], tmp, mode = "wb", quiet = !verbose)
        if (!file.copy(tmp, fpath, overwrite = TRUE)) {
          stop("could not write ", fpath)
        }
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

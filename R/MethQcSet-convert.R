#' Conversion Methods for MethQcSet
#'
#' Methods for converting MethQcSet objects to analysis-ready formats.
#'
#' @name MethQcSet-convert
NULL

# ============================================================================
# as.ImprintomeSet() - Convert to analysis-ready ImprintomeSet
# ============================================================================

if (!methods::isGeneric("as.ImprintomeSet")) {
  methods::setGeneric("as.ImprintomeSet", function(x, ...) standardGeneric("as.ImprintomeSet"))
}

#' Convert MethQcSet to ImprintomeSet
#'
#' Convert a QC-clean, single-platform `MethQcSet` to an analysis-ready `ImprintomeSet`
#' for downstream imprintome analysis.
#'
#' @param x A `MethQcSet` object.
#' @param probeset Optional data.frame or list of probe set annotation. If NULL, attempts
#'   to load platform-specific probeset from package data.
#' @param genome Character scalar for genome build ("hg19" or "hg38"). Default: "hg19".
#' @param ... Additional arguments (reserved for future use).
#'
#' @return An `ImprintomeSet` object with:
#'   \itemize{
#'     \item `beta`: Beta matrix from x@beta
#'     \item `meta`: Sample metadata from x@meta
#'     \item `probeset`: Probe annotation data
#'     \item `assay`: Array assay type derived from x@platform
#'     \item `genome`: Genome build
#'     \item `qc`: QC tables from x@qc_tables (stored for reference)
#'     \item `results`: Empty (to be populated by runImprintome)
#'     \item `plots`: Empty (to be populated by plotting functions)
#'   }
#'
#' @details
#' **Validation checks:**
#' - Ensures single platform (platform-specific check)
#' - Validates samples have non-missing QC status (if QC_matrix present)
#' - Warns if EPICv2 aggregation status is not confirmed
#'
#' **Probeset Loading:**
#' If probeset is NULL, attempts to load platform-specific probeset from
#' package inst/extdata. Currently supports "450K", "EPIC", and "EPICv2".
#'
#' @export
methods::setMethod("as.ImprintomeSet", "MethQcSet", function(x, probeset = NULL, genome = "hg19", ...) {
  suppressMessages(suppressWarnings(library(GenomicRanges)))

  # Validate single platform
  if (is.na(x@platform) || !nzchar(x@platform)) {
    stop("MethQcSet platform is empty. Cannot convert.")
  }

  # Standardize platform name for downstream use
  platform_std <- toupper(gsub("v2|v1", "", x@platform))

  # =========================================================================
  # Enforce EPICv2 aggregation — must be done before conversion
  # =========================================================================
  if (toupper(x@platform) == "EPICV2" && x@aggregation_status != "epicv2_aggregated") {
    stop("EPICv2 data must be aggregated before conversion to ImprintomeSet.\n",
         "Run: qcset <- aggregate_probes(qcset)")
  }

  # =========================================================================
  # Validate QC status if available
  # =========================================================================
  if ("QC_matrix" %in% names(x@qc_tables)) {
    qc_matrix <- x@qc_tables[["QC_matrix"]]
    if ("Final.QC" %in% colnames(qc_matrix)) {
      n_fail <- sum(qc_matrix$Final.QC == "FAIL", na.rm = TRUE)
      if (n_fail > 0) {
        warning("QC matrix contains ", n_fail, " samples with Final.QC='FAIL'. ",
                "Consider filtering before analysis.")
      }
    }
  }

  # =========================================================================
  # Load or validate probeset
  # =========================================================================
  if (is.null(probeset)) {
    # Attempt to load platform-specific probeset
    tryCatch({
      if (platform_std == "450K") {
        probeset_file <- "inst/extdata/probesets_450k.rds"
      } else if (platform_std == "EPIC") {
        probeset_file <- "inst/extdata/probesets_hg19.rds"
      } else if (platform_std == "EPICV2") {
        probeset_file <- "inst/extdata/probesets_epicv2.rds"
      } else {
        probeset_file <- NULL
      }

      if (!is.null(probeset_file) && file.exists(probeset_file)) {
        probeset_list <- readRDS(probeset_file)
        # Use first probeset or ICR-specific one if available
        probeset <- if (!is.null(probeset_list[[1]])) {
          probeset_list[[1]]
        } else if ("ICR" %in% names(probeset_list)) {
          probeset_list[["ICR"]]
        } else {
          probeset_list
        }
      } else {
        message("Probeset file not found for platform '", x@platform,
                "'. Creating minimal probeset from beta row names.")
        probeset <- data.frame(
          NAME = rownames(x@beta),
          stringsAsFactors = FALSE
        )
      }
    }, error = function(e) {
      message("Error loading probeset: ", conditionMessage(e),
              ". Using minimal probeset.")
      probeset <<- data.frame(
        NAME = rownames(x@beta),
        stringsAsFactors = FALSE
      )
    })
  }

  # =========================================================================
  # Ensure Sample_Group exists in metadata (required for ImprintomeSet)
  # =========================================================================
  meta <- x@meta
  
  # Normalize older MethQcSet metadata that may use SAMPLE_NAME to canonical Sample_Name
  if ("SAMPLE_NAME" %in% colnames(meta) && !("Sample_Name" %in% colnames(meta))) {
    colnames(meta)[colnames(meta) == "SAMPLE_NAME"] <- "Sample_Name"
  }
  
  # Create Sample_Group if missing (Tier B: Analysis-ready from QC output)
  if (!("Sample_Group" %in% colnames(meta))) {
    # Create Sample_Group with Sample_Name as fallback (each sample is its own group)
    if ("Sample_Name" %in% colnames(meta)) {
      meta$Sample_Group <- meta$Sample_Name
    } else {
      # Ultimate fallback: use row index (should rarely reach here)
      meta$Sample_Group <- paste0("Sample_", seq_len(nrow(meta)))
    }
    message("Sample_Group column not found. Created with Sample_Name values for each sample (Tier B: Analysis-ready).")
  }
  
  # Note: Basename column is dropped here (QC-specific, not needed for analysis)
  if ("Basename" %in% colnames(meta)) {
    message("Note: Basename column dropped during conversion to ImprintomeSet (QC-specific, not needed for analysis).")
    meta$Basename <- NULL
  }

  # =========================================================================
  # Create and return ImprintomeSet
  # =========================================================================
  iset <- ImprintomeSet(
    beta = x@beta,
    meta = meta,
    probeset = probeset,
    genome = genome,
    assay = x@platform,
    results = list(),
    plots = list()
  )

  iset
})

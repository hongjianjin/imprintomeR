
# ============================================================================
# Define generic functions early
# ============================================================================

#' @export
methods::setGeneric("export", function(x, ...) standardGeneric("export"))

#' MethQcSet S4 Class
#'
#' Formal container for preprocessing/QC data within a single methylation array platform.
#'
#' The MethQcSet represents a cohort of samples from a single array platform (450K, EPIC, EPICv2, or mouse)
#' after preprocessing and QC. It holds metadata, beta values, detection p-values,
#' QC results tables, and platform/aggregation state information. This object precedes ImprintomeSet
#' in the analysis workflow and serves as the preprocessing/QC container.
#'
#' @slot meta data.frame of sample metadata. Must include `Sample_Name` column. Row order must match beta column order.
#' @slot platform Character scalar indicating platform ("450K", "EPIC", "EPICv2", "mouse").
#' @slot beta Matrix of beta values (rows = probes, columns = samples).
#' @slot detection_pval Matrix or NULL. Detection p-values, same dims/order as beta.
#' @slot qc_tables Named list of QC result data.frames. Canonical keys (populated by `runMethQC()`):
#'   `QC_matrix`, `ctrl_metrics`, `recall_rate`, `contamination`, `predUniqDonor_ID`,
#'   `cutoffs`, and optional `qc_report_files`.
#' @slot aggregation_status Character scalar: "none", "epicv2_aggregated", or other flag.
#' @slot qc_params Named list of QC parameters used (pcutoff, method, etc.).
#' @slot statistics data.frame or NULL. Per-group QC statistics (GROUP, Total, PASS, FAIL, PASS.RATIO, FAIL.RATIO).
#'   Populated on export when Sample_Group is present in metadata.
#'
#' @name MethQcSet-class
#' @exportClass MethQcSet
NULL

setClassUnion("MatrixOrNull", c("matrix", "NULL"))
setClassUnion("data.frameOrNULL", c("data.frame", "NULL"))

.normalize_methqc_sample_name <- function(meta) {
  if (is.data.frame(meta) &&
      "SAMPLE_NAME" %in% colnames(meta) &&
      !("Sample_Name" %in% colnames(meta))) {
    colnames(meta)[colnames(meta) == "SAMPLE_NAME"] <- "Sample_Name"
  }
  meta
}

.validate_MethQcSet <- function(object) {
  errors <- character()

  meta <- object@meta
  beta <- object@beta
  platform <- object@platform
  detection_pval <- object@detection_pval
  qc_tables <- object@qc_tables
  aggregation_status <- object@aggregation_status
  qc_params <- object@qc_params

  # Platform validation
  if (!is.character(platform) || length(platform) != 1L || is.na(platform) || !nzchar(platform)) {
    errors <- c(errors, "slot 'platform' must be a non-empty character scalar")
  }

  # Meta validation
  if (!is.data.frame(meta)) {
    errors <- c(errors, "slot 'meta' must be a data.frame")
  } else {
    if (nrow(meta) < 1L) {
      errors <- c(errors, "slot 'meta' must have at least 1 row")
    }
    if (!("Sample_Name" %in% colnames(meta))) {
      errors <- c(errors, "slot 'meta' must contain column 'Sample_Name'")
    } else {
      if (anyDuplicated(meta$Sample_Name)) {
        errors <- c(errors, "slot 'meta$Sample_Name' must be unique")
      }
    }
  }

  # Beta validation
  if (!is.matrix(beta)) {
    errors <- c(errors, "slot 'beta' must be a matrix")
  } else {
    if (is.null(dim(beta)) || length(dim(beta)) != 2L) {
      errors <- c(errors, "slot 'beta' must be 2-dimensional")
    } else {
      if (nrow(beta) < 1L || ncol(beta) < 1L) {
        errors <- c(errors, "slot 'beta' must have at least 1 row and 1 column")
      }
      if (is.null(colnames(beta))) {
        errors <- c(errors, "slot 'beta' must have sample column names")
      } else if (is.null(rownames(beta))) {
        errors <- c(errors, "slot 'beta' must have probe row names (TargetID)")
      }
    }

    # Check meta and beta alignment
    if (!is.null(colnames(beta)) && "Sample_Name" %in% colnames(meta)) {
      common_samples <- intersect(colnames(beta), as.character(meta$Sample_Name))
      if (length(common_samples) == 0L) {
        errors <- c(errors, "no overlapping samples between colnames(beta) and meta$Sample_Name")
      }
      if (length(common_samples) != ncol(beta)) {
        errors <- c(errors, "not all beta samples found in meta$Sample_Name")
      }
    }
  }

  # Detection p-value validation (optional)
  if (!is.null(detection_pval)) {
    if (!is.matrix(detection_pval)) {
      errors <- c(errors, "slot 'detection_pval' must be a matrix or NULL")
    } else {
      if (!identical(dim(detection_pval), dim(beta))) {
        errors <- c(errors, "slot 'detection_pval' must have same dimensions as beta")
      }
      if (!identical(rownames(detection_pval), rownames(beta))) {
        errors <- c(errors, "rownames of detection_pval must match rownames of beta")
      }
      if (!identical(colnames(detection_pval), colnames(beta))) {
        errors <- c(errors, "colnames of detection_pval must match colnames of beta")
      }
    }
  }

  # QC tables validation
  if (!is.list(qc_tables)) {
    errors <- c(errors, "slot 'qc_tables' must be a list")
  } else if (length(qc_tables) > 0L) {
    if (is.null(names(qc_tables))) {
      errors <- c(errors, "slot 'qc_tables' must be a named list")
    }
    # Each element should be a data.frame
    for (i in seq_along(qc_tables)) {
      if (!is.data.frame(qc_tables[[i]])) {
        errors <- c(errors, paste("qc_tables[[", i, "]] must be a data.frame"))
      }
    }
  }

  # Aggregation status validation
  if (!is.character(aggregation_status) || length(aggregation_status) != 1L) {
    errors <- c(errors, "slot 'aggregation_status' must be a character scalar")
  }

  # QC params validation
  if (!is.list(qc_params)) {
    errors <- c(errors, "slot 'qc_params' must be a list")
  }

  # Statistics validation (optional)
  statistics <- object@statistics
  if (!is.null(statistics)) {
    if (!is.data.frame(statistics)) {
      errors <- c(errors, "slot 'statistics' must be a data.frame or NULL")
    } else if (nrow(statistics) > 0L) {
      if (!all(c("GROUP", "Total", "PASS", "FAIL", "PASS.RATIO", "FAIL.RATIO") %in% colnames(statistics))) {
        errors <- c(errors, "slot 'statistics' must contain columns: GROUP, Total, PASS, FAIL, PASS.RATIO, FAIL.RATIO")
      }
    }
  }

  if (length(errors)) errors else TRUE
}

setClass(
  "MethQcSet",
  slots = c(
    meta = "data.frame",
    platform = "character",
    beta = "matrix",
    detection_pval = "MatrixOrNull",
    qc_tables = "list",
    aggregation_status = "character",
    qc_params = "list",
    statistics = "data.frameOrNULL"
  ),
  prototype = list(
    detection_pval = NULL,
    qc_tables = list(),
    aggregation_status = "none",
    qc_params = list(),
    statistics = NULL
  ),
  validity = .validate_MethQcSet
)

#' Construct a MethQcSet Object
#'
#' Create a preprocessing/QC container for a single-platform methylation array cohort.
#'
#' @param meta data.frame containing sample metadata with `Sample_Name` column.
#' @param platform Character scalar for platform identifier ("450K", "EPIC", "EPICv2", "mouse").
#' @param beta Matrix of beta values (rows = probes, columns = samples).
#' @param detection_pval Optional matrix of detection p-values, same dims as beta.
#' @param qc_tables Optional named list of QC result data.frames.
#' @param aggregation_status Character scalar indicating aggregation state (default: "none").
#' @param qc_params Optional named list of QC parameters used.
#'
#' @return An object of class `MethQcSet`.
#' @export
MethQcSet <- function(meta,
                      platform,
                      beta,
                      detection_pval = NULL,
                      qc_tables = list(),
                      aggregation_status = "none",
                      qc_params = list()) {
  meta <- .normalize_methqc_sample_name(meta)
  methods::new(
    "MethQcSet",
    meta = meta,
    platform = platform,
    beta = beta,
    detection_pval = detection_pval,
    qc_tables = qc_tables,
    aggregation_status = aggregation_status,
    qc_params = qc_params
  )
}


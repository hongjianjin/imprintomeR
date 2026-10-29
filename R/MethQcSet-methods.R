#' QC Computation and Aggregation Methods for MethQcSet
#'
#' Methods for computing QC metrics and handling platform-specific probe aggregation.
#'
#' @name MethQcSet-methods
NULL

# ============================================================================
# computeQC() - Internal: compute QC metrics and store in qc_tables
# (Public user-facing factory is runMethQC() in MethQcSet-io.R)
# ============================================================================

if (!methods::isGeneric("computeQC")) {
  methods::setGeneric("computeQC", function(x, ...) standardGeneric("computeQC"))
}

#' Compute QC Metrics on a MethQcSet
#'
#' Internal method. Compute QC metrics from beta values and detection p-values,
#' storing results in qc_tables. Called internally by `runMethQC()`.
#'
#' @param x A `MethQcSet` object.
#' @param detection_pval Optional matrix of detection p-values. If NULL, uses x@detection_pval.
#' @param pcutoff Detection p-value threshold (default 0.05): a sample passes when at least 95% of its
#'   probes are detected at p < `pcutoff`. The per-probe recall rate uses the same threshold.
#' @param ... Additional arguments (reserved for future use).
#'
#' @return A `MethQcSet` object with updated qc_tables and qc_params.
#'
#' @keywords internal
methods::setMethod("computeQC", "MethQcSet", function(x, detection_pval = NULL,
                                                     pcutoff = 0.05, ...) {

  # Use provided or stored matrices
  if (is.null(detection_pval)) {
    detection_pval <- x@detection_pval
  }

  # Check we have detection p-values
  if (is.null(detection_pval)) {
    stop("detection_pval matrix required. Provide via argument or x@detection_pval.")
  }

  # Ensure numeric matrix
  dP <- .qc_as_numeric_matrix(detection_pval, "detection_pval")
  if (is.null(dP)) {
    stop("Failed to convert detection_pval to numeric matrix.")
  }

  # Replace NAs with 1 (non-detected)
  dP[is.na(dP)] <- 1

  if (!is.numeric(pcutoff) || length(pcutoff) != 1L || is.na(pcutoff) || pcutoff <= 0 || pcutoff >= 1) {
    stop("pcutoff must be a single number between 0 and 1.")
  }

  # Compute detection p-value statistics per sample
  aveDetPval <- colMeans(dP, na.rm = TRUE)
  DetPval0.01 <- colSums(dP < 0.01, na.rm = TRUE)
  DetPval0.05 <- colSums(dP < 0.05, na.rm = TRUE)
  pctDetected.01 <- round(DetPval0.01 / nrow(dP) * 100, 2)
  pctDetected.05 <- round(DetPval0.05 / nrow(dP) * 100, 2)

  # Create base QC matrix
  qc_matrix <- data.frame(
    Sample_Name = colnames(x@beta),
    aveDetectionPval = aveDetPval,
    DetPval.0.01 = DetPval0.01,
    DetPval.0.05 = DetPval0.05,
    pctDetectedCpG_dP0.01 = pctDetected.01,
    pctDetectedCpG_dP0.05 = pctDetected.05,
    stringsAsFactors = FALSE
  )

  # Final.QC: PASS when at least 95% of probes are detected at p < pcutoff. The 0.01 and 0.05 columns are
  # always reported; another pcutoff adds its own column.
  pct_col <- paste0("pctDetectedCpG_dP", format(pcutoff, trim = TRUE, scientific = FALSE))
  if (!pct_col %in% colnames(qc_matrix)) {
    qc_matrix[[pct_col]] <- round(colSums(dP < pcutoff, na.rm = TRUE) / nrow(dP) * 100, 2)
  }
  qc_matrix$Final.QC <- ifelse(qc_matrix[[pct_col]] >= 95, "PASS", "FAIL")

  # Per-probe recall rate (% of samples detecting each CpG at p < pcutoff)
  pass_idx <- qc_matrix$Final.QC == "PASS"
  fail_idx <- qc_matrix$Final.QC == "FAIL"
  n_all  <- ncol(dP)
  n_pass <- sum(pass_idx)
  n_fail <- sum(fail_idx)

  recall_rate <- data.frame(
    CpG = rownames(dP),
    pct_detected_all = round(rowSums(dP < pcutoff, na.rm = TRUE) / n_all * 100, 2),
    stringsAsFactors = FALSE
  )
  if (n_pass > 0) {
    recall_rate$pct_detected_pass <- round(
      rowSums(dP[, pass_idx, drop = FALSE] < pcutoff, na.rm = TRUE) / n_pass * 100, 2)
  } else {
    recall_rate$pct_detected_pass <- NA_real_
  }
  if (n_fail > 0) {
    recall_rate$pct_detected_fail <- round(
      rowSums(dP[, fail_idx, drop = FALSE] < pcutoff, na.rm = TRUE) / n_fail * 100, 2)
  } else {
    recall_rate$pct_detected_fail <- NA_real_
  }

  # Cutoffs table: detection/probe coverage required; intensity reported only; control metrics optional
  # Structured to match legacy meth_QC.R for compatibility
  cutoffs <- data.frame(
    criteria = c(
      "log2MedianIntensity", "aveDetectionPval", pct_col,
      "snps_outliers_aveLogOdds",
      "Restoration", "Staining_Green", "Staining_Red",
      "Extension_Green", "Extension_Red", "Hybridization_High/Medium", "Hybridization_Medium/Low",
      "Target_Removal_1", "Target_Removal_2",
      "Bisulfite_Conversion_I_Green", "Bisulfite_Conversion_I_Red", "Bisulfite_Conversion_II",
      "Specificity_I_Green", "Specificity_I_Red", "Specificity_II",
      "Non-polymorphic_Green", "Non-polymorphic_Red",
      "CtrlMetrics.QC"
    ),
    cutoff   = c(
      "reported", "reported", ">=95",
      ">-4",
      ">0", ">5", ">5", ">5", ">5", ">1", ">1",
      ">1", ">1",
      ">1", ">1", ">1", ">1", ">1", ">1",
      ">5", ">5",
      "PASS"
    ),
    Pass = c(
      "reported", "NA", ">=95",
      "NA",
      ">0", ">5", ">5", ">5", ">5", ">1", ">1",
      ">1", ">1",
      ">1", ">1", ">1", ">1", ">1", ">1",
      ">5", ">5",
      "PASS"
    ),
    Fail = c(
      "reported", "NA", "<95",
      "NA",
      "<=0", "<=5", "<=5", "<=5", "<=5", "<=1", "<=1",
      "<=1", "<=1",
      "<=1", "<=1", "<=1", "<=1", "<=1", "<=1",
      "<=5", "<=5",
      "FAIL"
    ),
    Final.QC = c(
      NA, NA, "required",
      NA,
      NA, NA, NA, NA, NA, NA, NA, NA, NA,
      "required", "required", NA, NA, NA, NA, NA, NA,
      "required"
    ),
    CtrlMetrics.QC = c(
      NA, NA, NA,
      NA,
      NA, NA, NA, NA, NA, NA, NA, NA, NA,
      "required", "required", NA, NA, NA, NA, NA, NA,
      "required"
    ),
    stringsAsFactors = FALSE
  )

  # Store in qc_tables (canonical key names matching meth_QC.R)
  new_qc_tables <- x@qc_tables
  new_qc_tables[["QC_matrix"]]  <- qc_matrix
  new_qc_tables[["recall_rate"]] <- recall_rate
  new_qc_tables[["cutoffs"]]    <- cutoffs

  # Remove legacy key if present
  new_qc_tables[["qc_matrix"]] <- NULL
  new_qc_tables[["detection_recall_rate"]] <- NULL

  # Store QC parameters, keeping preprocessing entries (e.g. normalization) set by runMethQC()
  new_qc_params <- utils::modifyList(x@qc_params, list(
    pcutoff = pcutoff,
    method  = "detection_pval_statistics"
  ))

  # Update and return
  x@qc_tables <- new_qc_tables
  x@qc_params <- new_qc_params

  methods::validObject(x)
  x
})

# ============================================================================
# aggregate_probes() - Handle EPICv2 probe aggregation
# ============================================================================

if (!methods::isGeneric("aggregate_probes")) {
  methods::setGeneric("aggregate_probes", function(x, ...) standardGeneric("aggregate_probes"))
}

#' Aggregate Platform-Specific Probes
#'
#' Apply platform-specific probe aggregation. Currently supports EPICv2 aggregation
#' (multiple measurements per base CpG to single representative value).
#'
#' @param x A `MethQcSet` object.
#' @param method Character, aggregation method ("median" or "mean"). Default: "median".
#' @param ... Additional arguments (reserved for future use).
#'
#' @return A `MethQcSet` object with:
#'   \itemize{
#'     \item Updated `beta` slot (aggregated if platform=="EPICv2", unchanged otherwise)
#'     \item Updated `detection_pval` slot (if present)
#'     \item Updated `aggregation_status` slot
#'     \item An aggregation report in `qc_tables(x)$Aggregation_report`
#'   }
#'   If platform is not "EPICv2", returns object unchanged with message.
#'
#' @details
#' For EPICv2 data, this method calls `aggregate_beta_epicv2()` to consolidate
#' multiple probe measurements (e.g., cg06373096_TC11, cg06373096_TC12) into a single
#' value per base probe ID (cg06373096). This is essential before merging EPICv2 data
#' with EPICv1 or 450K cohorts.
#'
#' The aggregation report (columns `metric`, `n`, `description`) counts the replicate
#' groups collapsed, identifiers kept unchanged, malformed identifiers (kept or removed)
#' and values missing because all replicates were missing; see `aggregate_beta_epicv2()`.
#' A one-line summary is also printed as a message.
#'
#' @aliases aggregate_probes
#' @export
methods::setMethod("aggregate_probes", "MethQcSet", function(x, method = c("median", "mean"), ...) {
  method <- match.arg(method)

  # Check if aggregation is needed
  if (tolower(x@platform) != "epicv2") {
    message("Platform is '", x@platform, "', not EPICv2. Returning unchanged.")
    return(x)
  }

  # Check if already aggregated
  if (x@aggregation_status == "epicv2_aggregated") {
    message("Already marked as aggregated. Returning unchanged.")
    return(x)
  }

  # Prepare beta data.frame for aggregation
  beta_df <- as.data.frame(x@beta)
  beta_df$TargetID <- rownames(x@beta)
  beta_df <- beta_df[, c("TargetID", setdiff(colnames(beta_df), "TargetID"))]

  # Aggregate beta values
  beta_agg <- aggregate_beta_epicv2(beta_df, method = method)

  # Aggregate detection p-values if present
  if (!is.null(x@detection_pval)) {
    dpval_df <- as.data.frame(x@detection_pval)
    dpval_df$TargetID <- rownames(x@detection_pval)
    dpval_df <- dpval_df[, c("TargetID", setdiff(colnames(dpval_df), "TargetID"))]

    dpval_agg <- aggregate_beta_epicv2(dpval_df, method = method)

    # Convert aggregated p-values back to matrix
    rownames(dpval_agg) <- dpval_agg$TargetID
    dpval_agg$TargetID <- NULL
    x@detection_pval <- as.matrix(dpval_agg)
  }

  # Record the identifier counts before the attribute is lost in the matrix conversion.
  report <- attr(beta_agg, "aggregation_report")
  x@qc_tables[["Aggregation_report"]] <- report
  r <- stats::setNames(report$n, report$metric)
  message(sprintf(paste0("aggregate_probes(): %d rows -> %d probes; %d replicate groups collapsed (%d rows), ",
                         "%d unchanged, %d malformed kept, %d malformed removed, %d all-missing values."),
                  r[["input_rows"]], r[["output_ids"]], r[["replicate_groups_collapsed"]],
                  r[["replicate_rows_collapsed"]], r[["unchanged_ids"]], r[["malformed_kept"]],
                  r[["malformed_dropped"]], r[["all_missing_cells"]]))

  # Convert aggregated beta back to matrix
  rownames(beta_agg) <- beta_agg$TargetID
  beta_agg$TargetID <- NULL
  x@beta <- as.matrix(beta_agg)

  # Update aggregation status
  x@aggregation_status <- "epicv2_aggregated"

  methods::validObject(x)
  x
})

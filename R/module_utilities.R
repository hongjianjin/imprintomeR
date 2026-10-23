# Auto-refactored from utilities2.R
# Module: utilities

##################################################################
# QC Cutoff Definitions for Conditional Formatting in Excel Export
##################################################################

#' QC Final Cutoffs for Conditional Formatting
#'
#' Data frame defining pass/fail expressions for QC_matrix sheet.
#' Used by SaveTableStyle() to apply conditional formatting (colors) to Excel output.
#'
#' @format A data frame with columns:
#'   - `Control`: Column name in QC_matrix (e.g., "pctDetectedCpG_dP0.05")
#'   - `Threshold`: Threshold value (used for warning highlighting on "Final.QC" fields)
#'   - `Pass`: Expression for pass condition (e.g., ">95")
#'   - `Fail`: Expression for fail condition (e.g., "<=95")
#'
#' @details
#' Pass expressions are formatted as R expressions (e.g., ">95", ">=11").
#' Fail expressions should be the logical inverse of Pass.
#'
#' @export
QC_final_Cutoffs <- read.table(text = "
Control Threshold Pass Fail
pctDetectedCpG_dP0.05 95 >95 <=95
Final.QC WARN PASS FAIL
", header = T, row.names = NULL, stringsAsFactors = F)

#' Control Metrics Cutoffs for Conditional Formatting
#'
#' Data frame defining pass/fail expressions for ctrl_metrics sheet.
#' Used by SaveTableStyle() to apply conditional formatting (colors) to Excel output.
#'
#' @format A data frame with columns:
#'   - `Control`: Column name in ctrl_metrics (e.g., "Bisulfite_Conversion_I_Green")
#'   - `Threshold`: Threshold value (used for warning highlighting)
#'   - `Pass`: Expression for pass condition (e.g., ">1")
#'   - `Fail`: Expression for fail condition (e.g., "<=1")
#'
#' @details
#' Rows cover Bisulfite Conversion, Specificity, Non-polymorphic controls, and overall QC status.
#' Most control metrics use >1 threshold for PASS, <=1 for FAIL.
#'
#' @export
ctrlMatCutoffs <- read.table(text = "
Control Threshold Pass Fail
Restoration 0 >0    <=0
Staining_Green 5 >5 <=5
Staining_Red 5 >5   <=5
Extension_Green 5   >5 <=5
Extension_Red 5 >5 <=5
Hybridization_High/Medium 1 >1 <=1
Hybridization_Medium/Low 1 >1 <=1
Target_Removal_1 1  >1 <=1
Target_Removal_2 1 >1 <=1
Bisulfite_Conversion_I_Green 1 >1 <=1
Bisulfite_Conversion_I_Red 1 >1 <=1
Bisulfite_Conversion_II 1 >1 <=1
Specificity_I_Green 1 >1 <=1
Specificity_I_Red 1 >1 <=1
Specificity_II 1 >1 <=1
Non-polymorphic_Green 5 >5 <=5
Non-polymorphic_Red 5 >5 <=5
CtrlMetrics.QC WARN PASS FAIL
", header = T, row.names = NULL, stringsAsFactors = F)

##################################################################

standardColors <- function() {
  colors <- c(
    "turquoise", "blue", "brown", "green", "red", "black", "pink", "magenta", "purple", "greenyellow", "tan", "salmon", "cyan", "midnightblue", "lightcyan",
    "grey60", "lightgreen", "lightyellow", "royalblue", "darkred", "darkgreen", "darkturquoise", "darkgrey", "orange", "darkorange", "white", "skyblue",
    "saddlebrown", "steelblue", "paleturquoise", "violet", "darkolivegreen", "darkmagenta", "sienna3", "yellowgreen", "skyblue3", "plum1", "orangered4", "mediumpurple3",
    "lightsteelblue1", "lightcyan1", "ivory", "floralwhite", "darkorange2", "brown4", "bisque4", "darkslateblue", "plum2", "thistle2", "thistle1", "salmon4",
    "palevioletred3", "navajowhite2", "maroon", "lightpink4", "lavenderblush3", "honeydew1", "darkseagreen4", "coral1", "antiquewhite4", "coral2", "mediumorchid", "skyblue2",
    "yellow4", "skyblue1", "plum", "orangered3", "mediumpurple2", "lightsteelblue", "lightcoral", "indianred4", "firebrick4", "darkolivegreen4", "brown2", "blue2",
    "darkviolet", "plum3", "thistle3", "thistle", "salmon2", "palevioletred2", "navajowhite1", "magenta4", "lightpink3", "lavenderblush2", "honeydew", "darkseagreen3",
    "coral", "antiquewhite2", "coral3", "mediumpurple4", "skyblue4", "yellow3", "sienna4", "pink4", "orangered1", "mediumpurple1", "lightslateblue", "lightblue4",
    "indianred3", "firebrick3", "darkolivegreen2", "blueviolet", "blue4", "deeppink", "plum4", "thistle4", "tan4", "salmon1", "palevioletred1", "navajowhite",
    "magenta3", "lightpink2", "lavenderblush1", "green4", "darkseagreen2", "chocolate4", "antiquewhite1", "coral4", "mistyrose", "slateblue", "yellow2", "sienna2",
    "pink3", "orangered", "mediumpurple", "lightskyblue4", "lightblue3", "indianred2", "firebrick2", "darkolivegreen1", "blue3", "brown1", "deeppink1", "powderblue",
    "tomato", "tan3", "royalblue3", "palevioletred", "moccasin", "magenta2", "lightpink1", "lavenderblush", "green3", "darkseagreen1", "chocolate3", "aliceblue",
    "cornflowerblue", "navajowhite3", "slateblue1", "whitesmoke", "sienna1", "pink2", "orange4", "mediumorchid4", "lightskyblue3", "lightblue2", "indianred1", "firebrick",
    "darkgoldenrod4", "blue1", "brown3", "deeppink2", "purple2", "tomato2", "tan2", "royalblue2", "paleturquoise4", "mistyrose4", "magenta1", "lightpink",
    "lavender", "green2", "darkseagreen", "chocolate2", "antiquewhite", "cornsilk", "navajowhite4", "slateblue2", "wheat3", "sienna", "pink1", "orange3",
    "mediumorchid3", "lightskyblue2", "lightblue1", "indianred", "dodgerblue4", "darkgoldenrod3", "blanchedalmond", "burlywood", "deepskyblue", "red1", "tomato4", "tan1",
    "rosybrown4", "paleturquoise3", "mistyrose3", "linen", "lightgoldenrodyellow", "khaki4", "green1", "darksalmon", "chocolate1", "antiquewhite3", "cornsilk2", "oldlace",
    "slateblue3", "wheat1", "seashell4", "peru", "orange2", "mediumorchid2", "lightskyblue1", "lightblue", "hotpink4", "dodgerblue3", "darkgoldenrod1", "bisque3",
    "burlywood1", "deepskyblue4", "red4", "turquoise2", "steelblue4", "rosybrown3", "paleturquoise1", "mistyrose2", "limegreen", "lightgoldenrod4", "khaki3", "goldenrod4",
    "darkorchid4", "chocolate", "aquamarine", "cyan1", "orange1", "slateblue4", "violetred4", "seashell3", "peachpuff4", "olivedrab4", "mediumorchid1", "lightskyblue",
    "lemonchiffon4", "hotpink3", "dodgerblue1", "darkgoldenrod", "bisque2", "burlywood2", "dodgerblue2", "rosybrown2", "turquoise4", "steelblue3", "rosybrown1", "palegreen4",
    "mistyrose1", "lightyellow4", "lightgoldenrod3", "khaki2", "goldenrod3", "darkorchid3", "chartreuse4", "aquamarine1", "cyan4", "orangered2", "snow", "violetred2",
    "seashell2", "peachpuff3", "olivedrab3", "mediumblue", "lightseagreen", "lemonchiffon3", "hotpink2", "dodgerblue", "darkblue", "bisque1", "burlywood3", "firebrick1",
    "royalblue1", "violetred1", "steelblue1", "rosybrown", "palegreen3", "mintcream", "lightyellow3", "lightgoldenrod2", "khaki1", "goldenrod2", "darkorchid2", "chartreuse3",
    "aquamarine2", "darkcyan", "orchid", "snow2", "violetred", "seashell1", "peachpuff2", "olivedrab2", "mediumaquamarine", "lightsalmon4", "lemonchiffon2", "hotpink1",
    "deepskyblue3", "cyan3", "bisque", "burlywood4", "forestgreen", "royalblue4", "violetred3", "springgreen3", "red3", "palegreen1", "mediumvioletred", "lightyellow2",
    "lightgoldenrod1", "khaki", "goldenrod1", "darkorchid1", "chartreuse2", "aquamarine3", "darkgoldenrod2", "orchid1", "snow4", "turquoise3", "seashell", "peachpuff1",
    "olivedrab1", "maroon4", "lightsalmon3", "lemonchiffon1", "hotpink", "deepskyblue2", "cyan2", "beige", "cadetblue", "gainsboro", "salmon3", "wheat",
    "springgreen2", "red2", "palegreen", "mediumturquoise", "lightyellow1", "lightgoldenrod", "ivory4", "goldenrod", "darkorchid", "chartreuse1", "aquamarine4", "darkkhaki",
    "orchid3", "springgreen1", "turquoise1", "seagreen4", "peachpuff", "olivedrab", "maroon3", "lightsalmon2", "lemonchiffon", "honeydew4", "deepskyblue1", "cornsilk4",
    "azure4", "cadetblue1", "ghostwhite", "sandybrown", "wheat2", "springgreen", "purple4", "palegoldenrod", "mediumspringgreen", "lightsteelblue4", "lightcyan4", "ivory3",
    "gold3", "darkorange4", "chartreuse", "azure", "darkolivegreen3", "palegreen2", "springgreen4", "tomato3", "seagreen3", "papayawhip", "navyblue", "maroon2",
    "lightsalmon1", "lawngreen", "honeydew3", "deeppink4", "cornsilk3", "azure3", "cadetblue2", "gold", "seagreen", "wheat4", "snow3", "purple3",
    "orchid4", "mediumslateblue", "lightsteelblue3", "lightcyan3", "ivory2", "gold2", "darkorange3", "cadetblue4", "azure1", "darkorange1", "paleturquoise2", "steelblue2",
    "tomato1", "seagreen2", "palevioletred4", "navy", "maroon1", "lightsalmon", "lavenderblush4", "honeydew2", "deeppink3", "cornsilk1", "azure2", "cadetblue3",
    "gold4", "seagreen1", "yellow1", "snow1", "purple1", "orchid2", "mediumseagreen", "lightsteelblue2", "lightcyan2", "ivory1", "gold1", "yellow"
  )
  return(colors)
}

##################################################################
# Metadata validation helper for three-tier system (Tier A/B/C)

#' Validate Metadata Against Tier Requirements
#'
#' Checks if metadata data.frame conforms to specified tier requirements:
#' - **Tier A:** Sample_Name + Sample_Group + Basename (QC-ready for runMethQC)
#' - **Tier B:** Sample_Name + Sample_Group (analysis-ready for ImprintomeSet)
#' - **Tier C:** Sample_Name only (minimal; allows auto_group=TRUE)
#'
#' @param meta data.frame containing sample metadata
#' @param tier Character scalar: one of "A", "B", or "C" (default: "B")
#' @param verbose Logical. If TRUE, print detailed validation messages (default: TRUE)
#'
#' @return Logical: TRUE if meta satisfies tier requirements, FALSE otherwise.
#'         If verbose=TRUE, prints detailed status; returns invisibly.
#'
#' @examples
#' # Tier B (standard)
#' meta_b <- data.frame(
#'   Sample_Name = c("S1", "S2"),
#'   Sample_Group = c("case", "control")
#' )
#' validate_meta_tier(meta_b, tier = "B")
#'
#' # Tier C (minimal, allows auto_group)
#' meta_c <- data.frame(Sample_Name = c("S1", "S2"))
#' validate_meta_tier(meta_c, tier = "C")
#'
#' @export
validate_meta_tier <- function(meta, tier = "B", verbose = TRUE) {
  if (!is.data.frame(meta)) {
    if (verbose) cat("[validate_meta_tier] ERROR: meta is not a data.frame\n")
    return(FALSE)
  }

  if (nrow(meta) < 1L) {
    if (verbose) cat("[validate_meta_tier] ERROR: meta has no rows\n")
    return(FALSE)
  }

  tier <- match.arg(tier, c("A", "B", "C"))
  required_cols <- switch(tier,
    "A" = c("Sample_Name", "Sample_Group", "Basename"),
    "B" = c("Sample_Name", "Sample_Group"),
    "C" = c("Sample_Name")
  )

  missing <- setdiff(required_cols, colnames(meta))
  is_valid <- length(missing) == 0L

  if (verbose) {
    tier_desc <- switch(tier,
      "A" = "QC-ready (Sample_Name + Sample_Group + Basename)",
      "B" = "Analysis-ready (Sample_Name + Sample_Group)",
      "C" = "Minimal (Sample_Name only)"
    )
    cat(sprintf("[validate_meta_tier] Tier %s (%s): %s\n", tier, tier_desc, if (is_valid) "PASS" else "FAIL"))
    if (!is_valid) {
      cat(sprintf("  Missing columns: %s\n", paste(missing, collapse = ", ")))
    }
    cat(sprintf("  Samples: %d\n", nrow(meta)))
  }

  invisible(is_valid)
}

##################################################################
#-----------------------------------------------------

SegmenPlot <- function() {
  # generate a segment plot displaying identified DMRs from EPIC methylation data
}
##################################################################

#' Test Whether Values Lie in an Interval
#'
#' @param values Numeric vector.
#' @param low_cutoff Lower bound, exclusive (default 0.3).
#' @param high_cutoff Upper bound, inclusive (default 0.7).
#'
#' @return Logical vector, `TRUE` where `low_cutoff < values <= high_cutoff`.
#' @export
Between <-function(values, low_cutoff=0.3,high_cutoff=0.7){
    # return logical if values within the range [low_cutoff,high_cutoff]
     values > low_cutoff & values <=high_cutoff
}
##################################################################


##################################################################
# 01/08/2025, 14:53:36

.qc_as_numeric_matrix <- function(x, arg_name) {
  if (is.null(x)) {
    return(NULL)
  }

  if (!(is.matrix(x) || is.data.frame(x))) {
    stop(arg_name, " must be a matrix or data.frame.")
  }

  mat <- as.matrix(x)
  storage.mode(mat) <- "numeric"
  mat
}

.qc_extract_sentrix_ids <- function(meta) {
  if (!is.data.frame(meta)) {
    return(NULL)
  }

  if ("Sentrix_ID" %in% colnames(meta)) {
    return(as.character(meta$Sentrix_ID))
  }

  if ("Basename" %in% colnames(meta)) {
    return(basename(as.character(meta$Basename)))
  }

  NULL
}

.qc_subset_to_samples <- function(mat, sample_ids, arg_name) {
  if (is.null(mat)) {
    return(NULL)
  }

  if (is.null(colnames(mat))) {
    if (ncol(mat) != length(sample_ids)) {
      stop(arg_name, " must have column names or the same number of columns as samples.")
    }
    colnames(mat) <- sample_ids
  }

  common_ids <- intersect(sample_ids, colnames(mat))
  if (length(common_ids) == 0L) {
    stop(arg_name, " has no overlapping sample columns.")
  }

  mat[, sample_ids[sample_ids %in% common_ids], drop = FALSE]
}

.qc_calc_recall_rate <- function(detctionPval, pCutoff = 0.05, cnSuffix = NULL) {
  if (is.null(detctionPval)) {
    return(NULL)
  }

  DF <- .qc_as_numeric_matrix(detctionPval, "detection_p")
  if (is.null(dim(DF)) || ncol(DF) < 1L || nrow(DF) < 1L) {
    return(NULL)
  }

  recallRateAll <- apply(DF, 1, FUN = function(x) {
    sum(x < pCutoff, na.rm = TRUE)
  })
  recallRateAll <- recallRateAll / ncol(DF)
  rr_cutoffs <- seq(1, 0.3, by = -0.05)[-1]
  DetectedCpGs <- vapply(rr_cutoffs, function(cutoff) {
    sum(recallRateAll >= cutoff, na.rm = TRUE)
  }, numeric(1))
  pctDetectedCpG <- round(DetectedCpGs / nrow(DF) * 100, 1)

  recallRate <- data.frame(
    recall_rate_cutoffs = rr_cutoffs * 100,
    DetectedCpG_dP = DetectedCpGs,
    pctDetectedCpG_dP = pctDetectedCpG,
    stringsAsFactors = FALSE
  )

  if (is.null(cnSuffix)) {
    cnSuffix <- paste0("_", ncol(DF))
  } else {
    cnSuffix <- paste0(cnSuffix, "_", ncol(DF))
  }
  colnames(recallRate)[2:3] <- paste(colnames(recallRate)[2:3], pCutoff, cnSuffix, sep = "")
  recallRate
}

.qc_extract_minfi_intensity <- function(minfi_object, intensity_cutoff = 11) {
  if (is.null(minfi_object)) {
    return(NULL)
  }

  if (!requireNamespace("minfi", quietly = TRUE)) {
    stop("minfi is required when minfi_object is supplied.")
  }

  U <- minfi::getUnmeth(minfi_object)
  U[is.na(U)] <- 0
  M <- minfi::getMeth(minfi_object)
  M[is.na(M)] <- 0

  if (requireNamespace("matrixStats", quietly = TRUE)) {
    uMed <- log2(matrixStats::colMedians(U, na.rm = TRUE))
    mMed <- log2(matrixStats::colMedians(M, na.rm = TRUE))
  } else {
    uMed <- log2(apply(U, 2, median, na.rm = TRUE))
    mMed <- log2(apply(M, 2, median, na.rm = TRUE))
  }

  intensity_qc <- data.frame(
    Sample_Name = names(mMed),
    mMed = as.numeric(mMed),
    uMed = as.numeric(uMed),
    aveMedIntensity = as.numeric((mMed + uMed) / 2),
    stringsAsFactors = FALSE
  )
  intensity_qc$intensity_status <- ifelse(
    intensity_qc$aveMedIntensity >= intensity_cutoff,
    "PASS",
    "FAIL"
  )
  intensity_qc
}

.qc_reduce_status <- function(dat, status_cols) {
  if (length(status_cols) == 0L) {
    return(rep(NA_character_, nrow(dat)))
  }

  apply(dat[, status_cols, drop = FALSE], 1, function(x) {
    x <- as.character(x)
    x <- x[!is.na(x) & nzchar(x)]
    if (length(x) == 0L) {
      return(NA_character_)
    }
    if (any(x == "FAIL")) {
      return("FAIL")
    }
    if (all(x == "PASS")) {
      return("PASS")
    }
    "WARN"
  })
}

#' Summarize Core Methylation Array QC Metrics
#'
#' Creates a deterministic QC bundle from matched metadata/beta inputs and
#' optional detection p-values or a minfi object. The returned list is designed
#' Not intended for direct storage in ImprintomeSet (QC data is handled by MethQcSet).
#'
#' @param betaFile Beta matrix/data.frame, file path, or an `ImprintomeSet`.
#' @param metaFile Optional metadata data.frame or file path. Not required when
#'   `betaFile` is an `ImprintomeSet`.
#' @param detection_p Optional detection p-value matrix/data.frame with samples
#'   in columns.
#' @param minfi_object Optional minfi object used to derive methylated and
#'   unmethylated intensity medians.
#' @param assay Optional assay label. When omitted and `betaFile` is an
#'   `ImprintomeSet`, `assay(betaFile)` is used.
#' @param p_cutoff Detection p-value threshold used for per-sample recall.
#' @param mean_detection_cutoff Mean detection p-value threshold for PASS/FAIL.
#' @param intensity_cutoff Minimum average median intensity for PASS/FAIL.
#'
#' @return Named list containing `metadata_qc`, `beta_qc`, optional
#'   `detection_qc`, optional `detection_recall_rate`, optional `intensity_qc`,
#'   and merged `sample_qc`.
#' @export
Meth_QC <- function(betaFile,
                    metaFile = NULL,
                    detection_p = NULL,
                    minfi_object = NULL,
                    assay = NULL,
                    p_cutoff = 0.05,
                    mean_detection_cutoff = 0.03,
                    intensity_cutoff = 11) {
  assay_value <- assay
  if (methods::is(betaFile, "ImprintomeSet") && is.null(assay_value)) {
    assay_value <- methods::slot(betaFile, "assay")
  }
  if (!is.null(assay_value)) {
    assay_value <- standardize_array(assay_value)
  }

  resolved <- .resolve_beta_meta_inputs(betaFile, metaFile, require_meta = TRUE)
  input <- LoadMetaBeta(resolved$meta, resolved$beta, probeset = NULL)

  meta <- input$meta
  beta <- .qc_as_numeric_matrix(input$beta, "betaFile")
  sample_ids <- as.character(meta$Sample_Name)
  beta <- .qc_subset_to_samples(beta, sample_ids, "betaFile")

  sentrix_ids <- .qc_extract_sentrix_ids(meta)
  sentrix_valid <- if (is.null(sentrix_ids)) {
    rep(NA, length(sample_ids))
  } else {
    CheckSentrixID(sentrix_ids)
  }

  metadata_qc <- data.frame(
    Sample_Name = sample_ids,
    stringsAsFactors = FALSE
  )
  if ("Sample_Group" %in% colnames(meta)) {
    metadata_qc$Sample_Group <- as.character(meta$Sample_Group)
  } else if ("SAMPLE_GROUP" %in% colnames(meta)) {
    metadata_qc$Sample_Group <- as.character(meta$SAMPLE_GROUP)
  }
  if (!is.null(assay_value)) {
    metadata_qc$assay <- assay_value
  }
  metadata_qc$sentrix_id <- if (is.null(sentrix_ids)) NA_character_ else as.character(sentrix_ids)
  metadata_qc$sentrix_id_valid <- as.logical(sentrix_valid)
  metadata_qc$sentrix_status <- ifelse(
    is.na(metadata_qc$sentrix_id_valid),
    NA_character_,
    ifelse(metadata_qc$sentrix_id_valid, "PASS", "FAIL")
  )

  beta_qc <- data.frame(
    Sample_Name = sample_ids,
    beta_median = apply(beta, 2, median, na.rm = TRUE),
    beta_missing_n = colSums(is.na(beta)),
    beta_missing_pct = round(colMeans(is.na(beta)) * 100, 2),
    stringsAsFactors = FALSE
  )

  out <- list(
    metadata_qc = metadata_qc,
    beta_qc = beta_qc
  )

  detection_qc <- NULL
  if (!is.null(detection_p)) {
    detection_mat <- .qc_as_numeric_matrix(detection_p, "detection_p")
    detection_mat <- .qc_subset_to_samples(detection_mat, sample_ids, "detection_p")
    pct_detected_col <- paste0("pctDetectedCpG_dP", format(p_cutoff, trim = TRUE, scientific = FALSE))

    detection_qc <- data.frame(
      Sample_Name = colnames(detection_mat),
      aveDetectionPval = colMeans(detection_mat, na.rm = TRUE),
      pct_detected = round(colMeans(detection_mat < p_cutoff, na.rm = TRUE) * 100, 1),
      stringsAsFactors = FALSE
    )
    colnames(detection_qc)[colnames(detection_qc) == "pct_detected"] <- pct_detected_col
    detection_qc$detection_status <- ifelse(
      detection_qc$aveDetectionPval < mean_detection_cutoff & detection_qc[[pct_detected_col]] > 95,
      "PASS",
      "FAIL"
    )

    out$detection_qc <- detection_qc
    out$detection_recall_rate <- .qc_calc_recall_rate(detection_mat, pCutoff = p_cutoff, cnSuffix = "_all")
  }

  intensity_qc <- .qc_extract_minfi_intensity(minfi_object, intensity_cutoff = intensity_cutoff)
  if (!is.null(intensity_qc)) {
    intensity_qc <- intensity_qc[intensity_qc$Sample_Name %in% sample_ids, , drop = FALSE]
    intensity_qc <- intensity_qc[match(sample_ids, intensity_qc$Sample_Name), , drop = FALSE]
    out$intensity_qc <- intensity_qc
  }

  sample_level_tables <- Filter(function(z) {
    is.data.frame(z) && "Sample_Name" %in% colnames(z)
  }, out)

  sample_qc <- Reduce(function(left, right) {
    merge(left, right, by = "Sample_Name", all = TRUE, sort = FALSE)
  }, sample_level_tables)

  status_cols <- intersect(
    c("sentrix_status", "detection_status", "intensity_status"),
    colnames(sample_qc)
  )
  sample_qc$final_qc_status <- .qc_reduce_status(sample_qc, status_cols)
  out$sample_qc <- sample_qc[match(sample_ids, sample_qc$Sample_Name), , drop = FALSE]

  out
}
##################################################################

IsValidColors <- function(x) {
  sapply(x, function(X) {
    tryCatch(is.matrix(col2rgb(X)),
      error = function(e) FALSE
    )
  })
}

#' Assign or Validate Group Colours in Metadata
#'
#' Adds a `COLOR` column with one standard colour per group when the metadata has none. When
#' `COLOR` holds category labels rather than colours, they are moved to `COLORGROUP` and replaced
#' by one colour per category; when it holds colours, they must map one-to-one onto the groups.
#'
#' @param meta Sample metadata data frame.
#' @param groupColumn Name of the grouping column (default `"Sample_Group"`; `"SAMPLE_GROUP"` is
#'   used when only that is present).
#'
#' @return `meta` with a valid `COLOR` column (and `COLORGROUP` for category labels).
#' @export
Check_Meta_Color <- function(meta, groupColumn = "Sample_Group") {
  if (!(groupColumn %in% colnames(meta)) && groupColumn == "Sample_Group" && "SAMPLE_GROUP" %in% colnames(meta)) {
    groupColumn <- "SAMPLE_GROUP"
  }
  if (!"COLOR" %in% colnames(meta)) {
    meta$COLOR <- standardColors()[as.integer(as.factor(meta[, groupColumn]))]
  } else {
    if (all(!IsValidColors(meta$COLOR))) { # allow custom color by category
      cat("\nINFO: custom color by category..")
      meta$COLORGROUP <- meta$COLOR
      meta$COLOR <- standardColors()[as.integer(as.factor(meta$COLORGROUP))]
    } else {
      cat("\nINFO: custom color by group ?")
      if (length(unique(meta$COLOR)) != length(unique(meta[, groupColumn]))) {
        cat("[No].\n")
        stop("meta$COLOR does not map one-to-one onto ", groupColumn, " groups. ",
             "Add a COLORGROUP categorical column to the metadata and ensure each COLOR ",
             "matches its COLORGROUP category.", call. = FALSE)
      } else {
        cat("[Yes].\n")
      }
    }
  }
  return(meta)
}
#================================================================

Select_Top_Features <- function(dat, method = "mad", topn = 3000) {
  if (!("data.frame" %in% class(dat) || "matrix" %in% class(dat))) {
    stop("[Select_Top_Features] dat must be a data.frame or matrix.")
  }
  dat <- as.matrix(dat)
  if (nrow(dat) == 0) {
    return(dat)
  }

  method <- tolower(method)
  scores <- switch(method,
    "mad" = apply(dat, 1, mad, na.rm = TRUE),
    "cv" = apply(dat, 1, function(x) sd(x, na.rm = TRUE) / mean(x, na.rm = TRUE)),
    "cv2" = apply(dat, 1, function(x) var(x, na.rm = TRUE) / (mean(x, na.rm = TRUE)^2)),
    "sd" = apply(dat, 1, sd, na.rm = TRUE),
    "var" = apply(dat, 1, var, na.rm = TRUE),
    "iqr" = apply(dat, 1, IQR, na.rm = TRUE),
    {
      cat("\nWARN: invalid ranking method. use [mad] instead.\n")
      apply(dat, 1, mad, na.rm = TRUE)
    }
  )

  scores[!is.finite(scores)] <- -Inf
  if (is.null(topn)) {
    topn <- nrow(dat)
  } else {
    topn <- as.integer(topn)
    if (is.na(topn) || topn < 1) {
      return(dat[0, , drop = FALSE])
    }
  }

  keep_n <- min(topn, nrow(dat))
  keep_idx <- order(scores, decreasing = TRUE)[seq_len(keep_n)]
  dat[keep_idx, , drop = FALSE]
}
#================================================================

ggplotColours <- function(n = 6, h = c(0, 360) + 15){
  if ((diff(h) %% 360) < 1) h[2] <- h[2] - 360/n
  hcl(h = (seq(h[1], h[2], length = n)), c = 100, l = 65)
}
#================================================================
PALETTES <-  c("default","seurat","viridis","plasma", "magma","inferno","inferno","inferno","kako","turbo")

#' Colour Palettes
#'
#' @param palette Palette name: `"default"` (the package's standard colours), `"seurat"` (ggplot2
#'   hue colours), or a viridis palette (`"viridis"`, `"plasma"`, `"magma"`, `"inferno"`,
#'   `"rocket"`, `"cividis"`, `"kako"` for mako, `"turbo"`). Case is ignored.
#' @param n Number of colours (default 10).
#'
#' @return Character vector of `n` colours, or `NULL` for an unknown palette.
#' @export
GetColors <- function(palette="Default",n=10) {
  colors <- switch(tolower(palette),
                   "default" = standardColors()[1:n],
                   "seurat" = ggplotColours(n),
                   "viridis" = viridisLite::viridis(n),
                   "plasma" = viridisLite::plasma(n),
                   "magma" = viridisLite::magma(n),
                   "inferno" = viridisLite::inferno(n),
                   "rocket" = viridisLite::rocket(n),
                   "cividis" = viridisLite::cividis(n),
                   "kako" = viridisLite::mako(n),
                   "turbo" = viridisLite::turbo(n)
    )
   return(colors)                
}
#-

#================================================================

Meth_Limma <- function() {
  # to be done
}
# ================================================================

Meth_DMR <- function() {
  # to be done
}


##################################################################

#' Per-ICR Methylation Variance per Sample
#'
#' Summarizes the probes of each imprinted region per sample: the median beta and the variance of
#' beta across the region's probes (`ImpVar_Score`), a measure of within-region heterogeneity.
#' Regions are either the loci of a bundled probeset (probes grouped by chromosome, parental
#' origin and nearest gene) or the intervals of a BED file.
#'
#' @param betaFile Beta matrix, data frame or file path (probes by samples).
#' @param metaFile Metadata data frame or file path with `Sample_Name`.
#' @param icr.bed Path of a BED file of regions, used when `probeset` is `NULL`. Requires the
#'   Bioconductor packages GenomicRanges and rtracklayer.
#' @param probeset Name of a bundled probeset whose loci define the regions.
#' @param assay Array type used to filter the annotation for `icr.bed`: `"450K"`, `"EPICv1"` or
#'   `"EPICv2"`.
#' @param genome Genome build, `"hg38"` (default) or `"hg19"`.
#' @param outFile Optional path of a tab-separated file to write the result to.
#'
#' @return Data frame with one row per sample and region: `Sample_Name`, `Sample_Group` and `ID2`
#'   when available, `icr_name`, `ImpVar_Score` (`NA` for regions with one probe), `Median_Beta`
#'   and `CpG_Count`.
#' @export
Calculate_impvar <- function(betaFile, metaFile = NULL,  icr.bed=NULL, probeset=NULL,assay=c("450K","EPICv1","EPICv2"),genome=c("hg38","hg19"),outFile=NULL) {
  genome <- match.arg(genome)

  resolved <- .resolve_beta_meta_inputs(betaFile, metaFile, require_meta = TRUE)
  betaFile <- resolved$beta
  metaFile <- resolved$meta
  
  input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
  meta <- input[["meta"]]
  beta <- input[["beta"]]

  if(!is.null(probeset)){
    probeset1 <- .get_probeset(probeset, genome)
    rownames(probeset1) <- probeset1$NAME
    commonProbes <- intersect(rownames(beta), probeset1$NAME)
    mapping <- beta[commonProbes, ]
    mapping$NAME <- commonProbes
    mapping$icr_name <- paste(probeset1[commonProbes,"CHR"],probeset1[commonProbes,"ORIGIN"], probeset1[commonProbes,"Closest_TSS_gene_name"],sep='_')

  }else{

        
      if(!is.null(assay)){
        assay <- standardize_array(assay)
        assay <-  match.arg(assay)
      }
      genome <- match.arg(genome)
      genome <- toupper(genome)
      
      cpg_annos <- readRDS(.resolve_extdata_file("anno.uniq_harmonized.liftover.rds"))
      if (!is.null(assay)){
        cpg_annos <- cpg_annos[grep(assay, cpg_annos[,"ASSAY"],ignore.case=T),]
      }
      chr <- paste0("CHR_", genome)
      mapinfo <- paste0("MAPINFO_", genome)
      if (!all(grepl("chr", cpg_annos[[chr]][1:1000]))) {
        cpg_annos[[chr]] <- paste("chr", gsub("chr", "", cpg_annos[[chr]]), sep = "")
      }

      .require_suggested("GenomicRanges", "Calculate_impvar() with icr.bed")
      # 1. Map CpGs to ICR regions
      cpg_gr <- GenomicRanges::GRanges(seqnames = cpg_annos[[chr]], 
                        ranges = IRanges::IRanges(start = cpg_annos[[mapinfo]], end = cpg_annos[[mapinfo]]))
      names(cpg_gr) <- cpg_annos[["NAME"]]

      icr_regions <- Bed2Granges(icr.bed)
      icr_names <- paste0(
          as.character(GenomeInfoDb::seqnames(icr_regions)), "_", 
          BiocGenerics::start(icr_regions), "_", 
          BiocGenerics::end(icr_regions)
        )
      icr_regions$name <- icr_names
      names(icr_regions) <- icr_names

      hits <- IRanges::findOverlaps(cpg_gr, icr_regions)
      
      # 2. Extract and Group Data
      # We create a mapping of which CpG belongs to which ICR
      mapping <- data.frame(
        NAME=names(cpg_gr)[S4Vectors::queryHits(hits)],
        CHR= as.character(GenomeInfoDb::seqnames(cpg_gr)[S4Vectors::queryHits(hits)]),
        MAPINFO = BiocGenerics::start(cpg_gr)[S4Vectors::queryHits(hits)],
        cpg_idx = S4Vectors::queryHits(hits),
        icr_name = icr_regions$name[S4Vectors::subjectHits(hits)]
      )
      
  }

  #beta <- LoadBeta(betaFile)
  if("TargetID" %in% colnames(beta)){
    beta$TargetID <- NULL
  }
  beta_matrix <- as.matrix(beta)

  # 3. Calculate within-region Variance
  # High variance = High stochasticity/instability
  report <- mapping %>%
        filter(NAME %in% rownames(beta_matrix)) %>%
        group_by(icr_name) %>%
          group_modify(~ {
      # Subset the beta matrix for CpGs in this specific ICR
      sub_beta <- beta_matrix[.x$NAME, , drop = FALSE]
      # 2.1 Calculate Median (always possible if nrow > 0)
        # colMedians returns a vector of medians, one per sample
        medians <- matrixStats::colMedians(sub_beta, na.rm = TRUE)

      # 2.2 Check if we have enough CpGs to calculate variance
        # Variance of 0 or 1 point is NA; we handle that here
        if (nrow(sub_beta) < 2) {
            scores <- rep(NA_real_, ncol(sub_beta))
   
        } else {
            scores <- matrixStats::colVars(sub_beta, na.rm = TRUE)
        }
      # Calculate column-wise variance (per sample)
      # We use Var to capture the 'spread' of methylation across the ICR
      data.frame(
        Sample_Name = colnames(beta_matrix),
        Median_Beta = medians,
        ImpVar_Score = scores,
        CpG_Count = nrow(sub_beta)
      )
    }) %>%
    ungroup()
    # Join metadata to the report
  
  final_report <- report %>%
    left_join(meta, by = "Sample_Name") %>%
    select(Sample_Name, any_of(c("Sample_Group", "ID2")), icr_name, ImpVar_Score, Median_Beta, CpG_Count) %>%
    arrange(Sample_Name)

  if(!is.null(outFile)){
    # outFile <- paste0(prefix,"_Stochastic_Drift.txt")
    write.table(final_report, outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
    cat("\n[",basename(outFile),"[saved]")
  }
  return(final_report)
}
#----------------------------------------------------------------

#' Aggregate EPICv2 Probes to Base Probe IDs
#'
#' EPICv2 arrays report multiple measurements per base CpG probe (e.g., cg06373096_TC11,
#' cg06373096_TC12, ..., cg06373096_TC110 all measure cg06373096). This function aggregates
#' repeated measurements into a single representative value per unique probe ID.
#'
#' @param beta_df A data.frame with a \code{TargetID} column (probe IDs) and numeric columns
#'   (beta values, detection p-values, etc.). Can be coerced from matrix.
#' @param method Character, one of \code{c("median", "mean")}. Aggregation method for
#'   numeric columns. Default: \code{"median"}.
#'
#' @return A data.frame with the same structure as \code{beta_df}, but with:
#'   \itemize{
#'     \item \code{TargetID} column: base probe IDs (suffixes removed)
#'     \item Numeric columns: aggregated values (median or mean across replicates)
#'   }
#'   If no EPICv2-style suffixes are detected (\code{_[TB].\\d+$}), returns \code{beta_df}
#'   unchanged (with a message). In both cases the attribute \code{aggregation_report} holds
#'   a data.frame (\code{metric}, \code{n}, \code{description}) counting the identifiers:
#'   \code{input_rows}, \code{output_ids}, \code{replicate_groups_collapsed} (base IDs built from
#'   two or more rows), \code{replicate_rows_collapsed}, \code{suffix_stripped_single} (base IDs
#'   from a single suffixed row), \code{unchanged_ids} (IDs without a replicate suffix, kept as
#'   they are), \code{malformed_kept} (IDs with surrounding white space or an underscore suffix
#'   that is not a replicate suffix; kept unchanged), \code{malformed_dropped} (missing or empty
#'   IDs; removed), \code{all_missing_cells} (aggregated values that are missing because every
#'   replicate was missing) and \code{all_missing_ids} (output IDs missing in every column).
#'
#' @details
#' The function detects EPICv2 probe suffixes matching the pattern \code{_[TB].\\d+$}
#' (e.g., \code{_TC11}, \code{_TB01}). If found, the suffix is stripped and values are
#' aggregated by base probe ID. Numeric columns are aggregated using the chosen method,
#' ignoring missing values; a group whose values are all missing stays missing. All other
#' columns are dropped.
#'
#' @examples
#' \dontrun{
#'   # Load EPICv2 beta matrix
#'   beta_df <- read.delim("epicv2_beta.txt")
#'   
#'   # Aggregate to base probes
#'   beta_agg <- aggregate_beta_epicv2(beta_df, method = "median")
#'   
#'   # Check result
#'   dim(beta_agg)  # Fewer rows (unique base probes)
#' }
#'
#' @export
aggregate_beta_epicv2 <- function(beta_df, method = c("median", "mean")) {
  
  # Coerce to data.frame if needed
  if (!is.data.frame(beta_df)) {
    beta_df <- as.data.frame(beta_df)
  }
  
  # Validate TargetID column exists
  if (!("TargetID" %in% colnames(beta_df))) {
    stop("TargetID column not found in beta_df. Required for probe aggregation.")
  }
  
  ids <- as.character(beta_df$TargetID)
  suffixed <- !is.na(ids) & grepl("_[TB].\\d+$", ids)

  # Check for EPICv2-style suffixes
  if (sum(suffixed) == 0) {
    message("No EPICv2-style suffixes detected in TargetID. Returning data unchanged.")
    attr(beta_df, "aggregation_report") <- .aggregation_report(ids, suffixed, NULL, NULL)
    return(beta_df)
  }

  # Match and validate method argument
  method <- match.arg(method)

  # Missing or empty identifiers cannot be assigned to a probe and are removed.
  dropped <- is.na(ids) | !nzchar(trimws(ids))
  beta_df <- beta_df[!dropped, , drop = FALSE]

  # Strip suffixes to get base probe IDs
  beta_df$TargetID <- sub("_[TB].\\d+$", "", beta_df$TargetID)

  # Aggregate: group by TargetID, aggregate all numeric columns
  aggregated_data <- beta_df %>%
    dplyr::group_by(TargetID) %>%
    dplyr::summarise(dplyr::across(where(is.numeric),
                                   list(~ if (method == "median")
                                          median(., na.rm = TRUE)
                                        else
                                          mean(., na.rm = TRUE)),
                                   .names = "{.col}"),
                     .groups = "drop") %>%
    as.data.frame()
  # mean() of no values is NaN; report such groups as missing, like median().
  num_cols <- vapply(aggregated_data, is.numeric, logical(1))
  aggregated_data[num_cols] <- lapply(aggregated_data[num_cols], function(v) { v[is.nan(v)] <- NA; v })

  attr(aggregated_data, "aggregation_report") <-
    .aggregation_report(ids, suffixed, beta_df$TargetID, aggregated_data[, num_cols, drop = FALSE])
  aggregated_data
}

# Identifier counts for aggregate_beta_epicv2(). ids/suffixed describe the input rows; base_ids are
# the base IDs of the rows kept, and values the aggregated numeric columns (NULL when nothing was
# aggregated).
.aggregation_report <- function(ids, suffixed, base_ids, values) {
  dropped <- is.na(ids) | !nzchar(trimws(ids))
  kept_ids <- ids[!dropped]
  malformed_kept <- sum(kept_ids != trimws(kept_ids) | (grepl("_", kept_ids) & !suffixed[!dropped]))
  if (is.null(base_ids)) {
    n_collapsed <- 0L
    rows_collapsed <- 0L
    single <- 0L
    missing_cells <- 0L
    missing_ids <- 0L
    n_out <- length(ids)
  } else {
    group_size <- table(base_ids)
    n_collapsed <- sum(group_size >= 2L)
    rows_collapsed <- sum(group_size[group_size >= 2L])
    sfx_groups <- table(base_ids[suffixed[!dropped]])
    single <- sum(sfx_groups == 1L & group_size[names(sfx_groups)] == 1L)
    missing <- is.na(as.matrix(values))
    missing_cells <- sum(missing)
    missing_ids <- if (ncol(missing)) sum(rowSums(missing) == ncol(missing)) else 0L
    n_out <- nrow(values)
  }
  data.frame(
    metric = c("input_rows", "output_ids", "replicate_groups_collapsed", "replicate_rows_collapsed",
               "suffix_stripped_single", "unchanged_ids", "malformed_kept", "malformed_dropped",
               "all_missing_cells", "all_missing_ids"),
    n = as.integer(c(length(ids), n_out, n_collapsed, rows_collapsed, single,
                     sum(!suffixed & !dropped), malformed_kept, sum(dropped), missing_cells, missing_ids)),
    description = c(
      "rows in the input",
      "identifiers in the output",
      "base IDs built from two or more rows",
      "input rows in those groups",
      "base IDs from a single suffixed row (suffix removed)",
      "IDs without a replicate suffix, kept as they are",
      "IDs with surrounding white space or a non-replicate underscore suffix, kept unchanged",
      "missing or empty IDs, removed",
      "aggregated values missing because every replicate was missing",
      "output IDs missing in every column"),
    stringsAsFactors = FALSE
  )
}
#----------------------------------------------------------------


# Stop with an informative error when an optional (Suggests) package is not installed.
.require_suggested <- function(pkg, what) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Package '", pkg, "' is needed for ", what, "; please install it.", call. = FALSE)
  }
  invisible(TRUE)
}

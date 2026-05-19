#' Visualization, Export, and Summary Methods for MethQcSet
#'
#' Methods for plotting QC metrics, exporting results, and summarizing cohort state.
#'
#' @name MethQcSet-viz
NULL

# ============================================================================
# Generic summarize for ImprintomeSet (MethQcSet uses qc_summarize instead)
# ============================================================================

if (!methods::isGeneric("summarize")) {
  methods::setGeneric("summarize", function(object, ...) standardGeneric("summarize"))
}

# ============================================================================
# qc_summarize() - Inventory of QC state
# ============================================================================

#' Summarize a MethQcSet Object
#'
#' Generate a comprehensive inventory of a `MethQcSet` object including sample counts,
#' probe counts, QC status summary, and aggregation state.
#'
#' @param x A `MethQcSet` object.
#' @param ... Additional arguments (reserved for future use).
#'
#' @return A named list with:
#'   \itemize{
#'     \item `platform`: Platform identifier
#'     \item `n_samples`: Number of samples
#'     \item `n_probes`: Number of probes
#'     \item `aggregation_status`: Current aggregation state
#'     \item `qc_status`: Summary of QC pass/fail counts (if qc_matrix present)
#'     \item `missing_values`: Count of missing values in beta matrix
#'     \item `qc_tables`: Names of QC tables stored
#'   }
#'
#' @export
qc_summarize <- function(x, ...) {
  if (!is(x, "MethQcSet")) {
    stop("x must be a MethQcSet object")
  }

  summary_list <- list(
    platform = x@platform,
    n_samples = ncol(x@beta),
    n_probes = nrow(x@beta),
    aggregation_status = x@aggregation_status,
    missing_values_beta = sum(is.na(x@beta))
  )

  # Add QC status if QC_matrix present
  if ("QC_matrix" %in% names(x@qc_tables)) {
    qc_matrix <- x@qc_tables[["QC_matrix"]]
    if ("Final.QC" %in% colnames(qc_matrix)) {
      summary_list$qc_status <- table(qc_matrix$Final.QC, useNA = "ifany")
    }
  }

  # Add detection p-value missing counts if present
  if (!is.null(x@detection_pval)) {
    summary_list$missing_values_detection_pval <- sum(is.na(x@detection_pval))
  }

  # List QC tables
  summary_list$qc_tables <- names(x@qc_tables)

  summary_list
}

# ============================================================================
# export() - Write QC tables and beta files
# ============================================================================

#' Export MethQcSet Data
#'
#' Write QC tables, beta values, and metadata to disk in various formats.
#'
#' @param x A `MethQcSet` object.
#' @param outdir Directory where files will be written.
#' @param format Character vector of output formats: `"xlsx"` (default, requires openxlsx),
#'   `"rds"`, or `"txt"` (tab-delimited). Multiple formats can be combined.
#' @param prefix Character, prefix for output filenames (default: "methqcset").
#' @param ... Additional arguments (reserved for future use).
#'
#' @return Invisibly returns a character vector of written file paths.
#'
#' @details
#' **xlsx output (recommended):**
#' All QC tables are written into a **single workbook** (`{prefix}_qc_tables.xlsx`)
#' with one sheet per table: `QC_matrix`, `recall_rate`, `cutoffs`,
#' `ctrl_metrics`, `contamination`, `predUniqDonor_ID`. Sample metadata is
#' written to a separate sheet `meta` in the same workbook. Beta values are
#' excluded from xlsx (too large) and written as rds only.
#'
#' **rds output:**
#' Each object (`beta`, `meta`, individual QC tables) is saved as a separate
#' `.rds` file for programmatic access.
#'
#' **txt output:**
#' Tab-delimited `.txt` files for beta, metadata, and each QC table separately.
#'
#' @export
methods::setMethod("export", "MethQcSet", function(x, outdir, format = c("xlsx", "rds"),
                                                   prefix = "methqcset", ...) {

  format <- match.arg(format, choices = c("xlsx", "rds", "txt"), several.ok = TRUE)

  if (!dir.exists(outdir)) {
    dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  }

  written_files <- character()

  # =========================================================================
  # RDS: save entire MethQcSet object (NOT individual components)
  # =========================================================================
  if ("rds" %in% format) {
    outfile <- file.path(outdir, paste0(prefix, "_qcset.rds"))
    saveRDS(x, outfile)
    written_files <- c(written_files, outfile)
    message("rds: wrote MethQcSet to ", basename(outfile))
  }

  # =========================================================================
  # xlsx: single workbook — meta + all qc_tables as separate sheets
  # =========================================================================
  if ("xlsx" %in% format) {
    if (!requireNamespace("openxlsx", quietly = TRUE)) {
      warning("openxlsx not installed. Skipping xlsx export.")
    } else {
      wb <- openxlsx::createWorkbook()

      # Sheet 1: metadata — augmented with Platform and Final.QC from QC_matrix
      meta_out <- x@meta
      meta_out[["Platform"]] <- x@platform
      qcm <- x@qc_tables[["QC_matrix"]]
      if (!is.null(qcm) && "SAMPLE_NAME" %in% colnames(qcm) && "Final.QC" %in% colnames(qcm)) {
        idx <- match(as.character(meta_out[["SAMPLE_NAME"]]),
                     as.character(qcm[["SAMPLE_NAME"]]))
        meta_out[["Final.QC"]] <- qcm[["Final.QC"]][idx]
      }
      openxlsx::addWorksheet(wb, "meta")
      openxlsx::writeData(wb, "meta", meta_out, rowNames = FALSE)

      # One sheet per QC table (canonical order)
      canonical_order <- c("QC_matrix", "recall_rate", "cutoffs",
                           "ctrl_metrics", "contamination", "predUniqDonor_ID")
      sheet_names <- c(canonical_order,
                       setdiff(names(x@qc_tables), canonical_order))

      for (tbl_name in sheet_names) {
        tbl <- x@qc_tables[[tbl_name]]
        if (is.null(tbl) || !is.data.frame(tbl)) next
        # Sheet names max 31 chars
        safe_name <- substr(tbl_name, 1, 31)
        openxlsx::addWorksheet(wb, safe_name)
        openxlsx::writeData(wb, safe_name, tbl, rowNames = FALSE)
      }

      outfile <- file.path(outdir, paste0(prefix, "_qc_tables.xlsx"))
      tryCatch({
        openxlsx::saveWorkbook(wb, outfile, overwrite = TRUE)
        written_files <- c(written_files, outfile)
        message("xlsx: wrote ", length(openxlsx::sheets(wb)), " sheets to ", basename(outfile))
      }, error = function(e) {
        warning("Could not write xlsx workbook: ", conditionMessage(e))
      })
    }
  }

  # =========================================================================
  # txt: individual files for meta + beta + each QC table
  # =========================================================================
  if ("txt" %in% format) {
    # Beta matrix
    beta_df <- as.data.frame(x@beta)
    beta_df <- cbind(TargetID = rownames(x@beta), beta_df)
    outfile <- file.path(outdir, paste0(prefix, "_beta.txt"))
    write.table(beta_df, outfile, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    written_files <- c(written_files, outfile)

    # Metadata
    outfile <- file.path(outdir, paste0(prefix, "_meta.txt"))
    write.table(x@meta, outfile, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    written_files <- c(written_files, outfile)

    # Individual QC tables
    for (qc_name in names(x@qc_tables)) {
      qc_table <- x@qc_tables[[qc_name]]
      if (!is.data.frame(qc_table)) next
      outfile <- file.path(outdir, paste0(prefix, "_qc_", qc_name, ".txt"))
      write.table(qc_table, outfile, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
      written_files <- c(written_files, outfile)
    }
    message("txt: wrote ", sum(grepl("\\.txt$", written_files)), " text files")
  }

  # =========================================================================
  # Export summary
  # =========================================================================
  summary_result <- qc_summarize(x)
  summary_txt <- paste0(
    "MethQcSet Summary\n",
    "==================\n",
    "Platform: ", summary_result$platform, "\n",
    "Samples: ", summary_result$n_samples, "\n",
    "Probes: ", summary_result$n_probes, "\n",
    "Aggregation Status: ", summary_result$aggregation_status, "\n",
    "Missing Beta Values: ", summary_result$missing_values_beta, "\n"
  )

  if (!is.null(summary_result$missing_values_detection_pval)) {
    summary_txt <- paste0(summary_txt,
                         "Missing Detection P-values: ", summary_result$missing_values_detection_pval, "\n")
  }

  if (!is.null(summary_result$qc_status)) {
    summary_txt <- paste0(summary_txt, "\nQC Status (Final.QC):\n")
    for (status in names(summary_result$qc_status)) {
      summary_txt <- paste0(summary_txt, "  ", status, ": ", summary_result$qc_status[[status]], "\n")
    }
  }

  summary_txt <- paste0(summary_txt, "\nQC Tables (sheets in xlsx): ",
                        paste(summary_result$qc_tables, collapse = ", "), "\n")

  summary_file <- file.path(outdir, paste0(prefix, "_summary.txt"))
  writeLines(summary_txt, summary_file)
  written_files <- c(written_files, summary_file)

  message("Exported ", length(written_files), " file(s) to ", outdir)
  invisible(written_files)
})

# ============================================================================
# plot() - QC-stage visualization
# ============================================================================

if (!methods::isGeneric("plot")) {
  methods::setGeneric("plot", function(x, y, ...) standardGeneric("plot"))
}

#' Plot QC Metrics from MethQcSet
#'
#' Generate QC-stage visualizations from stored QC tables.
#'
#' @param x A `MethQcSet` object.
#' @param y Ignored (for generic compatibility).
#' @param type Character scalar. One of `"qc_bar"` (default), `"intensity"`,
#'   `"detection_pval"`, `"probe_coverage"`, `"predicted_sex"`, `"ctrl_metrics"`,
#'   `"ctrl_metrics_detail"`.
#' @param icutoff Numeric. log2 intensity cutoff reference line for `"intensity"` plot (default 11).
#' @param pcutoff Numeric. Detection p-value cutoff reference line for `"detection_pval"` plot (default 0.05).
#' @param outFile Optional file path to save the plot (format inferred from extension: pdf/png/svg).
#' @param ... Additional arguments forwarded to `ggplot2::ggsave()`.
#'
#' @return A ggplot object. Also written to `outFile` when provided.
#'
#' @details
#' **Plot types:**
#' \describe{
#'   \item{`qc_bar`}{PASS / FAIL sample count bar chart from `QC_matrix$Final.QC`.}
#'   \item{`intensity`}{Scatter of mMed.Intensity vs uMed.Intensity per sample, colored by
#'     `Final.QC`, with a horizontal reference line at `icutoff`.}
#'   \item{`detection_pval`}{Per-sample average detection p-value dot plot, colored by
#'     `Final.QC`, with a horizontal reference line at `pcutoff`.}
#'   \item{`probe_coverage`}{Per-sample percent of probes detected (dP < 0.05), colored by
#'     `Final.QC`, with a reference line at 95\%.}
#'   \item{`predicted_sex`}{Bar chart of predicted sex counts from `QC_matrix$predictedSex`.}
#'   \item{`ctrl_metrics`}{Per-sample dot chart of ewastools `CtrlMetrics.QC` from `ctrl_metrics`.
#'     Returns `NULL` silently if `ctrl_metrics` is absent.}
#'   \item{`ctrl_metrics_detail`}{One jitter-dot plot per ewastools control metric
#'     (Bisulfite Conversion, Specificity, Non-polymorphic). `outFile` is used as a
#'     path prefix; individual files are saved as `{prefix}_CtrlMetrics_{Metric}.pdf`.
#'     Returns a named list of ggplot objects.}
#' }
#' All types return `NULL` with a message if the required data are not yet present.
#'
#' @export
methods::setMethod("plot", c("MethQcSet", "missing"), function(x, y,
    type     = "qc_bar",
    icutoff  = 11,
    pcutoff  = 0.03,
    outFile  = NULL,
    ...) {

  # Shared palette: PASS = teal, FAIL = coral
  qc_colors <- c("PASS" = "#1B9E77", "FAIL" = "#D95F02")

  .get_qcm <- function(x) {
    qcm <- x@qc_tables[["QC_matrix"]]
    if (is.null(qcm)) {
      message("QC_matrix not found in qc_tables. Run runMethQC() first.")
      return(NULL)
    }
    qcm
  }

  plot_obj <- NULL

  # =========================================================================
  # qc_bar: PASS / FAIL count bar chart
  # =========================================================================
  if (type == "qc_bar") {
    qcm <- .get_qcm(x)
    if (is.null(qcm)) return(NULL)
    if (!("Final.QC" %in% colnames(qcm))) {
      message("Final.QC column not found in QC_matrix.")
      return(NULL)
    }
    tbl <- as.data.frame(table(Final.QC = qcm$Final.QC, useNA = "ifany"),
                         stringsAsFactors = FALSE)
    plot_obj <- ggplot2::ggplot(tbl, ggplot2::aes(x = Final.QC, y = Freq, fill = Final.QC)) +
      ggplot2::geom_col(width = 0.5) +
      ggplot2::scale_fill_manual(values = qc_colors, na.value = "grey70") +
      ggplot2::geom_text(ggplot2::aes(label = Freq), vjust = -0.4, size = 3.5) +
      ggplot2::theme_classic(base_size = 12) +
      ggplot2::labs(title = paste0("QC Summary — ", x@platform),
                    x = "Final.QC", y = "Number of Samples") +
      ggplot2::theme(legend.position = "none",
                     plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"))

  # =========================================================================
  # intensity: mMed vs uMed scatter, hline at icutoff
  # =========================================================================
  } else if (type == "intensity") {
    qcm <- .get_qcm(x)
    if (is.null(qcm)) return(NULL)
    need <- c("mMed.Intensity", "uMed.Intensity", "SAMPLE_NAME")
    missing_cols <- setdiff(need, colnames(qcm))
    if (length(missing_cols)) {
      message("Missing columns for intensity plot: ", paste(missing_cols, collapse = ", "))
      return(NULL)
    }
    qcm$QC <- if ("Final.QC" %in% colnames(qcm)) qcm$Final.QC else "unknown"
    
    # Compute axis limits: default 5-15, but expand if data exceeds this range
    all_intensity <- c(qcm$mMed.Intensity, qcm$uMed.Intensity)
    min_int <- min(all_intensity, na.rm = TRUE)
    max_int <- max(all_intensity, na.rm = TRUE)
    
    x_lim <- c(if (min_int < 5) min_int * 0.95 else 5,
               if (max_int > 15) max_int * 1.05 else 15)
    y_lim <- x_lim  # Same limits for both axes (scatter plot)
    
    plot_obj <- ggplot2::ggplot(qcm,
        ggplot2::aes(x = mMed.Intensity, y = uMed.Intensity,
                     color = QC, label = SAMPLE_NAME)) +
      ggplot2::geom_point(size = 2, alpha = 0.8) +
      ggplot2::geom_hline(yintercept = icutoff, linetype = "dashed",
                          color = "grey40", linewidth = 0.7) +
      ggplot2::geom_vline(xintercept = icutoff, linetype = "dashed",
                          color = "grey40", linewidth = 0.7) +
      ggplot2::scale_color_manual(values = qc_colors, na.value = "grey70") +
      ggplot2::scale_x_continuous(limits = x_lim, expand = ggplot2::expansion(mult = c(0, 0.05))) +
      ggplot2::scale_y_continuous(limits = y_lim, expand = ggplot2::expansion(mult = c(0, 0.05))) +
      ggplot2::theme_classic(base_size = 12) +
      ggplot2::labs(title = paste0("Array Intensity — ", x@platform),
                    subtitle = paste0("Cutoff: log2 intensity > ", icutoff),
                    x = "Methylated Median Intensity (log2)",
                    y = "Unmethylated Median Intensity (log2)",
                    color = "Final.QC") +
      ggplot2::theme(plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"))

  # =========================================================================
  # detection_pval (aveDetPval): per-sample avg detection p-value, -log10 scale
  # =========================================================================
  } else if (type == "detection_pval") {
    qcm <- .get_qcm(x)
    if (is.null(qcm)) return(NULL)
    if (!all(c("SAMPLE_NAME", "aveDetectionPval") %in% colnames(qcm))) {
      message("SAMPLE_NAME or aveDetectionPval not found in QC_matrix.")
      return(NULL)
    }
    qcm$QC <- if ("Final.QC" %in% colnames(qcm)) qcm$Final.QC else "unknown"
    qcm$log_pval <- -log10(qcm$aveDetectionPval)
    qcm <- qcm[order(qcm$log_pval), ]
    qcm$SAMPLE_NAME <- factor(qcm$SAMPLE_NAME, levels = qcm$SAMPLE_NAME)
    
    # Reference line at -log10(pcutoff)
    ref_pval_threshold <- -log10(pcutoff)
    
    plot_obj <- ggplot2::ggplot(qcm,
        ggplot2::aes(x = SAMPLE_NAME, y = log_pval, color = QC)) +
      ggplot2::geom_point(size = 2) +
      ggplot2::geom_hline(yintercept = ref_pval_threshold, linetype = "dashed",
                          color = "purple", linewidth = 0.7) +
      ggplot2::scale_color_manual(values = qc_colors, na.value = "grey70") +
      ggplot2::scale_y_continuous(limits = c(0, NA), expand = ggplot2::expansion(mult = c(0, 0.05))) +
      ggplot2::theme_classic(base_size = 11) +
      ggplot2::labs(title = paste0("Average Detection P-value — ", x@platform),
                    subtitle = paste0("Above the line: p-value < ", pcutoff),
                    x = NULL, y = "-log10(Average Detection P-value)",
                    color = "Final.QC") +
      ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, hjust = 1,
                                                         vjust = 0.5, size = 7),
                     plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"))

  # =========================================================================
  # probe_coverage: % detected probes per sample, hline at 95%
  # =========================================================================
  } else if (type == "probe_coverage") {
    qcm <- .get_qcm(x)
    if (is.null(qcm)) return(NULL)
    if (!all(c("SAMPLE_NAME", "pctDetectedCpG_dP0.05") %in% colnames(qcm))) {
      message("SAMPLE_NAME or pctDetectedCpG_dP0.05 not found in QC_matrix.")
      return(NULL)
    }
    qcm$QC <- if ("Final.QC" %in% colnames(qcm)) qcm$Final.QC else "unknown"
    qcm <- qcm[order(qcm$pctDetectedCpG_dP0.05), ]
    qcm$SAMPLE_NAME <- factor(qcm$SAMPLE_NAME, levels = qcm$SAMPLE_NAME)
    plot_obj <- ggplot2::ggplot(qcm,
        ggplot2::aes(x = SAMPLE_NAME, y = pctDetectedCpG_dP0.05, fill = QC)) +
      ggplot2::geom_col() +
      ggplot2::geom_hline(yintercept = 95, linetype = "dashed",
                          color = "grey40", linewidth = 0.7) +
      ggplot2::scale_fill_manual(values = qc_colors, na.value = "grey70") +
      ggplot2::theme_classic(base_size = 11) +
      ggplot2::labs(title = paste0("Probe Coverage per Sample — ", x@platform),
                    subtitle = "Reference line: 95% detected (dP < 0.05)",
                    x = NULL, y = "% CpGs Detected (dP < 0.05)",
                    fill = "Final.QC") +
      ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, hjust = 1,
                                                         vjust = 0.5, size = 7),
                     plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"))

  # =========================================================================
  # predicted_sex: bar chart of predicted sex counts
  # =========================================================================
  } else if (type == "predicted_sex") {
    qcm <- .get_qcm(x)
    if (is.null(qcm)) return(NULL)
    if (!("predictedSex" %in% colnames(qcm))) {
      message("predictedSex not found in QC_matrix. Run runMethQC() with minfi available.")
      return(NULL)
    }
    sex_colors <- c("M" = "#4393C3", "F" = "#D6604D", "undetermined" = "grey70")
    tbl <- as.data.frame(table(predictedSex = qcm$predictedSex, useNA = "ifany"),
                         stringsAsFactors = FALSE)
    plot_obj <- ggplot2::ggplot(tbl,
        ggplot2::aes(x = predictedSex, y = Freq, fill = predictedSex)) +
      ggplot2::geom_col(width = 0.5) +
      ggplot2::scale_fill_manual(values = sex_colors, na.value = "grey70") +
      ggplot2::geom_text(ggplot2::aes(label = Freq), vjust = -0.4, size = 3.5) +
      ggplot2::theme_classic(base_size = 12) +
      ggplot2::labs(title = paste0("Predicted Sex — ", x@platform),
                    x = "Predicted Sex", y = "Number of Samples") +
      ggplot2::theme(legend.position = "none",
                     plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"))

  # =========================================================================
  # ctrl_metrics: per-sample ewastools control metric QC
  # =========================================================================
  } else if (type == "ctrl_metrics") {
    ctrl <- x@qc_tables[["ctrl_metrics"]]
    if (is.null(ctrl)) {
      message("ctrl_metrics not found. Skipping (ewastools data absent).")
      return(NULL)
    }
    if (!all(c("SAMPLE_NAME", "CtrlMetrics.QC") %in% colnames(ctrl))) {
      message("SAMPLE_NAME or CtrlMetrics.QC not found in ctrl_metrics.")
      return(NULL)
    }
    # Create bar chart with PASS/FAIL counts
    qc_colors <- c("PASS" = "#1B9E77", "FAIL" = "#D95F02")
    tbl <- as.data.frame(table(CtrlMetrics.QC = ctrl$CtrlMetrics.QC, useNA = "ifany"),
                         stringsAsFactors = FALSE)
    plot_obj <- ggplot2::ggplot(tbl,
        ggplot2::aes(x = CtrlMetrics.QC, y = Freq, fill = CtrlMetrics.QC)) +
      ggplot2::geom_col(width = 0.5) +
      ggplot2::scale_fill_manual(values = qc_colors, na.value = "grey70") +
      ggplot2::geom_text(ggplot2::aes(label = Freq), vjust = -0.4, size = 3.5) +
      ggplot2::theme_classic(base_size = 12) +
      ggplot2::labs(title = paste0("Control Probe Metrics — ", x@platform),
                    subtitle = "ewastools CtrlMetrics.QC score",
                    x = "CtrlMetrics.QC", y = "Number of Samples") +
      ggplot2::theme(legend.position = "none",
                     plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"))

  # =========================================================================
  # ctrl_metrics_detail: one jitter-dot plot per control metric column
  # =========================================================================
  } else if (type == "ctrl_metrics_detail") {
    ctrl <- x@qc_tables[["ctrl_metrics"]]
    if (is.null(ctrl)) {
      message("ctrl_metrics not found. Skipping (ewastools data absent).")
      return(invisible(NULL))
    }
    if (!"SAMPLE_NAME" %in% colnames(ctrl)) {
      message("SAMPLE_NAME not found in ctrl_metrics.")
      return(invisible(NULL))
    }

    # Metric sets with their cutoffs, matching meth_QC.R
    metric_cutoffs <- c(
      "Bisulfite Conversion I Green" = 1,
      "Bisulfite Conversion I Red"   = 1,
      "Specificity I Green"          = 1,
      "Bisulfite Conversion II"      = 1,
      "Specificity I Red"            = 1,
      "Specificity II"               = 1,
      "Non-polymorphic Green"        = 5,
      "Non-polymorphic Red"          = 5
    )
    available <- intersect(names(metric_cutoffs), colnames(ctrl))
    if (length(available) == 0) {
      message("No recognised control metric columns found in ctrl_metrics.")
      return(invisible(NULL))
    }

    # Determine output prefix: strip extension from outFile if provided
    out_prefix <- if (!is.null(outFile)) tools::file_path_sans_ext(outFile) else NULL

    plots_out <- lapply(available, function(metric) {
      cutoff <- metric_cutoffs[[metric]]
      df <- data.frame(
        SAMPLE_NAME = ctrl$SAMPLE_NAME,
        y           = ctrl[[metric]],
        QC          = ifelse(ctrl[[metric]] > cutoff, "PASS", "WARN"),
        stringsAsFactors = FALSE
      )
      # Sort by metric value (ascending, like detection_pval)
      df <- df[order(df$y), ]
      df$SAMPLE_NAME <- factor(df$SAMPLE_NAME, levels = df$SAMPLE_NAME)
      
      p <- ggplot2::ggplot(df, ggplot2::aes(x = SAMPLE_NAME, y = y, color = QC)) +
        ggplot2::geom_point(size = 2) +
        ggplot2::geom_hline(yintercept = cutoff, linetype = "dashed",
                            color = "grey40", linewidth = 0.7) +
        ggplot2::scale_color_manual(values = c("PASS" = "#1B9E77", "WARN" = "#D95F02"),
                                    guide = "none") +
        ggplot2::scale_y_continuous(limits = c(0, NA), expand = ggplot2::expansion(mult = c(0, 0.05))) +
        ggplot2::theme_classic(base_size = 11) +
        ggplot2::theme(
          axis.text.x = ggplot2::element_text(angle = 90, hjust = 1, vjust = 0.5, size = 7),
          plot.title = ggplot2::element_text(hjust = 0.5, face = "bold")
        ) +
        ggplot2::labs(
          title    = metric,
          subtitle = paste0(x@platform, "  |  cutoff: >", cutoff),
          x        = NULL,
          y        = paste0(metric, " Value")
        )
      
      # Label WARN samples (up to 20)
      warn_df <- df[df$QC == "WARN", ]
      if (nrow(warn_df) > 0 && nrow(warn_df) <= 20)
        p <- p + ggrepel::geom_text_repel(data = warn_df,
                    ggplot2::aes(label = SAMPLE_NAME), size = 2, color = "black")

      if (!is.null(out_prefix)) {
        metric_file <- paste0(out_prefix, "_CtrlMetrics_",
                              gsub(" ", "_", metric), ".pdf")
        tryCatch({
          # Auto-adjust width based on number of samples (min 5 inches, ~0.15 per sample)
          n_samples <- nrow(df)
          plot_width <- max(5, 2 + n_samples * 0.15)
          ggplot2::ggsave(filename = metric_file, plot = p, width = plot_width, height = 5)
          message("Plot saved to ", metric_file)
        }, error = function(e) warning("Could not save ", metric_file, ": ", conditionMessage(e)))
      }
      p
    })
    names(plots_out) <- available
    return(invisible(plots_out))

  } else {
    stop("Unknown plot type '", type, "'. Choose from: qc_bar, intensity, detection_pval, ",
         "probe_coverage, predicted_sex, ctrl_metrics, ctrl_metrics_detail.")
  }

  # =========================================================================
  # Save if outFile specified
  # =========================================================================
  if (!is.null(plot_obj) && !is.null(outFile)) {
    tryCatch({
      # Auto-adjust width for plots with many samples (detection_pval, probe_coverage)
      plot_width <- NULL
      if (type %in% c("detection_pval", "probe_coverage")) {
        n_samples <- nrow(qcm)
        plot_width <- max(5, 2 + n_samples * 0.15)
      }
      
      if (!is.null(plot_width)) {
        ggplot2::ggsave(filename = outFile, plot = plot_obj, width = plot_width, height = 5, ...)
      } else {
        ggplot2::ggsave(filename = outFile, plot = plot_obj, ...)
      }
      message("Plot saved to ", outFile)
    }, error = function(e) {
      warning("Could not save plot: ", conditionMessage(e))
    })
  }

  invisible(plot_obj)
})

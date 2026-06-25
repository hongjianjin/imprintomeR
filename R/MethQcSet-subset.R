#' Subset a MethQcSet by QC Status or Sample Names
#'
#' Create a valid `MethQcSet` containing only selected samples. By default, this
#' keeps samples with `Final.QC == "PASS"` from `qc_tables(x)[["QC_matrix"]]`,
#' making it convenient to carry QC-clean beta values into `as.ImprintomeSet()`.
#'
#' @param x A `MethQcSet` object.
#' @param final_qc Character vector of `Final.QC` values to keep. Defaults to
#'   `"PASS"`. Ignored when `sample_names` is supplied.
#' @param sample_names Optional character vector of sample names to keep.
#'
#' @return A valid `MethQcSet` subset to the requested samples.
#' @export
#'
#' @examples
#' \dontrun{
#' qcset_pass <- subsetMethQC(qcset)
#' beta_pass <- beta(qcset_pass)
#' }
subsetMethQC <- function(x, final_qc = "PASS", sample_names = NULL) {
  if (!methods::is(x, "MethQcSet")) {
    stop("x must be a MethQcSet object.", call. = FALSE)
  }

  meta_x <- meta(x)
  beta_x <- beta(x)
  sample_ids <- as.character(meta_x$Sample_Name)

  if (is.null(sample_names)) {
    qcm <- qc_tables(x)[["QC_matrix"]]
    if (!is.data.frame(qcm)) {
      stop("qc_tables(x)[[\"QC_matrix\"]] is required when sample_names is not supplied.", call. = FALSE)
    }
    if (!("Sample_Name" %in% colnames(qcm))) {
      stop("QC_matrix must contain a Sample_Name column.", call. = FALSE)
    }
    if (!("Final.QC" %in% colnames(qcm))) {
      stop("QC_matrix must contain a Final.QC column.", call. = FALSE)
    }

    keep_qc <- qcm[["Final.QC"]] %in% final_qc
    sample_names <- as.character(qcm[["Sample_Name"]][keep_qc])
  } else {
    sample_names <- as.character(sample_names)
  }

  sample_names <- unique(sample_names[!is.na(sample_names) & nzchar(sample_names)])
  sample_names <- sample_names[sample_names %in% colnames(beta_x)]
  sample_names <- sample_names[sample_names %in% sample_ids]

  if (length(sample_names) == 0L) {
    stop("No matching samples found for the requested MethQcSet subset.", call. = FALSE)
  }

  meta_sub <- meta_x[match(sample_names, sample_ids), , drop = FALSE]
  beta_sub <- beta_x[, sample_names, drop = FALSE]
  det_sub <- if (!is.null(detection_pval(x))) {
    detection_pval(x)[, sample_names, drop = FALSE]
  } else {
    NULL
  }

  qc_tables_sub <- lapply(qc_tables(x), function(tbl) {
    if (is.data.frame(tbl) && "Sample_Name" %in% colnames(tbl)) {
      idx <- match(sample_names, as.character(tbl$Sample_Name))
      tbl[idx[!is.na(idx)], , drop = FALSE]
    } else {
      tbl
    }
  })

  MethQcSet(
    meta = meta_sub,
    platform = platform(x),
    beta = beta_sub,
    detection_pval = det_sub,
    qc_tables = qc_tables_sub,
    aggregation_status = aggregation_status(x),
    qc_params = qc_params(x)
  )
}

# Auto-refactored from utilities2.R
# Module: aggregation

#' Calculate Row-Wise Group Means
#'
#' Computes per-row average values in `dat` for each `SAMPLE_GROUP` defined in
#' `meta`, matching samples by `meta$Sample_Name` to column names in `dat`.
#'
#' @param dat Numeric matrix/data frame with probes/features in rows and samples
#'   in columns.
#' @param meta Metadata data frame containing at least `Sample_Name` and
#'   `SAMPLE_GROUP`.
#'
#' @return Data frame of row-wise group means, one column per group.
#' @export
CalcAvgByGrp <- function(dat, meta = NULL) {
  resolved <- .resolve_beta_meta_inputs(dat, meta, require_meta = TRUE)
  dat <- resolved$beta
  meta <- resolved$meta

  # fucntion to calculate average value by Group
  # ID should match column name in datFile
  avg <- NULL
  cn <- NULL
  for (group in unique(meta$Sample_Group)) {
    cols_grp <- colnames(dat)[colnames(dat) %in% meta$Sample_Name[meta$Sample_Group == group]]
    if (length(cols_grp) == 1) {
      grp.mean <- dat[, cols_grp]
    } else {
      grp.mean <- rowMeans(dat[, cols_grp])
    }
    tmpDF <- data.frame(grp.mean)
    if (is.null(avg)) {
      avg <- tmpDF
      cn <- group
    } else {
      cn <- c(cn, group)
      avg <- cbind(avg, tmpDF)
    }
  }
  colnames(avg) <- cn # paste("grp_",cn,sep='')
  return(avg)
}
##################################################################
##################################################################

#' Aggregate Beta Matrix by Imprinting Locus
#'
#' Aggregates probe-level beta values into locus-level means by grouping probes
#' with the same chromosome, origin, and nearest gene annotation.
#'
#' @param beta Numeric beta matrix/data frame with probe IDs as row names and
#'   samples in columns.
#' @param probeset Character probeset key present in
#'   `inst/extdata/probesets_hg19.rds`.
#'
#' @return Data frame with aggregated loci as rows and samples as columns.
#' @export
AggregateByLocus <- function(beta, probeset="selected", probeset_data = NULL){
  beta <- .resolve_beta_input(beta)

  if (!(is.data.frame(beta) || is.matrix(beta))) {
    stop("beta must be a matrix or data.frame with probe IDs as row names.")
  }
  if (is.null(rownames(beta))) {
    stop("beta must include probe IDs as row names.")
  }
  if (!is.character(probeset) || length(probeset) != 1 || is.na(probeset) || !nzchar(probeset)) {
    stop("probeset must be a single non-empty character value.")
  }

  beta_df <- as.data.frame(beta, stringsAsFactors = FALSE, check.names = FALSE)
  numeric_cols <- vapply(beta_df, is.numeric, logical(1))
  if (!all(numeric_cols)) {
    dropped_cols <- colnames(beta_df)[!numeric_cols]
    warning(
      "AggregateByLocus: dropping non-numeric beta columns: ",
      paste(dropped_cols, collapse = ", "),
      call. = FALSE
    )
    beta_df <- beta_df[, numeric_cols, drop = FALSE]
  }
  if (ncol(beta_df) == 0L) {
    stop("beta must include at least one numeric sample column.")
  }

  if (!is.null(probeset_data)) {
    if (!is.data.frame(probeset_data)) {
      stop("probeset_data must be a data.frame when supplied.")
    }
    probeset1 <- probeset_data
  } else {
    probesets <- readRDS(.resolve_extdata_file("probesets_hg19.rds"))

    if (!(probeset %in% names(probesets))) {
      stop("Unavailable probeset: ", probeset)
    }

    probeset1 <- probesets[[probeset]]
  }
  required_cols <- c("NAME", "CHR", "ORIGIN", "Closest_TSS_gene_name")
  missing_cols <- setdiff(required_cols, colnames(probeset1))
  if (length(missing_cols) > 0) {
    stop("Probeset annotation missing required columns: ", paste(missing_cols, collapse = ", "))
  }
  rownames(probeset1) <- probeset1$NAME

  commonProbes <- intersect(rownames(beta_df), probeset1$NAME)
  if (length(commonProbes) == 0) {
    return(beta_df[0, , drop = FALSE])
  }

  beta_common <- beta_df[commonProbes, , drop = FALSE]
  group_key <- paste(
    probeset1[commonProbes, "CHR"],
    probeset1[commonProbes, "ORIGIN"],
    probeset1[commonProbes, "Closest_TSS_gene_name"],
    sep = "_"
  )

  split_idx <- split(seq_along(commonProbes), group_key)
  agg_list <- lapply(split_idx, function(idx) {
    apply(beta_common[idx, , drop = FALSE], 2, median, na.rm = TRUE)
  })

  result_mat <- do.call(rbind, agg_list)
  if (is.null(dim(result_mat))) {
    result_mat <- matrix(result_mat, nrow = 1)
  }
  rownames(result_mat) <- names(agg_list)
  colnames(result_mat) <- colnames(beta_common)

  as.data.frame(result_mat, stringsAsFactors = FALSE, check.names = FALSE)
}
##################################################################


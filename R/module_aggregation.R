# Auto-refactored from utilities2.R
# Module: aggregation

#' Calculate Row-Wise Group Means
#'
#' Computes per-row average values in `dat` for each `Sample_Group` defined in
#' `meta`, matching samples by `meta$Sample_Name` to column names in `dat`.
#'
#' @param dat Numeric matrix/data frame with probes/features in rows and samples
#'   in columns.
#' @param meta Metadata data frame containing at least `Sample_Name` and
#'   `Sample_Group`.
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
#' Aggregates probe-level beta values into locus-level medians. Probes are grouped
#' by chromosome, annotated parental origin and either their nearest gene
#' (`by = "gene"`) or their curated ICR (`by = "icr"`). Loci are returned in
#' genomic order: by chromosome (1-22, X, Y), then by the position of the locus'
#' first probe (`MAPINFO`); without `MAPINFO`, by label within a chromosome.
#'
#' @param beta Numeric beta matrix/data frame with probe IDs as row names and
#'   samples in columns.
#' @param probeset Character probeset key present in the bundled probeset file
#'   for `genome` (`probesets_<genome>.rds`).
#' @param genome Genome build of the probeset panels, `"hg19"` or `"hg38"`
#'   (default `"hg38"`).
#' @param by How probes are grouped into loci:
#'   - `"gene"` (default): by nearest gene (`Closest_TSS_gene_name`); loci are
#'     labelled `chr_origin_gene`.
#'   - `"icr"`: by curated ICR (`ICR_name`), so each ICR forms one locus whatever
#'     the nearest-gene labels of its probes; probes outside curated ICRs are
#'     grouped by nearest gene. Loci are labelled `chr_origin_ICR` (for example
#'     `chr11_paternal_H19/IGF2:IG-DMR`). Panels without an `ICR_name` column are
#'     grouped by nearest gene, with a message.
#' @param icr_only With `by = "icr"`, keep only the curated ICRs and leave out
#'   probes outside them (default `FALSE`). Radar plots use `by = "icr"` with
#'   `icr_only = TRUE`, one spoke per curated ICR.
#'
#' @return Data frame with aggregated loci as rows and samples as columns.
#' @export
AggregateByLocus <- function(beta, probeset="selected", genome = "hg38", by = c("gene", "icr"), icr_only = FALSE){
  by <- match.arg(by)
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
  if (!is.character(genome) || length(genome) != 1 || is.na(genome)) {
    stop("genome must be a single character value: 'hg19' or 'hg38'.")
  }
  genome <- match.arg(tolower(genome), c("hg19", "hg38"))

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

  probesets <- .load_probesets(genome)

  if (!(probeset %in% names(probesets))) {
    stop("Unavailable probeset for genome '", genome, "': ", probeset)
  }

  probeset1 <- probesets[[probeset]]
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

  locus_name <- as.character(probeset1[commonProbes, "Closest_TSS_gene_name"])
  if (by == "icr") {
    if ("ICR_name" %in% colnames(probeset1)) {
      icr <- as.character(probeset1[commonProbes, "ICR_name"])
      in_icr <- !is.na(icr) & nzchar(icr)
      locus_name[in_icr] <- icr[in_icr]
      if (isTRUE(icr_only)) {
        commonProbes <- commonProbes[in_icr]
        locus_name <- locus_name[in_icr]
        if (!length(commonProbes)) return(beta_df[0, , drop = FALSE])
      }
    } else {
      message("[AggregateByLocus] Probeset '", probeset, "' has no ICR_name column; loci are grouped by nearest gene.")
    }
  }
  beta_common <- beta_df[commonProbes, , drop = FALSE]
  group_key <- paste(
    probeset1[commonProbes, "CHR"],
    probeset1[commonProbes, "ORIGIN"],
    locus_name,
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

  # Genomic order: chromosome (1-22, X, Y, other), then the locus' first probe position, then label.
  loci <- rownames(result_mat)
  chr_of <- vapply(split_idx[loci], function(idx) as.character(probeset1[commonProbes[idx[1]], "CHR"]), "")
  chr_rank <- suppressWarnings(as.numeric(sub("^chr", "", chr_of, ignore.case = TRUE)))
  chr_key <- toupper(sub("^chr", "", chr_of, ignore.case = TRUE))
  chr_rank[is.na(chr_rank)] <- c(X = 23, Y = 24, M = 25, MT = 25)[chr_key[is.na(chr_rank)]]
  chr_rank[is.na(chr_rank)] <- 26
  start_of <- if ("MAPINFO" %in% colnames(probeset1)) {
    vapply(split_idx[loci], function(idx) {
      p <- suppressWarnings(as.numeric(probeset1[commonProbes[idx], "MAPINFO"]))
      if (all(is.na(p))) NA_real_ else min(p, na.rm = TRUE)
    }, numeric(1))
  } else {
    rep(NA_real_, length(loci))
  }
  result_mat <- result_mat[order(chr_rank, start_of, loci, na.last = TRUE), , drop = FALSE]

  as.data.frame(result_mat, stringsAsFactors = FALSE, check.names = FALSE)
}
##################################################################


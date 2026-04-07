# Auto-refactored from utilities2.R
# Module: aggregation

#' Calculate Row-Wise Group Means
#'
#' Computes per-row average values in `dat` for each `SAMPLE_GROUP` defined in
#' `meta`, matching samples by `meta$SAMPLE_NAME` to column names in `dat`.
#'
#' @param dat Numeric matrix/data frame with probes/features in rows and samples
#'   in columns.
#' @param meta Metadata data frame containing at least `SAMPLE_NAME` and
#'   `SAMPLE_GROUP`.
#'
#' @return Data frame of row-wise group means, one column per group.
CalcAvgByGrp <- function(dat, meta) {
  # fucntion to calculate average value by Group
  # ID should match column name in datFile
  avg <- NULL
  cn <- NULL
  for (group in unique(meta$SAMPLE_GROUP)) {
    cols_grp <- colnames(dat)[colnames(dat) %in% meta$SAMPLE_NAME[meta$SAMPLE_GROUP == group]]
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
AggregateByLocus <- function(beta, probeset="selected"){
  probesets <- readRDS("inst/extdata/probesets_hg19.rds")
   if (probeset %in% names(probesets)){
      probeset1 <- probesets[[probeset]]
      rownames(probeset1) <- probeset1$NAME
   } else {
      cat("\nERROR: unavailable probeset.\n")
      q("no")
  }
  commonProbes <- intersect(rownames(beta), probeset1$NAME)
  df <- beta[commonProbes, ]
  df$NAME <- commonProbes
  df$group <- paste(probeset1[commonProbes,"CHR"],probeset1[commonProbes,"ORIGIN"],probeset1[commonProbes,"Closest_TSS_gene_name"],sep='_')
  suppressMessages(suppressWarnings(library(dplyr)))
  suppressMessages(suppressWarnings(library(tidyr)))

    # Convert to long format
    df_long <- df %>% 
      tidyr::pivot_longer(cols = -c(NAME, group), names_to = "sample", values_to = "expression")

    # Group by 'group' and 'sample', then compute mean
    result <- df_long %>% 
      group_by(group, sample) %>% 
      summarise(mean_expression = mean(expression, na.rm = TRUE), .groups = 'drop')

    # Pivot back to wide format if needed
    result_wide <- result %>% 
      tidyr::pivot_wider(names_from = sample, values_from = mean_expression)
    result_wide <- as.data.frame(result_wide)  
    rownames(result_wide) <- result_wide$group
    result_wide$group <-NULL
  return(result_wide)

}
##################################################################

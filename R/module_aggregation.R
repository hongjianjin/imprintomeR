# Auto-refactored from utilities2.R
# Module: aggregation

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

AggregateByLocus <- function(beta, probeset="selected"){
  probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
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

calculate_global_clocks <- function(beta_matrix) {
  # Install the package if you haven't
  # BiocManager::install("methylclock")
  library(methylclock)
  library(tidyverse)
  # 1. Ensure the matrix is numeric
  beta_matrix <- as.matrix(beta_matrix)
  
  # 2. Estimate Chronological Age using Horvath's 353 CpGs
  # DNAmAge handles the background coefficients for you
  clock_results <- DNAmAge(beta_matrix)
  
  # 3. Extract just the Numeric Vector for Horvath Age
  # 'Horvath' is the standard output column name in this package
  global_clocks_age <- clock_results$Horvath
  
  return(global_clocks_age)
}

# Example Usage:
# my_bio_ages <- calculate_global_clocks(gtex_beta_data)
#================================================================



#' Calculate ImprintAge and Age Acceleration
#' @param beta_matrix Matrix of beta values (rows = CpGs, cols = samples)
#' @param icr_sites Vector of CpG IDs (cgXXXX) that reside within ICRs
#' @param global_clocks_age Numeric vector of previously calculated BioAge (e.g., Horvath Age)
#' @param trained_weights A named vector of weights for ICR sites (from a training set)
#' @return A dataframe with ImprintAge and Acceleration scores


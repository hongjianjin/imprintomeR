# Auto-refactored from utilities2.R
# Module: scoring

DetectMosaicism <- function(res_table, roi_ref_mean = 0.06, roi_ref_sd = 0.03) {
  # 1. Calculate Z-score based on healthy reference distribution
  res_table$IDS_Zscore <- (res_table$IDS - roi_ref_mean) / roi_ref_sd
  
  # 2. Define Mosaicism: 
  # High Z-score (>3) BUT still below the hard 'Alteration' threshold
  res_table$Is_Mosaic <- case_when(
     res_table$IDS >= 0.2 ~ "Constitutive",
    res_table$IDS_Zscore > 3 & res_table$IDS < 0.2 & res_table$consistency >0.8 ~ "High-Confidence Mosaic",
    res_table$IDS_Zscore > 2 & res_table$IDS < 0.2 & res_table$consistency >0.8 ~ "Possible Mosaic",
    TRUE ~ "Stable"
  )
  #The Inner Ellipse (Z < 2): "Stable (ROI)".
  #The Middle Ring (Z 2-3): "Possible Mosaic".
  #The Outer Ring (Z > 3): "Likely Mosaic".
  #Outside the Square: "Constitutive".

  # 3. Estimate Mosaic Percentage
  # Theory: A shift of 0.5 in Beta (from 0.5 to 0 or 1.0) = 100% cells altered.
  # Therefore: % Mosaic = (Abs Deviation from 0.5 / 0.5) * 100
  # Note: This takes the max deviation from either Pat or Mat median
  dev_pat <- abs(res_table$paternal_median - 0.5)
  dev_mat <- abs(res_table$maternal_median - 0.5)
  res_table$Mosaic_Pct_Est <- pmax(dev_pat, dev_mat) / 0.5 * 100
  
  return(res_table)
}


#================================================================

AnalyzeImprintStatus <- function(betaFile, metaFile, 
                                 probeset = probeset_options,
                                 ids_cutoff = 0.2) {
  suppressMessages(suppressWarnings(library(dplyr)))  
  
  # 1. Feature Alignment
  input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
  meta <- input[["meta"]]
  beta <- input[["beta"]]
  tmp  <- SubsetBeta_By_Probeset(beta, probeset = probeset, prefix = NULL)
  
  probesets <- tmp[["probesets"]]
  used <- tmp[["beta"]]
  used <- na.omit(used) 
  
  maternal_probes <- intersect(probesets$NAME[grep("maternal", probesets$ORIGIN)], rownames(used))
  paternal_probes <- intersect(probesets$NAME[grep("paternal", probesets$ORIGIN)], rownames(used))
  
  # --- NEW LOGIC: Handle Missing Probesets ---
  # If probes exist, subset them. If not, create a 0.5 matrix for all samples.
  if (length(maternal_probes) > 0) {
    maternal_beta <- used[maternal_probes, , drop = FALSE]
  } else {
    message("WARNING: No maternal probes found for [", probeset, "]. Defaulting to 0.5.")
    maternal_beta <- matrix(0.5, nrow = 1, ncol = ncol(used), 
                            dimnames = list("Placeholder_Mat", colnames(used)))
  }
  
  if (length(paternal_probes) > 0) {
    paternal_beta <- used[paternal_probes, , drop = FALSE]
  } else {
    message("WARNING: No paternal probes found for [", probeset, "]. Defaulting to 0.5.")
    paternal_beta <- matrix(0.5, nrow = 1, ncol = ncol(used), 
                            dimnames = list("Placeholder_Pat", colnames(used)))
  }
  # ------------------------------------------

  consistency_scores <- t(sapply(meta$SAMPLE_NAME, function(sid) {
    p_vals <- paternal_beta[, sid]
    m_vals <- maternal_beta[, sid]
    
    # Calculate directions
    p_med <- median(p_vals, na.rm = TRUE)
    m_med <- median(m_vals, na.rm = TRUE)
    p_dir <- if(p_med > 0.5) 1 else -1
    m_dir <- if(m_med > 0.5) 1 else -1
    
    # Calculate concordance (Handle length=0 to avoid NaN)
    p_concordance <- if(length(p_vals) > 0) sum((p_vals - 0.5) * p_dir >= 0, na.rm = TRUE) / length(p_vals) else 1
    m_concordance <- if(length(m_vals) > 0) sum((m_vals - 0.5) * m_dir >= 0, na.rm = TRUE) / length(m_vals) else 1
    
    return(c(pat_cons = p_concordance, 
             mat_cons = m_concordance, 
             consistency = mean(c(p_concordance, m_concordance))))
  }))

  consistency_df <- as.data.frame(consistency_scores)

  # 2. Metric Calculation (Median aggregation) 
  # Note: apply on 1-row matrix works correctly here
  mat_med <- apply(maternal_beta, 2, median, na.rm = TRUE)
  pat_med <- apply(paternal_beta, 2, median, na.rm = TRUE)

  # 3. Euclidean Distance (IDS) calculation
  ids <- sqrt((pat_med - 0.5)^2 + (mat_med - 0.5)^2)
  
  # 4. Directional Vector (Angle)
  radians <- atan2(mat_med - 0.5, pat_med - 0.5)
  degrees <- (radians * 180) / pi
  degrees <- (degrees + 360) %% 360 
  
  # 5. Define directional categories
  mechanism_labels <- c(
    "Pat-Gain", "Global-Hyper", "Mat-Gain", "Mat-Gain/Pat-Loss", 
    "Pat-Loss", "Global-Hypo", "Mat-Loss", "Pat-Gain/Mat-Loss"
  )

  shifted_degrees <- (degrees + 22.5) %% 360
  mechanism <- mechanism_labels[cut(shifted_degrees, 
                                    breaks = seq(0, 360, by = 45), 
                                    labels = FALSE, 
                                    include.lowest = TRUE)]

  # 6. Status and Confidence Logic
  status_conf_logic <- data.frame(ids = ids) %>%
    mutate(
      Status = if_else(ids >= ids_cutoff, "Imprinting Alteration", "Normal"),
      Confidence = case_when(
        ids < 0.1  ~ "High (Normal)",
        ids < 0.2  ~ "Low (Normal)",
        ids < 0.4  ~ "Moderate (Alteration)",
        TRUE       ~ "High (Alteration)"
      ),
      Final_Mechanism = if_else(ids < 0.2, "ROI", as.character(mechanism))
    )

  # 7. Metadata selection
  cols_to_keep <- intersect(colnames(meta), c("SAMPLE_NAME", "SAMPLE_GROUP", "ID2"))
  meta_selected <- meta[, cols_to_keep, drop = FALSE]

  # 8. Final Results Assembly
  res <- data.frame(
    meta_selected,
    probeset        = probeset,
    paternal_median = round(pat_med, 3),
    maternal_median = round(mat_med, 3),
    consistency_df,
    IDS             = round(ids, 3),
    Angle           = round(degrees, 1),
    Mechanism       = status_conf_logic$Final_Mechanism,
    Status          = status_conf_logic$Status,
    Confidence      = status_conf_logic$Confidence,
    stringsAsFactors = FALSE
  )

  return(res)
}
#=====================================

AnalyzeImprintStatus0 <- function(betaFile,  metaFile, 
                                  probeset = probeset_options,
                                 ids_cutoff = 0.2) {
   suppressMessages(suppressWarnings(library(dplyr)))  
 
  #probeset <- match.arg(probeset)
  # 1. Feature Alignment
  input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
  meta <- input[["meta"]]
  beta <- input[["beta"]]
  tmp  <- SubsetBeta_By_Probeset(beta, probeset=probeset,prefix=NULL)
  probesets <- tmp[["probesets"]]
  used <- tmp[["beta"]]
  used <- na.omit(used) # removed NA
  all_probes <- intersect(probesets$NAME, rownames(used))
  maternal_probes <- intersect(probesets$NAME[grep("maternal", probesets$ORIGIN)], rownames(used))
  paternal_probes <- intersect(probesets$NAME[grep("paternal", probesets$ORIGIN)], rownames(used))
  
  maternal_beta <- used[maternal_probes, ]
  paternal_beta <- used[paternal_probes, ]

  consistency_scores <- t(sapply(meta$SAMPLE_NAME, function(sid) {
    # Check for Probe-Level Consistency in Mosaic Samples
    # Metric: We calculate the Percentage of Concordant Probes.Threshold: 
    # If >80% of probes in the signature are shifting in the same direction (e.g., all >0.5), 
    #   it confirms a high-confidence biological event.    

      # 1. Get raw betas for this sample
      p_vals <- maternal_beta[, sid]
      m_vals <- paternal_beta[, sid]
      
      # 2. Determine the direction of the median shift
      p_dir <- if(median(p_vals, na.rm=TRUE) > 0.5) 1 else -1
      m_dir <- if(median(m_vals, na.rm=TRUE) > 0.5) 1 else -1
      
      # 3. Calculate % of probes matching that direction
      p_concordance <- sum((p_vals - 0.5) * p_dir > 0, na.rm=TRUE) / length(p_vals)
      m_concordance <- sum((m_vals - 0.5) * m_dir > 0, na.rm=TRUE) / length(m_vals)
      
      # Return the average concordance across both alleles
      return(c(pat_cons=p_concordance,mat_cons=m_concordance, consistency=mean(c(p_concordance, m_concordance))))
    }))

 consistency_df <- as.data.frame(consistency_scores)

  if (length(maternal_probes) < 2) {
    cat("\nERROR: less than 2 probes in maternal loci..\n")
    q("no")
  }
  if (length(paternal_probes) < 2) {
    cat("\nERROR: less than 2 probes in paternal loci..\n")
    q("no")
  }

  if (!all(c("maternal", "paternal") %in% unique(probesets$ORIGIN))) {
    cat("\nERROR: Invalid ORIGIN column in probeset[",probeset,"].\n")
    stop("exit.")
  }

    # 2. Metric Calculation (Median aggregation) 
  mat_med <- apply(maternal_beta, 2, median, na.rm = TRUE)
  # maternal_sd <- apply(maternal_beta, 2, sd)
  pat_med <- apply(paternal_beta, 2, median, na.rm = TRUE)
   #paternal_sd <- apply(paternal_beta, 2, sd)


  # 3. Euclidean Distance (IDS) calculation
  # Distance from the ideal hemimethylated state (0.5, 0.5)
  ids <- sqrt((pat_med - 0.5)^2 + (mat_med - 0.5)^2)
  
  # 4. Directional Vector (Angle)
  # atan2(y, x) -> atan2(mat_dev, pat_dev)
  radians <- atan2(mat_med - 0.5, pat_med - 0.5)
  degrees <- (radians * 180) / pi
  degrees <- (degrees + 360) %% 360 # Normalize to 0-360 range
  
  # 5. Define directional categories (Mechanism)
  # We use a cleaner break system. Note: Pat-Gain spans the 360/0 degree line.
  mechanism_labels <- c(
    "Pat-Gain", "Global-Hyper", "Mat-Gain", "Mat-Gain/Pat-Loss", 
    "Pat-Loss", "Global-Hypo", "Mat-Loss", "Pat-Gain/Mat-Loss"
  )

  # Use findInterval or cut to assign initial directional mechanism
  # We shift the degrees by 22.5 to center the bins on the axes (0, 45, 90...)
  shifted_degrees <- (degrees + 22.5) %% 360
  mechanism <- mechanism_labels[cut(shifted_degrees, 
                                    breaks = seq(0, 360, by = 45), 
                                    labels = FALSE, 
                                    include.lowest = TRUE)]

  # 6. Define Status and Confidence with combined descriptive labels
  # This resolves the "High" vs "High" ambiguity
  status_conf_logic <- data.frame(ids = ids) %>%
    mutate(
      Status = if_else(ids >= ids_cutoff, "Imprinting Alteration", "Normal"),
      Confidence = case_when(
        ids < 0.1  ~ "High (Normal)",
        ids < 0.2  ~ "Low (Normal)",
        ids < 0.4  ~ "Moderate (Alteration)",
        TRUE       ~ "High (Alteration)"
      ),
      # Prioritize ROI: If IDS is very low, the mechanism is "Retention"
      Final_Mechanism = if_else(ids < 0.2, "ROI", as.character(mechanism))
    )

  # 7. Metadata selection (Defensive programming)
  cols_to_keep <- intersect(colnames(meta), c("SAMPLE_NAME", "SAMPLE_GROUP", "ID2"))
  meta_selected <- meta[, cols_to_keep, drop = FALSE]

  # 8. Final Results Assembly
  res <- data.frame(
    meta_selected,
    probeset        = probeset,
    paternal_median = round(pat_med, 3),
    maternal_median = round(mat_med, 3),
    consistency_df,
    IDS             = round(ids, 3),
    Angle           = round(degrees, 1),
    Mechanism       = status_conf_logic$Final_Mechanism,
    Status          = status_conf_logic$Status,
    Confidence      = status_conf_logic$Confidence,
    stringsAsFactors = FALSE
  )

  return(res)
}

#================================================================

Survey_Global_Imprinting <- function(beta, sampleID,probeset=c("classifier2","classifier3","selected","signature_hc"), min_probes = 10, ids_cutoff=0.2) {
  suppressMessages(suppressWarnings(library("dplyr")))
  library(stringr)
  probeset <- match.arg(probeset)
  #================================================================
  # prepare chromosome
  beta <- as.data.frame(beta)
  probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
    if (probeset %in% names(probesets)) {
      probes <- probesets[[probeset]]
    } else {
      cat("\nERROR: unavailable probeset & probes not given.\n")
      q("no")
    }
    anno <- probes[,c("CHR","MAPINFO","Closest_TSS_gene_name","ORIGIN")]   
    colnames(anno)[3] <- "GENE"
    rownames(anno) <- probes$NAME

  common_probes <- intersect(rownames(anno), rownames(beta))
  beta <- beta[common_probes, ]
  #================================================================
  #================================================================
  beta$Probe <- rownames(beta)
  beta$Chromosome <-  anno[common_probes,"CHR"]
  beta$ORIGIN <-  anno[common_probes,"ORIGIN"]

  # 1. Filter for the specific sample
  sample_data <- beta[, c("Probe", "Chromosome","ORIGIN",sampleID) ]
  colnames(sample_data)[ncol(sample_data)] <- "beta"
  # print(head(sample_data))

  # 2. Group by Chromosome and calculate vectors
  # Assuming your 'data' has columns: Chromosome, ORIGIN (maternal/paternal), and beta
  chrom_survey <- sample_data %>%
    group_by(Chromosome) %>%
    summarise(
      n_mat = sum(ORIGIN %in%  "maternal", na.rm=TRUE),
      n_pat = sum(ORIGIN %in% "paternal", na.rm=TRUE),
      # Calculate Maternal Median ONLY if >= 10 probes
      maternal_median = if(n_mat >= min_probes) {
                    median(beta[ORIGIN %in% "maternal"], na.rm = TRUE)
                } else { 0.5 },
                
      # Calculate Paternal Median ONLY if >= 10 probes
      paternal_median = if(n_pat >= min_probes) {
                    median(beta[ORIGIN %in% "paternal"], na.rm = TRUE)
                } else { 0.5 },
      # Maternal Consistency
      mat_cons = if(any(ORIGIN %in% "maternal")) {
        m_vals <- beta[ORIGIN %in% "maternal"]
        m_dir  <- if(median(m_vals, na.rm=TRUE) > 0.5) 1 else -1
        sum((m_vals - 0.5) * m_dir > 0, na.rm=TRUE) / sum(ORIGIN %in% "maternal")
      } else { 0 },
      
      # Paternal Consistency
      pat_cons = if(any(ORIGIN %in% "paternal")) {
        p_vals <- beta[ORIGIN %in% "paternal"]
        p_dir  <- if(median(p_vals, na.rm=TRUE) > 0.5) 1 else -1
        sum((p_vals - 0.5) * p_dir > 0, na.rm=TRUE) / sum(ORIGIN %in% "paternal")
      } else { 0 },     
      max_cons = pmax(mat_cons, pat_cons, na.rm = TRUE), 
      n_total = n(),
      .groups = 'drop'
    ) %>%
    filter(n_mat >= min_probes | n_pat >= min_probes) %>%
    mutate(
      # Calculate the Vector components
      mat_dev = maternal_median - 0.5,
      pat_dev = paternal_median - 0.5,
      IDS = sqrt(mat_dev^2 + pat_dev^2),
      # ANGLE LOGIC: Handling cases with only 1 allele type
      Angle = case_when(
        n_pat == 0 & mat_dev > 0 ~ 90,   # Pure Maternal Gain
        n_pat == 0 & mat_dev < 0 ~ 270,  # Pure Maternal Loss
        n_mat == 0 & pat_dev > 0 ~ 0,    # Pure Paternal Gain
        n_mat == 0 & pat_dev < 0 ~ 180,  # Pure Paternal Loss
        TRUE ~ (atan2(mat_dev, pat_dev) * 180 / pi + 360) %% 360
      )
    )
    #================================================================
      mechanism_labels <- c(
        "Pat-Gain", "Global-Hyper", "Mat-Gain", "Mat-Gain/Pat-Loss", 
        "Pat-Loss", "Global-Hypo", "Mat-Loss", "Pat-Gain/Mat-Loss"
      )    
      shifted_degrees <- (chrom_survey$Angle + 22.5) %% 360
      mechanism <- mechanism_labels[cut(shifted_degrees, 
                                    breaks = seq(0, 360, by = 45), 
                                    labels = FALSE, 
                                    include.lowest = TRUE)]
    #================================================================
    
    
    status_logic <- data.frame(ids = chrom_survey$IDS) %>%
    mutate(
      Status = if_else(ids >= ids_cutoff, "Imprinting Alteration", "Normal"),
      Confidence = case_when(
        ids < 0.1  ~ "High (Normal)",
        ids < 0.2  ~ "Low (Normal)",
        ids < 0.4  ~ "Moderate (Alteration)",
        TRUE       ~ "High (Alteration)"
      ),
      # Prioritize ROI: If IDS is very low, the mechanism is "Retention"
      Mechanism = if_else(ids < 0.2, "ROI", as.character(mechanism))
    )
  status_logic$ids <- NULL
  chrom_survey  <- cbind(chrom_survey,status_logic )
  chrom_survey <- chrom_survey %>%
                   mutate(Chromosome = factor(Chromosome, levels = str_sort(unique(Chromosome), numeric = TRUE))) %>%  
                   arrange(Chromosome)

  return(chrom_survey)
}

#================================================================

Survey_Global_Imprinting_Batch <- function(betaFile, metaFile,
                                          subset = "all", 
                                          probeset = c("classifier2", "classifier3", "selected", "signature_hc"), 
                                          min_probes = 10, 
                                          ids_cutoff = 0.2) {
  
  suppressMessages(suppressWarnings({
    library(dplyr)
    library(tidyr)
    library(stringr)
    library(data.table)
  }))
  
  probeset <- match.arg(probeset)
  
  input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
  beta0 <- input[["beta"]]
  meta <- input[["meta"]]
  tmp  <- SubsetBeta_By_Probeset(beta0, probeset=probeset,prefix=NULL)

  # 1. Load Beta Data (Supports RDS and TXT/TSV)
  beta <- tmp[["beta"]]
  beta <- na.omit(beta) # removed NA

  # 2. Load Annotation
  anno_path <- "/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds"
  probesets <- readRDS(anno_path)
  
  probes_info <- probesets[[probeset]]
  anno <- probes_info %>%
    select(NAME, CHR, ORIGIN) %>%
    as.data.frame()
  rownames(anno) <- anno$NAME

  # 3. Filter by Subset (Chromosome)
  if (subset != "all") {
    anno <- anno %>% filter(CHR == subset)
  }

  # 4. Align and Pivot to Long Format
  common_probes <- intersect(rownames(anno), rownames(beta))
  
  # Merging annotation with beta values
  combined_data <- beta[common_probes, , drop = FALSE] %>%
    mutate(Probe = common_probes,
           Chromosome = anno[common_probes, "CHR"],
           ORIGIN = anno[common_probes, "ORIGIN"]) %>%
    # Transform table so we have one row per Probe-Sample pair
    pivot_longer(cols = -c(Probe, Chromosome, ORIGIN), 
                 names_to = "SAMPLE_NAME", 
                 values_to = "beta_val")

  # 5. Global Calculation (Group by Sample AND Chromosome)
  results <- combined_data %>%
    group_by(SAMPLE_NAME, Chromosome) %>%
    summarise(
      n_mat = sum(ORIGIN == "maternal", na.rm = TRUE),
      n_pat = sum(ORIGIN == "paternal", na.rm = TRUE),
      maternal_median = if(n_mat >= min_probes) median(beta_val[ORIGIN == "maternal"], na.rm = TRUE) else 0.5,
      paternal_median = if(n_pat >= min_probes) median(beta_val[ORIGIN == "paternal"], na.rm = TRUE) else 0.5,
      .groups = 'drop'
    ) %>%
    filter(n_mat >= min_probes | n_pat >= min_probes) %>%
    mutate(
      mat_dev = maternal_median - 0.5,
      pat_dev = paternal_median - 0.5,
      IDS = sqrt(mat_dev^2 + pat_dev^2),
      Angle = (atan2(mat_dev, pat_dev) * 180 / pi + 360) %% 360
    )

  # 6. Apply Mechanism Labels
  mechanism_labels <- c("Pat-Gain", "Global-Hyper", "Mat-Gain", "Mat-Gain/Pat-Loss", 
                        "Pat-Loss", "Global-Hypo", "Mat-Loss", "Pat-Gain/Mat-Loss")
  


  report <- results %>%
    mutate(
      mechanism_idx = cut((Angle + 22.5) %% 360, breaks = seq(0, 360, by = 45), labels = FALSE, include.lowest = TRUE),
      raw_mech = mechanism_labels[mechanism_idx],
      Status = if_else(IDS >= ids_cutoff, "Alteration", "Normal"),
      Mechanism = if_else(IDS < 0.2, "ROI (Retention)", raw_mech),
      Chromosome = factor(Chromosome, levels = str_sort(unique(Chromosome), numeric = TRUE))
    ) %>%
    select(SAMPLE_NAME, Chromosome, n_mat, n_pat, IDS, Status, Mechanism, Angle) %>%
    arrange(SAMPLE_NAME, Chromosome)

    cols_to_keep <- intersect(colnames(meta), c("SAMPLE_NAME", "SAMPLE_GROUP", "ID2"))
    meta_selected <- meta[, cols_to_keep, drop = FALSE]
  
  # Join metadata to the report
  final_report <- report %>%
    left_join(meta_selected, by = "SAMPLE_NAME") %>%
    select(SAMPLE_NAME, any_of(c("SAMPLE_GROUP", "ID2")), Chromosome, n_mat, n_pat, IDS, Status, Mechanism, Angle) %>%
    arrange(SAMPLE_NAME, Chromosome)

  return(final_report)
}
#================================================================

#================================================================

validate_imprinting_fit <- function(purity, obs_dev, sample_ids) {
  library(ggplot2)
  # 1. Calculate Expected Deviation based on the "Perfect LOI" model
  # D_exp = 0.5 * Purity
  exp_dev <- 0.5 * purity
  
  # 2. Calculate the Residual (The "Mismatch")
  # A positive residual means more deviation than expected (Higher than 100% LOI in tumor)
  # A negative residual means less deviation (Partial LOI or stochastic drift)
  residual <- obs_dev - exp_dev
  
  # 3. Calculate Consistency Score (0 to 1, where 1 is a perfect fit)
  # We use a simple Gaussian-like decay for the score
  consistency_score <- exp(-(residual^2) / 0.01) 
  
  results <- data.frame(
    SampleID = sample_ids,
    Purity = purity,
    Observed_Dev = obs_dev,
    Expected_Dev = exp_dev,
    Residual = round(residual, 3),
    Fit_Score = round(consistency_score, 3)
  )
  
  # 4. Flagging Logic
  results$Status <- ifelse(results$Residual < -0.1, "Partial LOI / Drift",
                    ifelse(results$Residual > 0.1, "Purity Underestimated", "Consistent LOI"))
  
  return(results)
}

if(F){
  # --- Example Usage ---
  samples <- c("Sample_A", "Sample_B", "Sample_C")
  purity_vals <- c(0.70, 0.90, 0.40)
  observed_devs <- c(0.40, 0.45, 0.05) # 40%, 45%, 5%

  fit_data <- validate_imprinting_fit(purity_vals, observed_devs, samples)
  print(fit_data) 

}

#================================================================

calculate_imprint_age <- function(beta_matrix, icr_sites, global_clocks_age, trained_weights = NULL) {
  library(dplyr)
  library(matrixStats)
  # 1. Subset for ICR-specific sites
  common_sites <- intersect(rownames(beta_matrix), icr_sites)
  icr_beta <- beta_matrix[common_sites, ]
  
  # 2. If no weights are provided, we use a Z-score deviation model
  # This measures how 'disordered' the ICRs are compared to a young/normal baseline
  if (is.null(trained_weights)) {
    message("No trained weights provided. Calculating Deviation-based ImprintAge...")
    
    # Deviation from the 'perfect' 0.5 methylation state
    # High deviation in specific directions correlates with epigenetic fatigue
    imprint_age_score <- colMeans(abs(icr_beta - 0.5), na.rm = TRUE)
    
    # Scale to a year-based metric for comparison (heuristic scaling)
    imprint_age_years <- (imprint_age_score * 100) + 20 
  } else {
    # 3. Use Linear Model: Age = intercept + sum(Beta_i * Weight_i)
    # This is the standard Horvath-style calculation
    imprint_age_years <- colSums(icr_beta * trained_weights[common_sites], na.rm = TRUE)
  }
  
  # 4. Calculate Age Acceleration (The delta)
  age_acceleration <- imprint_age_years - global_clocks_age
  
  results <- data.frame(
    SampleID = colnames(beta_matrix),
    Global_BioAge = global_clocks_age,
    ImprintAge = round(imprint_age_years, 2),
    Age_Acceleration = round(age_acceleration, 2)
  )
  
  # Categorize results
  results$Aging_Status <- ifelse(results$Age_Acceleration > 5, "Accelerated",
                          ifelse(results$Age_Acceleration < -5, "Decelerated", "Normal"))
  
  return(results)
}

# --- Example Usage ---
# icr_sites <- c("cg000002", "cg000005", ...) # Sites inside ICR boundaries
# global_ages <- c(45, 62, 30) # Ages calculated via standard Horvath/Hannum clocks
# clock_results <- calculate_imprint_age(my_betas, icr_sites, global_ages)

#================================================================
if(F){

  library(ggplot2)
  plot_imprint_clock <- function(df) {
    ggplot(df, aes(x = Global_BioAge, y = ImprintAge)) +
      geom_point(aes(color = Aging_Status), size = 3) +
      geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "grey") + # The "Perfect Match" line
      geom_smooth(method = "lm", color = "blue", se = FALSE) +
      scale_color_manual(values = c("Accelerated" = "red", "Normal" = "black", "Decelerated" = "green")) +
      labs(
        title = "ImprintAge Clock: ICR Aging vs. Global BioAge",
        subtitle = "Points above the line indicate Accelerated Imprinting Decay",
        x = "Global Biological Age (Standard Clock)",
        y = "ImprintAge (ICR-Specific Clock)"
      ) +
      theme_classic()
  }
}

#================================================================
library(ComplexHeatmap)
library(ConsensusClusterPlus)
library(circlize)

#' Pan-Imprint Clustering (PIC) Module
#' @param icr_beta_matrix Matrix of beta values filtered for ICR sites only
#' @param results_dir Directory to save consensus plots
#' @return A list containing cluster assignments and the signature heatmap

run_pic_signature_finder <- function(icr_beta_matrix, results_dir = "PIC_Output") {
  
  # 1. Transform data to 'Deviation Space'
  # We care about the distance from 0.5 (balanced imprinting)
  pic_matrix <- abs(icr_beta_matrix - 0.5)
  
  # 2. Consensus Clustering
  # This determines the stability of the clusters
  results <- ConsensusClusterPlus(
    d = as.matrix(pic_matrix),
    maxK = 6,
    reps = 100,
    pItem = 0.8,
    clusterAlg = "hc",
    distance = "pearson",
    title = results_dir,
    plot = "pdf"
  )
  
  # 3. Extract the optimal Cluster (e.g., K=3)
  # In a real scenario, you'd pick K based on the CDF plot provided by ConsensusClusterPlus
  optimal_k <- 3
  cluster_assignments <- results[[optimal_k]][["consensusClass"]]
  
  # 4. Generate the Signature Heatmap
  col_fun = colorRamp2(c(0, 0.25, 0.5), c("white", "orange", "red"))
  
  hm <- Heatmap(
    pic_matrix,
    name = "Deviation from 0.5",
    col = col_fun,
    column_split = cluster_assignments,
    show_row_names = FALSE,
    column_title = paste("PIC Signatures (K =", optimal_k, ")"),
    clustering_distance_columns = "pearson"
  )
  
  return(list(clusters = cluster_assignments, heatmap = hm))
}
#================================================================


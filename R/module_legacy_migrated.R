# Auto-migrated legacy functions
# Module: legacy-migrated
# NOTE: Functions in this file preserve legacy behavior and are
# intentionally copied without formula/threshold changes.

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

  consistency_scores <- t(sapply(meta$Sample_Name, function(sid) {
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
  cols_to_keep <- intersect(colnames(meta), c("Sample_Name", "Sample_Group", "ID2"))
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


AnalyzeImprintStatusV2 <- function(betaFile, 
                                 metaFile, probeset = c("selected", "chr11p15"),
                                 ids_cutoff = 0.2, prefix=NULL) {
   suppressMessages(suppressWarnings(library(dplyr)))  

  probeset <- match.arg(probeset)
  # 1. Feature Alignment
  input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
  input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
  beta <- input[["beta"]]
  meta <- input[["meta"]]
  tmp  <- SubsetBeta_By_Probeset(beta, probeset=probeset,prefix=NULL)
  probesets <- tmp[["probesets"]]
  used <- tmp[["beta"]]
  used <- na.omit(used) # removed NA
  all_probes <- intersect(probesets$NAME, rownames(used))
  maternal_probes <- intersect(probesets$NAME[grep("maternal", probesets$ORIGIN)], rownames(used))
  paternal_probes <- intersect(probesets$NAME[grep("paternal", probesets$ORIGIN)], rownames(used))
  maternal_beta <- used[maternal_probes, ]
  paternal_beta <- used[paternal_probes, ]

  consistency_scores <- t(sapply(meta$Sample_Name, function(sid) {
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
  cols_to_keep <- intersect(colnames(meta), c("Sample_Name", "Sample_Group", "ID2"))
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


AnnotateProbesetCytoband <- function(probeset, assay = "EPICV1", version = "HG19", verbose = FALSE, file = NULL,uniqColumn= TRUE) {
  suppressMessages(library("bedr"))
  if (!check.binary("bedtools")) {
    cat("\nERROR: bedtools not available.\n")
    q("no")
  }

  cytobandFile <- paste0("/home/hjin/projects/ImprintomeR/package/inst/extdata/", tolower(version), "_cytoband_arm.txt")
  if (!file.exists(cytobandFile)) {
    cat("\nERROR: cytoban file is missing.\n")
    q("no")
  }
  cytoband <- read.table(cytobandFile, sep = "\t", header = TRUE, fill = TRUE, stringsAsFactors = FALSE, quote = "", row.names = NULL, check.names = F, comment.char = "")
  cytoband_beds <- paste(cytoband[, 1], ":", cytoband[, 2], "-", cytoband[, 3], sep = "")
  rownames(cytoband) <- cytoband_beds
  x <- is.valid.region(cytoband_beds, verbose = verbose)
  if (sum(x) != length(x)) {
    cat("\nWARN: some invalid bed coordidates in ", basename(cytobandFile), "\n")
  }
  cytoband_beds_used <- bedr.sort.region(cytoband_beds[x], verbose = verbose)
  chr <- paste0("CHR_", toupper(version))
  mapinfo <- paste0("MAPINFO_", toupper(version))
    if (! all(grepl("^chr",probeset[[chr]]))){
     cat("\nINFO: add chr to in probeset input.")
     probeset[[chr]] <-paste("chr", probeset[[chr]], sep = "")
    }
  input_beds <- paste(probeset[[chr]], ":", probeset[[mapinfo]] - 1, "-", probeset[[mapinfo]] + 1, sep = "")
  rownames(probeset) <- input_beds
  y <- is.valid.region(input_beds, verbose = verbose)
  input_beds_used <- bedr.sort.region(input_beds[y], verbose = verbose)
  if (sum(y) != length(y)) {
    cat("\nWARN: some invalid bed coordidates in ", basename(outFile), "\n")
  }
  # check overalapping coordinates
  a.intb <- bedr(
    input = list(a = input_beds_used, b = cytoband_beds_used),
    method = "intersect", params = "-loj -sorted", verbose = F
  )

  idx1 <- a.intb$index
  idx2 <- paste(a.intb$V4, ":", a.intb$V5, "-", a.intb$V6, sep = "")
  res2 <- data.frame(probeset[idx1, ], ARM = cytoband[idx2, "Arm"])
  cat("\ndim:", nrow(res2), "nrow x", ncol(res2), "ncol")
  res3 <- merge(x = probeset, y = res2, by.x = "NAME", by.y = "NAME", all.x = TRUE)
  if (uniqColumn == TRUE){
 cat("\n Searching dupicated column names... ")
  tmp <- table(gsub("\\.[xy]$","", colnames(res3)))
  dupColNames<- names(tmp)[tmp>1]
  if (length(dupColNames) >0){
      cat("\n\tFound ",length(dupColNames),":", dupColNames)
      cat("\n\tOrig. ncol: ",ncol(res3))
      toDel <- paste( dupColNames, ".y",sep="")
      res3uniq<- res3[, colnames(res3)[! colnames(res3) %in% toDel]]
      for(n in dupColNames) {
      colnames(res3uniq) <- gsub(paste0(n,"\\.x"),n,colnames(res3uniq))
      }
      res3 <- res3uniq
      cat("\n\tUniq. ncol: ",ncol(res3))
  }
}
  print(colnames(res3))
  res3 <- res3[order(res3[[chr]]), ]
  if (!is.null(file)) {
    # file <- paste0(prefix, ".annotatedBy", assayType, "_cytoband.", cytoband.used, "_na.txt")
    write.table(res3, file, sep = "\t", quote = F, row.names = F, col.names = T)
    cat("\n\t", basename(file), "[saved,nrow=", nrow(res3), "]")
  }
  return(res3)
}
# ================================================================

# ================================================================

BetaBeePlot_line <- function(beta, meta, SAMPLEID = "Sample_Name", outFile = NULL, alpha = 1,usedProbes=NULL) {
  # https://r-charts.com/distribution/ggbeeswarm/
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))

  options(ggplot2.verbose = FALSE)
  dotSize <- max(0.3, 1 - log10(nrow(beta)+1) / 5)
  TargetIDs <- rownames(beta)
  validIds <- intersect(meta$Sample_Name, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$Sample_Name %in% validIds]
  if (length(validIds) ==1) {
    beta=data.frame(beta[, validIds])
    rownames(beta) <- rownames(beta)
    colnames(beta) <- validIds
    meta <- meta[validIds, ]
  }else  if (length(validIds) > 1) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$Sample_Name. \n")
    return(NULL)
  }
  colnames(beta) <- newIDs

  meta <- meta[order(meta$Sample_Group), ] # order GROUP
  orderedIDs <- meta$SAMPLEID # order SMAPLEID by GROUP
  rownames(meta) <- as.character(meta$SAMPLEID)
  beta <- beta[, orderedIDs]
  if(!is.null(usedProbes))  {
    beta <- beta[intersect(usedProbes, rownames(beta)),] # subset beta matrix by usedProbes
  }
  beta$Probe <- rownames(beta)

  suppressMessages({
     used <- reshape2::melt(beta, id.vars = "Probe",variable.name = "ID",value.name = "value")
  })
  used$value <- as.numeric(as.character(used$value))
  

  cat("\n generate dotplot ...\n")
  pg <- ggplot(used, aes(x = ID, y = value), alpha = alpha) +
    geom_point(cex = dotSize) +
    geom_line(aes(group = Probe), alpha = 0.5) +
    theme_classic(base_size = 10) +
    labs(y = "methylation level", x = "") +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) +
    theme(legend.position = "none")

  imgHeight <- 5 + max(nchar(meta$SAMPLEID)) / 20
  #plots <- cowplot::plot_grid(pg1, pg2, ncol = 2, rel_widths = c(8, 1))
  if (!is.null(outFile)) {
    if (ncol(beta) > 20) {
      imgWidth <- 5 + ncol(beta) / 5 + nrow(beta) / 400
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = F)
    } else {
      imgWidth <- min(5 + ncol(beta) / 10 + nrow(beta) / 400, 45)
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = T)
    }
    cat("\n\t", basename(outFile), "[saved]")
  }
  options(ggplot2.verbose = TRUE)
  return(pg)
}
##################################################################

BetaBeePlot_line_color <- function(beta, meta, SAMPLEID = "Sample_Name", colorGroup="MOM",heteGermGroup="germline", outFile = NULL, alpha = 0.5,low_cutoff=0.3,high_cutoff=0.7) {
  # https://r-charts.com/distribution/ggbeeswarm/
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))

  options(ggplot2.verbose = FALSE)
  dotSize <- max(0.3, 1 - log10(nrow(beta)+1) / 5)
  TargetIDs <- rownames(beta)
  validIds <- intersect(meta$Sample_Name, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$Sample_Name %in% validIds]
  if (length(validIds) ==1) {
    beta=data.frame(beta[, validIds])
    rownames(beta) <- rownames(beta)
    colnames(beta) <- validIds
    meta <- meta[validIds, ]
  }else  if (length(validIds) > 1) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$Sample_Name. \n")
    return(NULL)
  }
  colnames(beta) <- newIDs

  meta <- meta[order(meta$Sample_Group), ] # order GROUP
  orderedIDs <- meta$SAMPLEID # order SMAPLEID by GROUP
  rownames(meta) <- as.character(meta$SAMPLEID)
  beta <- beta[, orderedIDs]
  beta$Probe <- rownames(beta)

  beta <- data.frame(beta)
  
  ctrls <- meta[grep(paste0(colorGroup,"$"), meta$Sample_Group),"SAMPLEID"]
  cat("\nInfo: colorGroup sample.", ctrls,"\n")
  if(length(ctrls)>1){
    ctrls_mean <- rowMeans(beta[,ctrls])
  }else{
    ctrls_mean <- as.numeric(beta[,ctrls])
  }
  breaks <- c(0, low_cutoff, high_cutoff, 1)
  labels <- c("BB", "AB", "AA")
  beta$GENOTYPE <- cut(ctrls_mean, breaks = breaks, labels = labels, include.lowest = TRUE)


  if(! is.null(heteGermGroup)){
    hetes <- meta[grep(paste0(heteGermGroup,"$"), meta$Sample_Group),"SAMPLEID"]
    cat("\nInfo: heterozygous Germline Group sample.", hetes,"\n")
    if(length(ctrls)>1){
    hetes_mean <- rowMeans(beta[,hetes])
    }else{
      hetes_mean <- as.numeric(beta[,hetes])
    }
      hetes_breaks <- c(0, low_cutoff, high_cutoff, 1)
      hetes_labels <- c("BB", "AB", "AA")
      beta$HETE_GRP <- cut(hetes_mean, breaks = hetes_breaks, labels = hetes_labels, include.lowest = TRUE)
      beta <-  beta[beta$HETE_GRP %in% "AB", ]
      print(dim(beta))
      beta$HETE_GRP <- NULL
  }


  suppressMessages({
    used <- reshape2::melt(beta, id.vars = c("Probe", "GENOTYPE"),variable.name = "ID",value.name = "value")
  })
  used$value <- as.numeric(as.character(used$value))
  

  cat("\n generate lines ...\n")
  pg <- ggplot(used, aes(x = ID, y = value,color = GENOTYPE), alpha = alpha) +
    geom_point(cex = dotSize) +
    geom_line(aes(group = Probe,), linewidth=1) +
    theme_classic(base_size = 10) +
    labs(y = "methylation level", x = "ID") + ggtitle( paste0("SNP genotype defined by [",colorGroup,"]") ) +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) # + theme(legend.position = "none")
   
  imgHeight <- 5 + max(nchar(meta$SAMPLEID)) / 20
  #plots <- cowplot::plot_grid(pg1, pg2, ncol = 2, rel_widths = c(8, 1))
  if (!is.null(outFile)) {
    if (ncol(beta) > 20) {
      imgWidth <- 5 + ncol(beta) / 5 + nrow(beta) / 400
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = F)
    } else {
      imgWidth <- min(5 + ncol(beta) / 10 + nrow(beta) / 400, 45)
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = T)
    }
    cat("\n\t", basename(outFile), "[saved]")
  }
  options(ggplot2.verbose = TRUE)
  return(pg)
} 
##################################################################



BetaRidgeline <- function(beta, meta, SAMPLEID = "Sample_Name", outFile = NULL, scale = 1.2, alpha = 1) {
  # The extent to which the different densities overlap can be controlled with the scale parameter
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggridges")))

  TargetIDs <- rownames(beta)
  validIds <- intersect(meta$Sample_Name, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$Sample_Name %in% validIds]
  if (length(validIds) ==1) {
    beta=data.frame(beta[, validIds])
    rownames(beta) <- rownames(beta)
    colnames(beta) <- validIds
    meta <- meta[validIds, ]
  }else if (length(validIds) > 1) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$Sample_Name. \n")
    return(NULL)
  }
  colnames(beta) <- newIDs
  suppressMessages({
    used <- reshape2::melt(as.matrix(beta))
  })

  colnames(used)[2] <- "ID"
  used$value <- as.numeric(used$value) # * 100
  meta <- meta[order(meta$Sample_Group), ]
  rownames(meta) <- as.character(meta$SAMPLEID)

  orderedIDs <- meta$SAMPLEID
  GROUP1 <- meta$Sample_Group[match(as.character(used$ID), meta$SAMPLEID)]
  used$GROUP <- factor(GROUP1, levels = unique(meta$Sample_Group))
  uniqCols <- standardColors()[1:length(unique(meta$Sample_Group))]
  uniqComb <- data.frame(GROUP = unique(meta$Sample_Group), COLOR = uniqCols)

  cat("\n generate density ridge plot ...\n")
  pg <- ggplot(used, aes(x = value, y = ID, fill = GROUP)) +
    geom_density_ridges(alpha = alpha, scale = scale) +
    scale_fill_cyclical(name = "GROUP", values = uniqComb$COLOR, guide = "legend", labels = sort(uniqComb$GROUP)) +
    scale_y_discrete(limits = orderedIDs) + #  specify order on the X axis
    coord_flip(xlim = c(0, 1), ylim = NULL, expand = TRUE, clip = "on") +
    theme_classic(base_size = 10) +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) +
    labs(x = "methylation level", y = "ID")

  imgHeight <- 5 + max(nchar(meta$SAMPLEID)) / 20
  # theme(plot.title = element_text(size = 6),plot.subtitle=element_text(size=6)) +
  # ggtitle(label=title,subtitle=subTitle)
  if (!is.null(outFile)) {
    if (ncol(beta) > 20) {
      imgWidth <- 10 + ncol(beta) / 5
      suppressMessages(suppressWarnings(ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = F)))
    } else {
      imgWidth <- 10 + ncol(beta) / 10
      suppressMessages(suppressWarnings(ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = T)))
    }
    cat("\n\t", basename(outFile), "[saved]")
  }

  return(pg)
}


##################################################################
##################################################################
# 04/09/2025, 16:30:09 


Build_CDF_classfier <-function(dataset, probeset="selected", p=0.7, ntree = 100, retrain_gini=0.5, outPrefix=NULL){
  # Install and load necessary packages
   if (!requireNamespace("randomForest", quietly = TRUE)) install.packages("randomForest")
   suppressMessages(suppressWarnings(library(randomForest)))
   if (!requireNamespace("caret", quietly = TRUE)) install.packages("caret")
   suppressMessages(suppressWarnings(library(caret)))   


   
   Gen_ML_classifier <- function(input, p=0.7, ntree = 100, outPrefix=NULL){
    set.seed(42)  # for reproducibility
    input$group <- as.factor(input$group)
    trainIndex <- createDataPartition(input$group, p = p, 
                                      list = FALSE, 
                                      times = 1)

    dfTrain <- input[ trainIndex,]
    dfTest  <- input[-trainIndex,]
    # Train the Random Forest model
    # Tune mtry using tuneRF function
    tuned_model <- tuneRF(input[,-1], input[,1], stepFactor = 1.5, improve = 0.01, ntreeTry = 500)

    # Print the best mtry value
    best_mtry <- tuned_model[which.min(tuned_model[, 2]), 1]
    cat(paste0("\nbest_mtry=",best_mtry)) # the number of features to consider when looking for the best split at each node.

    rf_model <- randomForest(group ~ ., data = dfTrain, 
                            ntree = ntree,  # Number of trees
                            mtry = best_mtry)    # Number of variables randomly sampled as candidates at each split

    # Make predictions on the test data
    rf_predictions <- predict(rf_model, dfTest)
    if(!is.null(outPrefix)){
      logFile <- paste0(outPrefix,"_model.log")
      sink(logFile)    
      cat(paste0("\nbest_mtry=",best_mtry,"\n"))
      # Print confusion matrix
      # capture all the output to a file.
      print(confusionMatrix(rf_predictions, dfTest$group))
      #================================================================
      rdsFile <- paste0(outPrefix,"_rf_model.rds")
      saveRDS(rf_model,file=rdsFile)
      cat(paste0('\n ',basename(rdsFile),' [saved]'))
      
      cat("\n")
      print(importance(rf_model))
      #[1] 179, Check feature importance
      # Plot feature importance
      pdfFile<- paste0(outPrefix,"_varImpPlot.pdf")
      pdf(pdfFile,width=6, height = 6)
            varImpPlot(rf_model) 
      garbage<-dev.off()    
      cat(paste0('\n ',basename(pdfFile),' [saved]'))   
      sink()
    }  
      #================================================================
      if(!is.null(retrain_gini)){
        topfeatures <- rownames(importance(model))[importance(model) > 0.5]
        cat("\nINFO: retrain model using features with MeanDecreaseGini >0.5\n")
        print( sort( importance(model)[topfeatures,],decreasing=T))
        dfTrain_top_features <- dfTrain[,c(topfeatures,"group")]      
      # Retrain the model
        rf_model <- randomForest(group ~ ., data = dfTrain_top_features)
        rf_predictions <- predict(rf_model, dfTest)
        if(!is.null(outPrefix)){
          logFile <- paste0(outPrefix,"_model2.log")
          sink(logFile)    
          cat("\nretrain with top features\n")
          cat(paste0("\nbest_mtry=",best_mtry,"\n"))
          # Print confusion matrix
          # capture all the output to a file.
          print(confusionMatrix(rf_predictions, dfTest$group))
          #================================================================
          rdsFile <- paste0(outPrefix,"_rf_model2.rds")
          saveRDS(rf_model,file=rdsFile)
          cat(paste0('\n ',basename(rdsFile),' [saved]'))
          
          cat("\n")
          print(importance(rf_model))
          #[1] 179, Check feature importance
          # Plot feature importance
          pdfFile<- paste0(outPrefix,"_varImpPlot2.pdf")
          pdf(pdfFile,width=6, height = 6)
                varImpPlot(rf_model) 
          garbage<-dev.off()    
          cat(paste0('\n ',basename(pdfFile),' [saved]'))   
           sink()  
         } 
      }
     #================================================================
    return(rf_model)
   }
   model <- Gen_ML_classifier(dataset, p=p, ntree = ntree, outPrefix=outPrefix)
   return(model)
}

#================================================================

Build_classfier_v6 <-function(dataset, probeset="selected", p=0.7, ntree = 100, mtry = 2,outPrefix=NULL){
  # Install and load necessary packages
   if (!requireNamespace("randomForest", quietly = TRUE)) install.packages("randomForest")
   suppressMessages(suppressWarnings(library(randomForest)))
   if (!requireNamespace("caret", quietly = TRUE))  install.packages("caret")
   suppressMessages(suppressWarnings(library(caret)))   
   dir.create(dirname(outPrefix), showWarnings = FALSE,recursive=T)
   Prepare_Input <- function(beta,meta, chrs=NULL, outXlsx=NULL){
    # stat <- t(beta) # does't work well if without statistic calculation
    stat <- Calc_Stat_Chr_v6(beta, chrs=chrs)
    df1 <- as.data.frame(stat)
    # df1[is.na(df1)] <- 0  # replace NA with 0
    df1$group <- as.factor(meta[colnames(beta),"Sample_Group"])
    table(df1$group, useNA = "always")
    if(! is.null(outXlsx)){
      df_out <- cbind(rownames(df1),df1)
      SaveTable(df_out, sheetName=chrs,file=outXlsx, rowNames=F,append=T)
    }
    return(df1)
   }
   Gen_ML_chr_classifier <- function(input, p=0.7, ntree = 100, mtry = 2, outPrefix=NULL){
    set.seed(42)  # for reproducibility
    trainIndex <- createDataPartition(input$group, p = p, 
                                      list = FALSE, 
                                      times = 1)

    dfTrain <- input[ trainIndex,]
    dfTest  <- input[-trainIndex,]
    # Train the Random Forest model
    rf_model <- randomForest(group ~ ., data = dfTrain, 
                            ntree = ntree,  # Number of trees
                            mtry = mtry)    # Number of variables randomly sampled as candidates at each split
    # Make predictions on the test data
    rf_predictions <- predict(rf_model, dfTest)
    if(!is.null(outPrefix)){
      logFile <- paste0(outPrefix,"_model.log")
      sink(logFile)    
      # Print confusion matrix
      # capture all the output to a file.
      cat("\n")
      print(confusionMatrix(rf_predictions, dfTest$group))
      #================================================================
      rdsFile <- paste0(outPrefix,"_model.rds")
      saveRDS(rf_model,file=rdsFile)
      cat(paste0('\n ',basename(rdsFile),' [saved]'))
      
      cat("\n")
      print(sum(importance(rf_model)>0))
      #[1] 179, Check feature importance
      # Plot feature importance
      pdfFile<- paste0(outPrefix,"_varImpPlot.pdf")
      pdf(pdfFile,width=6, height = 6)
            varImpPlot(rf_model) 
        garbage<-dev.off()    
       cat(paste0('\n ',basename(pdfFile),' [saved]'))   
      sink()         
    }

    return(rf_model)
   }
   models <- list()
   chrs <- names(dataset)
   x <- 0
   outXlsx <- paste0(outPrefix,"_stat.input.xlsx")
   for (chr in chrs ){ 
      x <- x +1
      cat("\n [",chr,"]")
      set1 <- dataset[[chr]]
      input1 <- Prepare_Input(set1[["beta"]],set1[["meta"]], chrs=chr, outXlsx=outXlsx)
      models[[x]] <- Gen_ML_chr_classifier(input1, p=p, ntree = ntree, mtry = mtry, outPrefix=paste0(outPrefix,"_",chr))
   }
    names(models) <- chrs
    rdsFile <- paste0(outPrefix,"_chr_rf_models.rds")
    saveRDS(models,file=rdsFile)
    cat(paste0('\n ',basename(rdsFile),' [saved]'))   
}
#================================================================

Build_ML_classfier <-function(metaFile, betaFile, mdlFile="GSE64244_rf.model.rds",probeset="selected"){
    model_path <- "/research/rgs01/home/clusterHome/hjin/projects/imprintomeR_dev/selected/"
    if (!requireNamespace("caret", quietly = TRUE)) install.packages("caret")
    library(caret)
    # metaFile <- "/research/rgs01/home/clusterHome/hjin/projects/imprintomeR_dev/selected/golden_std_wb_meta.txt"
    # betaFile <- "/research/rgs01/home/clusterHome/hjin/projects/imprintomeR_dev/selected/golden_std_wb_selected_beta.txt"
    if(F){
      metaFile <- "GSE64244_meta_ML.txt"
      meta <- read.table(metaFile, sep="\t",header=TRUE,fill=TRUE,stringsAsFactors = FALSE, as.is=TRUE,row.names=NULL ,check.names=FALSE ,comment.char = "")
      meta$Sample_Name <- gsub("1.1","2",meta$Sample_Name)
      meta$Sample_Name<- gsub("X45X","45",meta$Sample_Name)
      rownames(meta) <- meta$Sample_Name

      betaFile <-"GSE64244.HM450K_UPD_subset455_Beta.txt"
      dat <- read.table(betaFile, sep="\t",header=TRUE,fill=TRUE,stringsAsFactors = FALSE, as.is=TRUE,row.names=1 ,check.names=FALSE ,comment.char = "")
      colnames(dat) <- gsub("1.1","2",colnames(dat))
      colnames(dat) <- gsub("X45X","45",colnames(dat))

      cat("\n[dim:",nrow(dat)," rows x",ncol(dat),"cols]")
      df1 <- as.data.frame(t(dat))
      df1$group <- as.factor(meta[colnames(dat),"Sample_Group"])
    }
    input <- LoadMetaBeta(metaFile, betaFile, probeset = probeset)
    meta <- input[["meta"]]
    beta <- input[["beta"]]
    df1 <- as.data.frame(t(beta))
    df1$group <- as.factor(meta[colnames(beta),"Sample_Group"])
    table(df1$group, useNA = "always")
    set.seed(42)  # for reproducibility
    trainIndex <- createDataPartition(df1$group, p = .7, 
                                      list = FALSE, 
                                      times = 1)

    dfTrain <- df1[ trainIndex,]
    dfTest  <- df1[-trainIndex,]

    #================================================================
    # Install and load necessary packages
    if (!requireNamespace("randomForest", quietly = TRUE)) install.packages("randomForest")
    library(randomForest)

    # Use the same data split from the previous example
    rf_model <- randomForest(group ~ ., data = dfTrain, ntree = 100, mtry = 2, importance = TRUE)

    # Train the Random Forest model
    rf_model <- randomForest(group ~ ., data = dfTrain, 
                            ntree = 100,  # Number of trees
                            mtry = 2)     # Number of variables randomly sampled as candidates at each split
    # Make predictions on the test data
    rf_predictions <- predict(rf_model, dfTest)

    # Print confusion matrix
    print(confusionMatrix(rf_predictions, dfTest$group))
    #================================================================
   rdsFile <- paste0(model_path,"/",mdlFile)
   saveRDS(rf_model,file=rdsFile)
   cat(paste0('\n ',basename(rdsFile),' [saved]'))

   outFile<- paste0(tools::file_path_sans_ext(mdlFile),"_varImpPlot.pdf")

  sum(importance(rf_model)>0)
   #[1] 179, Check feature importance
    # Plot feature importance
  pdf(outFile,width=6, height = 6)
        varImpPlot(rf_model) 
    garbage<-dev.off()
    
   

}
##################################################################
#  02/17/2025,17:14:20 

Build_Model_PCA <- function(data,p=0.8, model="rf",outPrefix="test"){
   # data: dataset; row by sample, column by feature, last column is group (i.e. outcome of classification)
   # p: proportion of training set
   # model: rf or mlr, indicating random forest or multinomial logistic regression
   # outPrefix: prefix for output files (.log and model.rds)

    library(nnet)  # For multinomial logistic regression
    library(MASS)
    library(caret)
    library(randomForest)
    library(e1071) 
    
    # Split the data into training and testing sets
    set.seed(123)  # For reproducibility
    trainIndex <- createDataPartition(data$group, p = p, 
                                    list = FALSE, 
                                    times = 1)
    trainData <- data[trainIndex, ]
    testData <- data[-trainIndex, ]

    ctrl <- trainControl(method = "cv", number = 5)
    if(model %in%  c("mlr","multinorm")){
      # Fit the multinomial logistic regression model
      model_res <- train(group ~ ., data = trainData,
                    method = "multinom",
                    trControl = ctrl,
                    trace = FALSE)
    }else{
      # Fit the random forest model
      model_res <- train(group ~ ., data = trainData,
                    method = "rf",
                    trControl = ctrl,
                    trace = FALSE)
    }
    logFile <- paste0(outPrefix,"_",model,"_model.log")
    sink(logFile)   
    # Summarize the model
    cat("\n")
    print(summary(model_res))
     # model accuracy
    print(model_res$results)
    cat("\n")
    # Make predictions on the dataset
    predictions1 <- predict(model_res, newdata = testData)
    # Evaluate the model
    print( confusionMatrix(as.factor(predictions1), as.factor(testData$group)))
    rdsFile <- paste0(outPrefix,"_",model,"_model.rds")
    saveRDS(model_res,file=rdsFile)
    cat(paste0('\n ',basename(rdsFile),' [saved]'))
    sink()
    cat(paste0('\n ',basename(rdsFile),' [saved]'))
    return(model_res)
}

##################################################################
# started: 06/16/2025,11:59:11 
###############################  

Build_PCA_classfier <-function(dataset, probeset="selected", p=0.7, ntree = 100, retrain_gini=0.5, outPrefix=NULL){
  # Install and load necessary packages
   if (!requireNamespace("randomForest", quietly = TRUE)) install.packages("randomForest")
   suppressMessages(suppressWarnings(library(randomForest)))
   if (!requireNamespace("caret", quietly = TRUE)) install.packages("caret")
   suppressMessages(suppressWarnings(library(caret)))   

   
   Gen_ML_classifier <- function(input, p=0.7, ntree = 100, outPrefix=NULL){
    set.seed(42)  # for reproducibility
    input$group <- as.factor(input$group)
    trainIndex <- createDataPartition(input$group, p = p, 
                                      list = FALSE, 
                                      times = 1)

    dfTrain <- input[ trainIndex,]
    dfTest  <- input[-trainIndex,]
    # Train the Random Forest model
    # Tune mtry using tuneRF function
    tuned_model <- tuneRF(input[,-1], input[,1], stepFactor = 1.5, improve = 0.01, ntreeTry = 500)

    # Print the best mtry value
    best_mtry <- tuned_model[which.min(tuned_model[, 2]), 1]
    cat(paste0("\nbest_mtry=",best_mtry)) # the number of features to consider when looking for the best split at each node.

    rf_model <- randomForest(group ~ ., data = dfTrain, 
                            ntree = ntree,  # Number of trees
                            mtry = best_mtry)    # Number of variables randomly sampled as candidates at each split

    # Make predictions on the test data
    rf_predictions <- predict(rf_model, dfTest)
    if(!is.null(outPrefix)){
      logFile <- paste0(outPrefix,"_model.log")
      sink(logFile)    
      cat(paste0("\nbest_mtry=",best_mtry,"\n"))
      # Print confusion matrix
      # capture all the output to a file.
      print(confusionMatrix(rf_predictions, dfTest$group))
      #================================================================
      rdsFile <- paste0(outPrefix,"_rf_model.rds")
      saveRDS(rf_model,file=rdsFile)
      cat(paste0('\n ',basename(rdsFile),' [saved]'))
      
      cat("\n")
      print(importance(rf_model))
      #[1] 179, Check feature importance
      # Plot feature importance
      pdfFile<- paste0(outPrefix,"_varImpPlot.pdf")
      pdf(pdfFile,width=6, height = 6)
            varImpPlot(rf_model) 
      garbage<-dev.off()    
      cat(paste0('\n ',basename(pdfFile),' [saved]'))   
      sink()
    }  
      #================================================================
      if(!is.null(retrain_gini)){
        topfeatures <- rownames(importance(rf_model))[importance(rf_model) > 0.5]
        cat("\nINFO: retrain model using features with MeanDecreaseGini >0.5\n")
        print( sort( importance(rf_model)[topfeatures,],decreasing=T))
        dfTrain_top_features <- dfTrain[,c(topfeatures,"group")]      
      # Retrain the model
        rf_model <- randomForest(group ~ ., data = dfTrain_top_features)
        rf_predictions <- predict(rf_model, dfTest)
        if(!is.null(outPrefix)){
          logFile <- paste0(outPrefix,"_model2.log")
          sink(logFile)    
          cat("\nretrain with top features\n")
          cat(paste0("\nbest_mtry=",best_mtry,"\n"))
          # Print confusion matrix
          # capture all the output to a file.
          print(confusionMatrix(rf_predictions, dfTest$group))
          #================================================================
          rdsFile <- paste0(outPrefix,"_rf_model2.rds")
          saveRDS(rf_model,file=rdsFile)
          cat(paste0('\n ',basename(rdsFile),' [saved]'))
          
          cat("\n")
          print(importance(rf_model))
          #[1] 179, Check feature importance
          # Plot feature importance
          pdfFile<- paste0(outPrefix,"_varImpPlot2.pdf")
          pdf(pdfFile,width=6, height = 6)
                varImpPlot(rf_model) 
          garbage<-dev.off()    
          cat(paste0('\n ',basename(pdfFile),' [saved]'))   
           sink()  
         } 
      }
     #================================================================
    return(rf_model)
   }
   model <- Gen_ML_classifier(dataset, p=p, ntree = ntree, outPrefix=outPrefix)
   return(model)
}


Calc_Area_Ecdf <- function(sample_data){ 
  # Compute ECDFs for each CATEGORY
  suppressMessages(suppressWarnings(library(dplyr)))
  sample_data <- sample_data %>%  filter(is.finite(value))

  beta_A <- sample_data$value[sample_data$CATEGORY == "paternal"]
  beta_B <- sample_data$value[sample_data$CATEGORY == "maternal"]

  # Compute ECDFs
  ecdf_A <- ecdf(beta_A)
  ecdf_B <- ecdf(beta_B)

  # Define a fine grid over the common range
  x_grid <- seq(min(c(beta_A, beta_B)), max(c(beta_A, beta_B)), length.out = 1000)

  # Evaluate ECDFs at the grid points
  cdf_A <- ecdf_A(x_grid)
  cdf_B <- ecdf_B(x_grid)

  # Calculate absolute differences
  diff <- abs(cdf_A - cdf_B)

  # Numerical integration (trapezoidal rule) to  approximate the area under a curve
  dx <- diff(x_grid)[1]  # Step size (assuming equal spacing)
  area <- round(sum(diff * dx),3)
  return(area)
}


#================================================================

# Load necessary libraries
#================================================================

Calc_Area_Ecdf_Adv <- function(beta_group1, beta_group2){ 
  # Compute ECDFs for each CATEGORY
  suppressMessages(suppressWarnings(library(dplyr)))
  beta_A <- beta_group1[is.finite(beta_group1)]
  beta_B <- beta_group2[is.finite(beta_group2)]

  # Compute ECDFs
  ecdf_A <- ecdf(beta_A)
  ecdf_B <- ecdf(beta_B)
  # Define a fine grid over the common range
  x_grid <- seq(min(c(beta_A, beta_B)), max(c(beta_A, beta_B)), length.out = 1000)

  # Evaluate ECDFs at the grid points
  cdfA_values <- ecdf_A(x_grid)
  cdfB_values <- ecdf_B(x_grid)
  diff <- cdfA_values - cdfB_values
  cross_point <- x_grid[which.min(abs(diff))]
 print(cross_point)
  # Check for crossing points
 #cross_point <- x_grid[which.min(abs(cdfA_values - cdfB_values))]
 cat("\n",min(x_grid), max(x_grid),"\n")
 if (length(cross_point)==1){
    cat("\n1")
    # Calculate area before the crossing point
    idx_before <- which(x_grid <= cross_point)
    area_before <- sum((diff[idx_before[-1]] + diff[idx_before[-length(idx_before)]]) / 2 * diff(x_grid)[1])

    # Calculate area after the crossing point
    idx_after <- which(x_grid > cross_point)
    area_after <- sum((diff[idx_after[-1]] + diff[idx_after[-length(idx_after)]]) / 2 * diff(x_grid)[1])
    area <- max(area_before,area_after)
    cat("\narea_before=",area_before, "; area_after=",area_after)
    cat("\narea_1=",area)
  }else{
    # Calculate absolute differences
    diff <- abs(cdfA_values - cdfB_values)
    # Numerical integration (trapezoidal rule) to  approximate the area under a curve
    dx <- diff(x_grid)[1]  # Step size (assuming equal spacing)
    area <- round(sum(diff * dx),3)
    cat("\narea_4=",area)
   }
  cat("\narea=",area)
  return(area)
}
#================================================================

Calc_Area_Ecdf_sep <- function(beta_group1, beta_group2){ 
  # Compute ECDFs for each CATEGORY
  suppressMessages(suppressWarnings(library(dplyr)))
  beta_A <- beta_group1[is.finite(beta_group1)]
  beta_B <- beta_group2[is.finite(beta_group2)]

  # Compute ECDFs
  ecdf_A <- ecdf(beta_A)
  ecdf_B <- ecdf(beta_B)

  # Define a fine grid over the common range
  x_grid <- seq(min(c(beta_A, beta_B)), max(c(beta_A, beta_B)), length.out = 1000)

  # Evaluate ECDFs at the grid points
  cdf_A <- ecdf_A(x_grid)
  cdf_B <- ecdf_B(x_grid)

  # Calculate absolute differences
  diff <- abs(cdf_A - cdf_B)

  # Numerical integration (trapezoidal rule) to  approximate the area under a curve
  dx <- diff(x_grid)[1]  # Step size (assuming equal spacing)
  area <- round(sum(diff * dx),3)
  return(area)
}


#================================================================

Calc_CDF_Stat <- function(betaFile,metaFile,prefix=NULL,SAMPLEID="Sample_Name", probeset="selected"){
  input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
  meta <- input[["meta"]]
  beta0 <- input[["beta"]]
  if (!is.null(probeset)) {
      probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
      if (probeset %in% names(probesets)) {
        probes <- probesets[[probeset]]
      } else {
        cat("\nERROR: unavailable probeset & probes not given.\n")
        # q("no")
      }
      if("ORIGIN" %in% colnames(probes)){
        anno <- probes[,c("NAME","CHR","MAPINFO","Closest_TSS_gene_name","ORIGIN")]  
        colnames(anno)[4:5] <- c("GENE","CATEGORY")
      }else{
      anno <- probes[,c("NAME","CHR","MAPINFO","Closest_TSS_gene_name")] 
      anno$CATEGORY <- "NA"
      colnames(anno)[4] <- "GENE"
      }
      rownames(anno) <- probes$NAME
        cat("\n\t[SubsetBeta] subset by probeset [query:", length(anno$NAME))
        common_probes <- intersect(rownames(beta0), anno$NAME)
        probesets <- anno[common_probes, ]
        if(ncol(beta0)==1){
          beta <- data.frame(beta0[common_probes, ])
          rownames(beta) <- common_probes
          colnames(beta) <- colnames(beta0)
        }else{
          beta <- beta[common_probes, ]
        }
        print(dim(beta))
        cat("; matched probes:", nrow(beta), "]\n")

   }
  #================================================================
  TargetIDs <- rownames(beta)
  validIds <- intersect(meta$Sample_Name, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$Sample_Name %in% validIds]
  if (length(validIds) ==1) {
    beta=data.frame(beta[, validIds])
    rownames(beta) <- rownames(beta)
    colnames(beta) <- validIds
    meta <- meta[validIds, ]
  }else  if (length(validIds) > 1) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$Sample_Name. \n")
    return(NULL)
  } 
  colnames(beta) <- newIDs 
  beta$Probe=rownames(beta)
  beta$CATEGORY= anno[common_probes,"CATEGORY"]

  suppressMessages({
    used <- reshape2::melt(beta, id.vars = c("Probe", "CATEGORY"),variable.name = "ID",value.name = "value")
  })
  used <- used[used$CATEGORY %in% c("paternal","maternal"),]
  meta <- meta[order(meta$Sample_Group), ] # order GROUP
  orderedIDs <- meta$SAMPLEID # order SMAPLEID by GROUP
  rownames(meta) <- as.character(meta$SAMPLEID)
  used$value <- as.numeric(as.character(used$value)) -0.5 # calc
  #================================================================
  #      Probe CATEGORY                       ID      value
  #  cg00124993 paternal GTEX-117YW-0003-SM-GW185 0.08798529
  cat("\nINFO: processing data  ...\n")
  objEcdf <- list()
  objEcdf[[length(objEcdf)+1]] <- used
  names(objEcdf)[length(objEcdf)] <- "data"
  objEcdf[[length(objEcdf)+1]] <- meta
  names(objEcdf)[length(objEcdf)] <- "meta"
  objStat <- list()
  for (id in meta$SAMPLEID ){ 
    # procesed  by sample
    cat(paste0("\n ",id))
    sample_data <- used[used$ID %in% id, ] 
    area <- Calc_Area_Ecdf(sample_data)
    paternal_data <- sample_data[sample_data$CATEGORY %in% "paternal", ]
    maternal_data <- sample_data[sample_data$CATEGORY %in% "maternal", ]
    KS_result <- Calc_KS(paternal_data$value, maternal_data$value) #Kolmogorov-Smirnov test
    paternal_peak <- Peak_Stat(paternal_data$value, topn=1)
    maternal_peak <- Peak_Stat(maternal_data$value, topn=1)
    paternal_x <- paternal_peak[1,"value_x"] 
    maternal_x <- maternal_peak[1,"value_x"] 
    points_data <- Ecdf_Points(sample_data, paternal_x, maternal_x)
    euclidean_data <- Calc_Euclidean_Distance(points_data)
    distance <- euclidean_data["distance"]
    objStat[[length(objStat)+1]] <- list(data=sample_data, KS_test=KS_result, 
                              peakstat=list(paternal=paternal_peak,maternal=maternal_peak),
                              points_peak=points_data,
                              distance_peak =euclidean_data,
                              distance=distance, 
                              area=area )
     names(objStat)[length(objStat)] <- id
  } 
  cat("\n")
  objEcdf[[length(objEcdf)+1]] <- objStat
  names(objEcdf)[length(objEcdf)] <- "Statistics"
  #----------------------------------------------------------------
  areas <- sapply(objStat, function(x) x$area)
  ks_distances <- sapply(objStat, function(x) x$KS_test$dist)
  ks_p_values <- sapply(objStat, function(x) x$KS_test$p.value)
  distances_peak <- t(sapply(objStat, function(x) x$distance_peak))
  colnames(distances_peak) <- c("euclidean_dist", "peak_paternal_x","peak_paternal_y","peak_maternal_x", "peak_maternal_y")
  objEcdf[[length(objEcdf)+1]] <- data.frame(
                                SAMPLE_NAME = names(objStat),cdf_area=areas,
                                ks_dist=ks_distances, ks_pval=ks_p_values,
                                distances_peak
                              )
  names(objEcdf)[length(objEcdf)] <- "Summary"  
  #---------------------------------------------------------------- 
   if(!is.null(prefix)){
    rdsFile <- paste0(prefix,"_",probeset,"_obj.final.rds")
    saveRDS(objEcdf,file=rdsFile)
    cat(paste0('\n ',basename(rdsFile),' [saved]'))    
  }
  return(objEcdf)
}
#================================================================

##################################################################
# 04/16/2025, 09:13:18 
##################################################################



Calc_CDF_Stat_sep <- function(betaFile,metaFile,prefix=NULL,SAMPLEID="Sample_Name", probeset="selected"){
  input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
  meta <- input[["meta"]]
  beta0 <- input[["beta"]]
  if (!is.null(probeset)) {
      probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
      if (probeset %in% names(probesets)) {
        probes <- probesets[[probeset]]
      } else {
        cat("\nERROR: unavailable probeset & probes not given.\n")
        # q("no")
      }
      if("ORIGIN" %in% colnames(probes)){
        anno <- probes[,c("NAME","CHR","MAPINFO","Closest_TSS_gene_name","ORIGIN")]  
        colnames(anno)[4:5] <- c("GENE","CATEGORY")
      }else{
      anno <- probes[,c("NAME","CHR","MAPINFO","Closest_TSS_gene_name")] 
      anno$CATEGORY <- "NA"
      colnames(anno)[4] <- "GENE"
      }
      rownames(anno) <- probes$NAME
        cat("\n\t[SubsetBeta] subset by probeset [query:", length(anno$NAME))
        common_probes <- intersect(rownames(beta0), anno$NAME)
        probesets <- anno[common_probes, ]
        if(ncol(beta0)==1){
          beta <- data.frame(beta0[common_probes, ])
          rownames(beta) <- common_probes
          colnames(beta) <- colnames(beta0)
        }else{
          beta <- beta0[common_probes, ]
        }
        cat("; matched probes:", nrow(beta), "]\n")
        print(nrow(beta))
   }
  #================================================================
  TargetIDs <- rownames(beta)
  validIds <- intersect(meta$Sample_Name, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$Sample_Name %in% validIds]
  if (length(validIds) ==1) {
    beta=data.frame(beta[, validIds])
    rownames(beta) <- rownames(beta)
    colnames(beta) <- validIds
    meta <- meta[validIds, ]
  }else  if (length(validIds) > 1) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$Sample_Name. \n")
   print(head(meta$Sample_Name,n=5))
    print(head(colnames(beta),n=5))
    return(NULL)
  } 
  colnames(beta) <- newIDs 
  beta$Probe=rownames(beta)
  beta$CATEGORY= anno[common_probes,"CATEGORY"]

  suppressMessages({
    used <- reshape2::melt(beta, id.vars = c("Probe", "CATEGORY"),variable.name = "ID",value.name = "value")
  })
  used <- used[used$CATEGORY %in% c("paternal","maternal"),]
  meta <- meta[order(meta$Sample_Group), ] # order GROUP
  orderedIDs <- meta$SAMPLEID # order SMAPLEID by GROUP
  rownames(meta) <- as.character(meta$SAMPLEID)
  used$value <- as.numeric(as.character(used$value)) -0.5 # calculate deviation from imprinted norm
  #================================================================
  #      Probe CATEGORY                       ID      value
  #  cg00124993 paternal GTEX-117YW-0003-SM-GW185 0.08798529
  cat("\nINFO: processing data  ...\n")
  objEcdf <- list()
  objEcdf[[length(objEcdf)+1]] <- used
  names(objEcdf)[length(objEcdf)] <- "data"
  objEcdf[[length(objEcdf)+1]] <- meta
  names(objEcdf)[length(objEcdf)] <- "meta"
  objStat <- list()
  #norm <- ImputedNorm(ncol=1,nrow=nrow(beta), size=50, p_success=0.5,adj=-0.5, seed=123) # simulate imprinted norm and calculate deviation
  norm_data <- readRDS( "/home/hjin/projects/ImprintomeR/package/inst/extdata/GTEX_wholeblood_classifier2_aveBeta_normdf.rds")
  norm_data$value <-  norm_data$value - 0.5 # calculate deviation from imprinted norm
  objEcdf[[length(objEcdf)+1]] <- norm_data
  names(objEcdf)[length(objEcdf)] <- "norm"
  for (id in meta$SAMPLEID ){ 
    # procesed  by sample
    cat(paste0("\n ",id))
    sample_data <- used[used$ID %in% id, ] 
    #area <- Calc_Area_Ecdf(sample_data)
    paternal_data <- sample_data[sample_data$CATEGORY %in% "paternal", ]
    maternal_data <- sample_data[sample_data$CATEGORY %in% "maternal", ]
    area <- Calc_Area_Ecdf_sep(paternal_data$value,maternal_data$value)
    area_pat <- Calc_Area_Ecdf_sep(paternal_data$value, norm_data$value)
    area_mat <- Calc_Area_Ecdf_sep(maternal_data$value, norm_data$value)
    KS_pat <- Calc_KS(paternal_data$value, norm_data$value)
    KS_mat <- Calc_KS(maternal_data$value, norm_data$value)
    KS_result <- Calc_KS(paternal_data$value, maternal_data$value) #Kolmogorov-Smirnov test
    paternal_peak <- Peak_Stat(paternal_data$value, topn=1)
    maternal_peak <- Peak_Stat(maternal_data$value, topn=1)
    paternal_x <- paternal_peak[1,"value_x"] 
    maternal_x <- maternal_peak[1,"value_x"] 
    points_data <- Ecdf_Points(sample_data, paternal_x, maternal_x)
    euclidean_data <- Calc_Euclidean_Distance(points_data)
    distance <- euclidean_data["distance"]
    probabilities <- c(0.25, 0.5, 0.75)
    quartiles_pat <- quantile(sort(paternal_data$value), probabilities)
    quartiles_mat <- quantile(sort(maternal_data$value), probabilities)
    names(quartiles_pat) <- c("Q1","Q2","Q3")
    names(quartiles_mat) <- c("Q1","Q2","Q3")
    objStat[[length(objStat)+1]] <- list(data=sample_data, 
                              KS_test=KS_result, 
                              KS_paternal=KS_pat, KS_maternal=KS_mat, 
                              area=list(total=area, paternal=area_pat, maternal=area_mat),
                              peakstat=list(paternal=paternal_peak,maternal=maternal_peak),
                              quartile=list(paternal=quartiles_pat,maternal=quartiles_mat),
                              points_peak=points_data,
                              distance_peak =euclidean_data,
                              distance=distance
                              )
     names(objStat)[length(objStat)] <- id
  } 
  cat("\n")
  objEcdf[[length(objEcdf)+1]] <- objStat
  names(objEcdf)[length(objEcdf)] <- "Statistics"
  #----------------------------------------------------------------
  areas <- sapply(objStat, function(x) x$area$total)
  areas_pat <- sapply(objStat, function(x) x$area$paternal)
  areas_mat <- sapply(objStat, function(x) x$area$maternal)
  ks_dist <- sapply(objStat, function(x) x$KS_test$dist)
  ks_pval <- sapply(objStat, function(x) x$KS_test$p.value)
  ks_dist_pat <- sapply(objStat, function(x) x$KS_paternal$dist)
  ks_pval_pat <- sapply(objStat, function(x) x$KS_paternal$p.value)
  ks_dist_mat <- sapply(objStat, function(x) x$KS_maternal$dist)
  ks_pval_mat <- sapply(objStat, function(x) x$KS_maternal$p.value)
  Qs_pat <- lapply(objStat, function(x) x$quartile$paternal)
  Qs_mat <- lapply(objStat, function(x) x$quartile$maternal)
  print(head(Qs_pat))
  Qs_pat_df <- do.call(rbind, Qs_pat)
  Qs_mat_df <- do.call(rbind, Qs_mat)
  colnames(Qs_pat_df) <- paste0(c("Q1","Q2","Q3"),"_pat")
  colnames(Qs_mat_df) <- paste0(c("Q1","Q2","Q3"),"_mat")
  distances_peak <- t(sapply(objStat, function(x) x$distance_peak))
  colnames(distances_peak) <- c("euclidean_dist", "peak_paternal_x","peak_paternal_y","peak_maternal_x", "peak_maternal_y")
  objEcdf[[length(objEcdf)+1]] <- data.frame(
                                SAMPLE_NAME = names(objStat),
                                cdf_area_pm=areas,cdf_area_pat=areas_pat,cdf_area_mat=areas_mat,
                                ks_dist_pm=ks_dist, ks_pval_pm=ks_pval,
                                ks_dist_pat=ks_dist_pat, ks_pval_pat=ks_pval_pat,
                                ks_dist_mat=ks_dist_mat,ks_pval_mat=ks_pval_mat,
                                Qs_pat_df,Qs_mat_df,
                                distances_peak
                              )
  names(objEcdf)[length(objEcdf)] <- "Summary"  
  #---------------------------------------------------------------- 
   if(!is.null(prefix)){
    rdsFile <- paste0(prefix,"_",probeset,"_obj.final.rds")
    saveRDS(objEcdf,file=rdsFile)
    cat(paste0('\n ',basename(rdsFile),' [saved]'))    
  }
  return(objEcdf)
}
#================================================================


Calc_Euclidean_Distance <- function(points_data){
  # Coordinates of the two points
  x1 <- points_data$x[points_data$CATEGORY == "paternal"]  # beta for A
  y1 <- points_data$y[points_data$CATEGORY == "paternal"]   # cdf for A
  x2 <- points_data$x[points_data$CATEGORY == "maternal"]  # beta for B
  y2 <- points_data$y[points_data$CATEGORY == "maternal"]   # cdf for B
  # Euclidean distance
  distance <- round(sqrt((x2 - x1)^2 + (y2 - y1)^2),3)
  result <- c(distance,x1,y1,x2,y2)
  names(result) <- c("distance","x1","y1","x2","y2")
  return(result)
}

##################################################################



CALC_KL_DIV <- function(data1, data2) {
  # Kullback-Leibler (KL) divergence measures the difference between two probability distributions.
  #
  library(entropy)
  # Estimate densities at common points
  x <- seq(min(min(data1), min(data2)), max(max(data1), max(data2)), length.out = 500)
  density1 <- density(data1, from = min(x), to = max(x), n = length(x))$y
  density2 <- density(data2, from = min(x), to = max(x), n = length(x))$y

  # Normalize densities to act as probability distributions
  density1 <- density1 / sum(density1)
  density2 <- density2 / sum(density2)

  # Calculate KL divergence
  kl_divergence <- KL.empirical(density1, density2)

  set.seed(123) # For reproducibility
  n_permutations <- 1000
  kl_div_permutations <- numeric(n_permutations)

  for (i in 1:n_permutations) {
    # Permute the data (this is a simple example; adapt as needed)
    P_perm <- sample(density1, length(density1), replace = TRUE)
    Q_perm <- sample(density2, length(density2), replace = TRUE)

    # Compute KL divergence for permuted data
    kl_div_permutations[i] <- KL.empirical(P_perm, Q_perm)
  }
  p_value <- sum(kl_div_permutations <= kl_divergence) / n_permutations
  # cat("\nINFO: KL divergence=",kl_divergence,"; p_value=",p_value)
  return(list(kl_div = kl_divergence, p.value = p_value))
}
##################################################################


# sample=input; control=control; probeset = "selected"; outPrefix = "test"; ncores = 5; verbose = TRUE;x = IDs[1]


Calc_KS  <- function(data1,data2) {
  library(stats)
  suppressMessages(suppressWarnings(ks_result <- ks.test(data1, data2)))
  return(list(dist = as.numeric(ks_result$statistic), p.value = ks_result$p.value))
}
#================================================================

Calc_Stat_Chr_v6 <- function(beta,probeset="selected", chrs=NULL, low_cutoff=0.3, high_cutoff=0.7){
  probesets_all <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
  probeset <- probesets_all[[probeset]]
  common_probes <- intersect(probeset$NAME, rownames(beta))
  probeset <- probeset[probeset$NAME %in% common_probes, ]
  beta <- beta[common_probes,]
  result_all <- NULL
  maternal_probes <- intersect(probeset$NAME[grep("maternal", probeset$ORIGIN)], rownames(beta))
  paternal_probes <- intersect(probeset$NAME[grep("paternal", probeset$ORIGIN)], rownames(beta))

  if(is.null(chrs)){
    chrs <- c("chr1","chr4","chr6","chr7","chr8","chr11","chr14","chr15","chr16","chr19","chr20","all") #"chr13","chr22","chr2",
  }

  for(chr in chrs){
    if(chr == "all"){
      probes_chr <- probeset$NAME
      probes_chr_others <- NULL
    }else{
      probes_chr <- probeset$NAME[probeset$CHR %in% c(chr, gsub("chr","", chr))]
      probes_chr_others <- probeset$NAME[! probeset$CHR %in% c(chr, gsub("chr","", chr))]
    }

    beta_chr <- beta[probes_chr, ]
    result_chr <- t(apply(beta_chr, 2, Calculate_Stat_by_range_v6))
    colnames(result_chr) <- paste0(colnames(result_chr), "_",chr)  
    if(!is.null(probes_chr_others)){
      beta_chr_others <- beta[probes_chr_others, ]
      result_chr_others <- t(apply(beta_chr_others, 2,Calculate_Stat_by_range_v6))    
      median_diff <- result_chr[,1] - result_chr_others[,1]
      mean_diff <- result_chr[,2] - result_chr_others[,2]
      colnames(result_chr_others) <- paste0(colnames(result_chr_others), "_others")    
    }else{
      result_chr_others <- NULL
      median_diff <- NULL
      mean_diff <- NULL
    }
    
    if(chr %in% c("chr11","chr20","all")){
        probes_chr_mat <- probes_chr[probes_chr %in% maternal_probes]
        result_chr_mat <- t(apply(beta[probes_chr_mat,], 2, Calculate_Stat_by_range))
        colnames(result_chr_mat) <- paste0(colnames(result_chr_mat), "_",chr,"_mat")  
        probes_chr_pat <- probes_chr[probes_chr %in% paternal_probes]
        result_chr_pat <- t(apply(beta[probes_chr_pat,], 2, Calculate_Stat_by_range))
        colnames(result_chr_pat) <- paste0(colnames(result_chr_pat), "_",chr,"_pat")  
        result_chr <- cbind(result_chr, result_chr_others, median_diff,mean_diff, result_chr_mat,result_chr_pat)
    }else{
        result_chr <- cbind(result_chr, result_chr_others,median_diff,mean_diff)
    }

    if(is.null(result_all)){
      result_all <- result_chr
    }else{
      result_all <- cbind(result_all,result_chr )
    }
  }
  result_all[is.na(result_all)] <- 0 
  return(result_all)
}


Calc_Stat_Fun <- function(value,low_cutoff=0.3, high_cutoff=0.7, method="ratio") {
    Between <-function(values, low_cutoff=0.3,high_cutoff=0.7){
      # return logical if values within the range [low_cutoff,high_cutoff]
      values > low_cutoff & values <=high_cutoff
    }
    ranges <- list(
      "low" = value[Between(value, 0,low_cutoff)],
      "med" = value[Between(value, low_cutoff,high_cutoff)],
      "high" = value[Between(value, high_cutoff,1)]
    )
    total_probes <- length(value)
    counts <- sapply(ranges, function(x) if (length(x) > 0) length(x) else 0)
    means <- sapply(ranges, function(x) if (length(x) > 0) mean(x) else 0) # NA    
    medians <- sapply(ranges, function(x) if (length(x) > 0) median(x) else 0) # NA
    ratio <- sapply(ranges, function(x) (length(x) / total_probes))
    sd <- sapply(ranges,  function(x) if (length(x) > 0) sd(x) else 0)
    all <- c(counts, round(ratio,3),round(medians,3),round(sd,3))
    names(all) <- c("count_low","count_med","count_high","ratio_low","ratio_med","ratio_high","median_low","median_med","median_high", "sd_low","sd_med","sd_high")
    names(counts) <- c("count_low","count_med","count_high")
    names(medians) <- c("median_low","median_med","median_high")
    names(means) <- c("mean_low","mean_med","mean_high")
    names(ratio) <- c("ratio_low","ratio_med","ratio_high")
    names(sd) <- c("sd_low","sd_med","sd_high")
    result <- switch(method,
        count=counts,
        mean=means,
        median=medians, 
        ratio=ratio, 
        sd=sd,
        all=all
    )
    # result <- list(count=counts, ratio=ratio, median=medians, sd=sd)
    return(result)
   }
##################################################################
 
##################################################################


###################################


Calc_Wasserstein  <- function(data1,data2) {
  # library(entropy)
  library(transport) # remotes::install_github("dschuhmacher/transport")
  ## calculate Wasserstein Distance
  x <- seq(min(min(data1), min(data2)), max(max(data1), max(data2)), length.out = 500)
  density1 <- density(data1, from = min(x), to = max(x), n = length(x))
  density2 <- density(data2, from = min(x), to = max(x), n = length(x))

  # Resample points based on estimated densities
  resampled_dist1 <- sample(density1$x, size = 500, prob = density1$y, replace = TRUE)
  resampled_dist2 <- sample(density2$x, size = 500, prob = density2$y, replace = TRUE)

  w_dist <- transport::wasserstein1d(resampled_dist1, resampled_dist2)


    set.seed(123) # For reproducibility
    n_permutations <- 1000
    wd_permutations <- numeric(n_permutations)
    for (i in 1:wd_permutations) {
      # Permute the data (this is a simple example; adapt as needed)
      P_perm <- sample(resampled_dist1, length(resampled_dist1), replace = TRUE)
      Q_perm <- sample(resampled_dist2, length(resampled_dist2), replace = TRUE)
      wd_permutations[i] <- transport::wasserstein1d(P_perm, Q_perm)
    }
  p_value <- mean(wd_permutations >= w_dist)

  #ks_result <- ks.test(resampled_dist1, resampled_dist2)
  #p_value <-  ks_result$p.value
  return(list(dist = w_dist, p.value =p_value))
  #return(list(dist = w_dist, p.value = p_value))
}


CalcImprintMed <- function(betaFile, metaFile, probeset = "selected",prefix=NULL) {
   
  input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
  beta <- input[["beta"]]
  meta <- input[["meta"]]
  probesets <- tmp[["probesets"]]
  used <- tmp[["beta"]]
  used <- na.omit(used) # removed NA
  all_probes <- intersect(probesets$NAME, rownames(used))
  maternal_probes <- intersect(probesets$NAME[grep("maternal", probesets$ORIGIN)], rownames(used))
  paternal_probes <- intersect(probesets$NAME[grep("paternal", probesets$ORIGIN)], rownames(used))
  maternal_beta <- used[maternal_probes, ]
  paternal_beta <- used[paternal_probes, ]

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
  maternal_median <- apply(maternal_beta, 2, median, na.rm = TRUE)
  maternal_sd <- apply(maternal_beta, 2, sd)
  paternal_median <- apply(paternal_beta, 2, median, na.rm = TRUE)
  paternal_sd <- apply(paternal_beta, 2, sd)
  
  meta_selectedColumns <- meta[, intersect(colnames(meta),c("Sample_Name","Sample_Group","ID2"))]
  result <- cbind(
    meta_selectedColumns,
    paternal_median = paternal_median, paternal_sd= paternal_sd,  
    maternal_median = maternal_median, maternal_sd= maternal_sd, 
  )
  if (!is.null(prefix)) {
    outFile1 <- paste0(prefix, "_ImprintMed.raw.txt")
    write.table(result, outFile1, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile1), "[saved]\n")
  }
  return(result)
}


##################################################################
#  01/20/2026,15:29:49 
##################################################################

#' Comprehensive Imprinting Analysis for imprintomeR
#' 
#' @param betaFile  Character. file of beta values (Probes as rownames, Samples as colnames).
#' @param metaFile  Character. file of sample information.
#' @param probeset  Character. the name of a predefined imprinting probeset.
#' @param ids_cutoff Numeric. The IDS distance threshold to call an EpiMutation (Default = 0.2).
#' @param region_name Character. Optional label for the genomic locus (e.g., "11p15").
#' 
#' @return A data frame with metrics, directional interpretations, and mutation calls.


CalcStatByGrp <- function(dat, meta,low_cutoff=0.3, high_cutoff=0.7) {
  # fucntion to calculate average value by Group
  # ID should match column name in datFile
  
  res <- NULL
  cn <- NULL
  for (group in unique(meta$Sample_Group)) {
    cols_grp <- colnames(dat)[colnames(dat) %in% meta$Sample_Name[meta$Sample_Group == group]]
    used <- dat[, cols_grp]
    if (length(cols_grp) == 1) {
      grp.mean <- used
      med <- Between(na.omit(used), low_cutoff,high_cutoff)
      low <- Between(na.omit(used), 0,low_cutoff)
      high <- Between(na.omit(used), high_cutoff,1)
    } else {
      grp.mean <- rowMeans(used)
      med <- rowSums(apply(used,2, function(x)Between(na.omit(x), low_cutoff,high_cutoff)))  # retention of imprinting 
      low <- rowSums(apply(used,2, function(x)Between(na.omit(x), 0,low_cutoff)))
      high <- rowSums(apply(used,2, function(x)Between(na.omit(x), high_cutoff,1)))
    }
    tmpDF <- data.frame(grp.mean, low, med, high)
    colnames(tmpDF) <- paste0(c("mean","low","med","high"),"_",group)
    if (is.null(res)) {
      res <- tmpDF
    } else {
      res <- cbind(res, tmpDF)
    }
  }
  return(res)
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


Calculate_Stat_by_range_v6 <- function(value,low_cutoff=0.3, high_cutoff=0.7) {
  # chrs_set1 <- c("chr1","chr2","chr4","chr6","chr7","chr8","chr14","chr15","chr16","chr19","chr22") # "chr13" is bad
  suppressMessages(suppressWarnings(library(mclust)))
  medians <- median(value)
  means <- mean(value)
  sd <- sd(value)
  capture.output({
      # mclust_result <- Mclust(na.omit(value))
      mclust_result <- densityMclust(na.omit(value))
  }, file = "/dev/null")
  if(length(value>150)){
    mclust <- sum( table(mclust_result$classification) >20)
  }else{  # if testing single chromosome
    mclust <- mclust_result$G
  }
  density1 <- density(value, n = length(value))$y
  
  result <- c(round(medians,3),round(means,3), round(sd,3),mclust)
  names(result) <- c("median","mean","sd","mclust")
  return(result)
  }


CallConumee <- function(rgSetFile, metaFile, outdir="CNV",arrayType="EPICv2", ctrlGrp="germline", ncores = 2,detail_regions = NULL){
  # reference: https://github.com/hovestadtlab/conumee2
  # https://bioconductor.org/packages/devel/bioc/vignettes/conumee/inst/doc/conumee.html
  # If 
  suppressMessages(library(minfi))
  GetIntensity <- function(RGset, anno) {
    MSet <- preprocessRaw(RGset)
    Methylated <- minfi::getMeth(MSet)
    Unmethylated <- getUnmeth(MSet)
    intensity <- Methylated + Unmethylated
    require(stringr)
    probes<- str_split_fixed(rownames(intensity),"[_]",2)[,1]
    intensity <- intensity[!duplicated(probes), ]
    rownames(intensity) <- probes[!duplicated(probes)]
    # Subset intensity to match probes
    common_probes <- intersect(rownames(intensity), names(anno@probes))
    print(length(common_probes))
    intensity_subset <- intensity[common_probes, ]
    return(intensity_subset)
  }

  #================================================================
  ParallelCNV <- function(outBaseDir, caseIntensity, ctrlIntensity, anno, detail_regions, ncores = 2) {
    suppressMessages(library(parallel))

   #================================================================
    runCNV <- function(case, outBaseDir, caseIntensity, ctrlIntensity, anno) {
      suppressMessages(library(minfi))
      suppressMessages(library("conumee"))
      #================================================================
      CNV.load.custom <- function(intensity,cases=NULL){
      object <- new("CNV.data")
      if(is.null(cases)){
        dat<- data.frame(intensity)
      } else if(length(cases)==1){
        dat<- data.frame(intensity[,cases])
        colnames(dat) <- cases
      }else{
        dat<- as.data.frame(intensity[,cases])
      }
      object@intensity <-dat
      object@date <- date()
      return(object)
     }
      #================================================================
      if (is.na(case)) {
        return(FALSE)
      }
      cat("\n\t", case)
      ref_cases <- CNV.load.custom(caseIntensity)
      query_case <- CNV.load.custom(caseIntensity,case)
      fit <- CNV.fit(query=query_case,ref=ref_cases, anno) 
      fit <- CNV.bin(fit)
      fit <- CNV.detail(fit)
      fit@bin$ratio[which(is.na(fit@bin$ratio))] <-0
      # segment <- CNV.segment(log2ratios, verbose = 0, undo.SD = 2) # verbose=3 to report detail
      segment <- CNV.segment(fit, verbose = 0, undo.SD = 2) # verbose=3 to report detail
      outdir <- paste(outBaseDir, "/", case, sep = "")
      rdsFile <- paste0(outdir,"/",case,".conumee.rds")
      dir.create(outdir, showWarnings = FALSE, recursive=T)
      if (!file.exists(rdsFile)){
          saveRDS(list(fit=fit, segment=segment),file= rdsFile)
      }
      pdf(paste(outdir, "/", case, "_CNVplots.pdf", sep = ""), height = 9, width = 18)
        CNV.genomeplot(segment)
      chrs <- paste("chr", c(as.character(1:22), "X", "Y"), sep = "")
      for (chr in chrs) {
        CNV.genomeplot(segment, chr = chr)
      }
      garbage <- dev.off()
      igvOut1 <- paste(outdir, "/", case, ".CNVbins.igv", sep = "")
      if (!file.exists(igvOut1)) {
        CNV.write(segment, file = igvOut1, what = "bins")
      }
      igvOut2 <- paste(outdir, "/", case, ".CNVprobes.igv", sep = "")
      if (!file.exists(igvOut2)) {
        CNV.write(segment, file = igvOut2, what = "probes")
      }
      segFile <- paste(outdir, "/", case, ".CNVsegments.seg", sep = "")
      if (!file.exists(segFile)) {
        CNV.write(segment, file = segFile, what = "segments")
      }
      if(!is.null(detail_regions)){
        detailFile <- paste(outdir, "/", case, ".CNVdetail.txt", sep = "")
        if (!file.exists(detailFile)) {
          CNV.write(segment, file = detailFile, what = "detail")
        }      
      }
      return(TRUE)
    }
    ######################################################
    sampleCount <- ncol(caseIntensity)
    if (sampleCount == 1) {
      res <- runCNV(colnames(caseIntensity)[1], outBaseDir, caseIntensity, ctrlIntensity, anno)
      return(res)
    }
    ######################################################
    avai_cores <- detectCores() - 1
    ncores <- ifelse(ncores > avai_cores, avai_cores, ncores)
    ncores <- ifelse(ncores > sampleCount, sampleCount, ncores)
   
    tryCatch(
      {
        # Initiate cluster
        cl <- makeCluster(ncores, outfile = "") # output error message to console
        clusterExport(cl, varlist = c(
          "outBaseDir", "ctrlIntensity", "caseIntensity", "anno", "runCNV"
        ), envir = environment())
        res <- parLapply(
          cl, 1:sampleCount,
          function(x) runCNV(colnames(caseIntensity)[x], outBaseDir, caseIntensity, ctrlIntensity, anno)
        )
        names(res) <- colnames(caseIntensity)
        stopCluster(cl)
      },
      error = function(e) print(e)
    ) #-------end tryCatch
    return(unlist(res))
  }
  #================================================================
  # load packages

  suppressMessages(suppressWarnings(library(minfi)))
  # detach("package:conumee", unload = TRUE)
  suppressMessages(suppressWarnings(library(conumee)))

  # check meta data file
  meta<- LoadMeta(metaFile)
  if(!any (ctrlGrp %in% meta$Sample_Group )){
    cat(paste0('\nError: ctrlGrp [',ctrlGrp,'] is not present in meta$Sample_Group\n'))
    q("no")
  }else{
    cat(paste0('\nInfo: ctrlGrp [',ctrlGrp,'] found.\n'))
  }
  #load  
  rgSet<- readRDS(rgSetFile)
  data(detail_regions, package = "conumee")
  data(exclude_regions, package = "conumee") 

  if(grepl("EPIC$", arrayType,ignore.case=T) ){
      rdsFile1 <- "~/bin/COMET/conumee_data/conumee.EPIC.annotation.rds"
      if(file.exists(rdsFile1)){
        anno <- readRDS(rdsFile1)
        cat(paste0('\n ',basename(rdsFile1),' [loaded]'))
      }else{
        anno <- CNV.create_anno(exclude_regions = exclude_regions, array_type = "EPIC", detail_regions = detail_regions, chrXY = FALSE)
        saveRDS(anno,file=rdsFile1)
        cat(paste0('\n ',basename(rdsFile1),' [saved]'))
      }
  }else if(grepl("EPICv2", arrayType,ignore.case=T) ){
      rdsFile2 <- "~/bin/COMET/conumee_data/conumee.EPICv2.annotation.rds"
      if(file.exists(rdsFile2)){
        anno <- readRDS(rdsFile2)
        cat(paste0('\n ',basename(rdsFile2),' [loaded]'))
      }else{
        anno <- Create.anno.EPICv2(outFile="./conumee.EPICv2.annotation.rds")
      }
  }else{ 
      rdsFile3 <- "~/bin/COMET/conumee_data/conumee.450k.annotation.rds"
      if(file.exists(rdsFile3)){
        anno <- readRDS(rdsFile3)
        cat(paste0('\n ',basename(rdsFile3),' [loaded]'))
      }else{
        anno <- CNV.create_anno(exclude_regions = exclude_regions, array_type = "450k", detail_regions = detail_regions, chrXY = FALSE)
        saveRDS(anno,file=rdsFile3)
        cat(paste0('\n ',basename(rdsFile3),' [saved]'))
      }        
    }

  # exclude_regions defines regions to be excluded (e.g. polymorphic regions, an example is given in data(exclude_regions)).
   # array_type:	 character . One of 450k, EPICv2, or overlap. Defaults to 450k.
  control_samples <- rownames(meta)[meta$Sample_Group %in% ctrlGrp]  # Replace with your control sample names
  cat("\n control samples:",paste(control_samples,collapse= ' '),"\n")
  query_samples <- rownames(meta)[! meta$Sample_Group %in% ctrlGrp] 
  cat("\n query samples:", paste(query_samples,collapse=' '),"\n")
  intesitity <- GetIntensity(rgSet,anno)
  control_intensity <- intesitity[, control_samples]  # Adjust indices
  query_intensity <- intesitity[,query_samples]
   #================================================================
  dir.create(outdir, showWarnings = FALSE, recursive=T)
  ts <- strtrim(Sys.time(), 19)
  cat(paste0('\nInfo: start ParallelCNV.[',ts,']\n'))
  ParallelCNV(outdir, query_intensity, control_intensity, anno, detail_regions, ncores =ncores)
  ts <- strtrim(Sys.time(), 19)
  cat(paste0('\nInfo: complete ParallelCNV.[',ts,']\n'))
}

#================================================================

##################################################################
# 04/03/2025, 08:10:05 
##################################################################
##################################################################
# 04/04/2025, 18:20:40 
##################################################################

CallGenotype <- function(rgSetFile, metaFile, outPrefix=NULL){
   # check if UPD affects SNP allele calling 
   # Their beta values approximate the proportion of one alleleâ€™s signal
   # (e.g., 0 for homozygous AA, ~0.5 for heterozygous AT, 1 for homozygous TT), allowing us to infer genotypes.
  suppressMessages(suppressWarnings(library(minfi)))
  outFile <- paste0(outPrefix,"_snpBeta.txt") 
  if(grepl(".*snpBeta.*txt",rgSetFile )){
     cat("\nINFO: input is a snpBeta.txt file.")
     cat("\n[",basename(outFile),"[loaded]")
     snpBeta <- read.table(rgSetFile, sep="\t",header=TRUE,fill=TRUE,stringsAsFactors = FALSE, as.is=TRUE,row.names=1 ,check.names=FALSE ,comment.char = "")
     cat("\n[dim:",nrow(snpBeta)," rows x",ncol(data),"cols]")
  }else if(file.exists(outFile)){
     cat("\nINFO: previous snpBeta.txt file found.")
     cat("\n[",basename(outFile),"[loaded]")
     snpBeta <- read.table(outFile, sep="\t",header=TRUE,fill=TRUE,stringsAsFactors = FALSE, as.is=TRUE,row.names=1 ,check.names=FALSE ,comment.char = "")
     cat("\n[dim:",nrow(snpBeta)," rows x",ncol(data),"cols]")
  }else{
     cat("\nINFO: input is a RGset file.")
     rgSet <- readRDS(rgSetFile)
     snpBeta <- getSnpBeta(rgSet)
     write.table(cbind(TargetID=rownames(snpBeta),snpBeta), outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
     cat("\n[",basename(outFile),"[saved]")

  }
  meta <- LoadMeta(metaFile)
  SAMPLEID <- ifelse("ID2" %in% colnames(meta),"ID2", "Sample_Name" )
  outFile <- paste0(outPrefix,"_snpBeta_heatmap.png")
  BetaHeatmap(snpBeta, meta, SAMPLEID=SAMPLEID,annoColumn=c("Sample_Group"), clusterRows=TRUE, clusterColumns=FALSE, outFile=outFile, imgSizeFactor=0.5 )
  p1a <- BetaBeePlot(snpBeta, meta, SAMPLEID=SAMPLEID, outFile=paste0(outPrefix,"_snpBeta_beeswarm_original_order.pdf"))
  p1b <- BetaBeePlot(snpBeta, meta, SAMPLEID=SAMPLEID, outFile=paste0(outPrefix,"_snpBeta_beeswarm_group_order.pdf"),orderByGroup=TRUE)  
  p2 <- BetaRidgeline(snpBeta, meta, SAMPLEID=SAMPLEID, outFile=paste0(outPrefix,"_snpBeta_ridgeline.png"))
  pdfFolder= ifelse(dir.exists(paste0(dirname(outPrefix),"/pdf_snp")),NULL, "pdf_snp") # skip 
  p3 <- BetaBeeswarm_chr(snpBeta, meta, SAMPLEID=SAMPLEID, outFile=paste0(outPrefix,"_snpBeta_beeswarm_chr.pdf"),pdfFolder=pdfFolder)
   print(table(meta$Sample_Group))
  if(any(grepl("germline$", meta$Sample_Group))){
      BetaBeePlot_SNP(snpBeta, meta, SAMPLEID=SAMPLEID, outFile=paste0(outPrefix,"_snpBeta_beeswarm_snp2_ctrl.germline.png"),ctrlgrp="germline",low_cutoff=0.3,  high_cutoff=0.7)
  }
  if(any(grepl("blood$", meta$Sample_Group))){
  BetaBeePlot_SNP(snpBeta, meta, SAMPLEID=SAMPLEID, outFile=paste0(outPrefix,"_snpBeta_beeswarm_snp2_ctrl.blood.png"),ctrlgrp="blood",low_cutoff=0.3,  high_cutoff=0.7)
  }  

}
#================================================================

CheckGap <- function(values){
  suppressMessages(suppressWarnings(library(mclust)))
  capture.output({
    # Fit density-based model
      mclust_fit <- densityMclust(na.omit(values))
  }, file = "/dev/null")
  # Check number of groups detected
  n_groups <- mclust_fit$G
  #cat("Number of groups detected: ", n_groups, "\n")
  if (n_groups == 2) {
    # Get cluster assignments
    cluster1 <- na.omit(values[mclust_fit$classification == 1])
    cluster2 <- na.omit(values[mclust_fit$classification == 2])
    # Compute the gap
    gap1 <- abs(min(cluster1) - max(cluster2))
    gap2 <- abs(min(cluster2) - max(cluster1))
    gap <- min(gap1, gap2)
  } else {
    gap <- NA
  }  
  result <- c(n_groups, gap)
  names(result) <- c("n_groups","gap")
  return(result)
}

##################################################################
# started: 06/23/2025,14:39:38 
##################################################################

Chr11p15_Classifier <- function(beta,meta, probeset = "chr11p15", prefix = NULL,high_cutoff=0.7,low_cutoff=0.3){
  # betaFile
  # probeset format
  #     Two columns: TargetID and GROUP;
  #     -TargetID: Illumina probeID;  like cg11753499
  #     -GROUP: values must be H19 or KCNQ1OT1

  #Loss of Heterozygosity (LOH): This is not directly related to imprinting but rather to the loss of one allele's genetic material. At 11p15, LOH can affect tumor suppressor genes like CDKN1C or the imprinted genes, potentially leading to cancer.
  
  #Loss of Imprinting (LOI): This occurs when the normal imprinting pattern is disrupted, leading to biallelic expression or silencing of genes that should be monoallelically expressed. 
  
  #Retention of Imprinting (ROI):This refers to the normal state where the methylation pattern of genes at the 11p15 locus is maintained as it should be according to the parental origin. 

  tmp  <- SubsetBeta_By_Probeset(beta, probeset=probeset,prefix=prefix)
  probesets <- tmp[["probesets"]]
  used <- tmp[["beta"]]
  used <- na.omit(used) # removed NA
  H19_probes <- intersect(probesets$NAME[grep("H19", probesets$GROUP)], rownames(used))
  KCNQ1OT1_probes <- intersect(probesets$NAME[grep("KCNQ1OT1", probesets$GROUP)], rownames(used))
  if (length(H19_probes) < 2) {
    cat("\nERROR: less than 2 probes in H19 locus..\n")
    q("no")
  }
  if (length(KCNQ1OT1_probes) < 2) {
    cat("\nERROR: less than 2 probes in KCNQ1OT1 locus..\n")
    q("no")
  }

  if (!all(unique(probesets$GROUP) %in% c("H19", "KCNQ1OT1"))) {
    cat("\nERROR: Invalid GROUP column in annotation file.\n")
    stop("exit.")
  }
  H19_probes_mean <- colMeans(used[H19_probes, ])   # paternal allele
  KCNQ1OT1_probes_mean <- colMeans(used[KCNQ1OT1_probes, ]) # maternal allele
  ROI <- H19_probes_mean < high_cutoff & KCNQ1OT1_probes_mean > low_cutoff
  LOI <- H19_probes_mean > high_cutoff | KCNQ1OT1_probes_mean < low_cutoff
  LOH <- (H19_probes_mean > high_cutoff & KCNQ1OT1_probes_mean < low_cutoff) & (abs(H19_probes_mean-KCNQ1OT1_probes_mean)>0.3)
  meta$chr11p15 <- "undertermined"
  meta$chr11p15[ROI] <- "ROI"
  meta$chr11p15[LOI] <- "LOI"
  meta$chr11p15[LOH] <- "LOH"
  detail <- data.frame(
    SAMPLE_NAME = colnames(used), SAMPLE_GROUP = meta$Sample_Group,
    H19_probes_mean = H19_probes_mean, t(used[H19_probes, ]),
    KCNQ1OT1_probes_mean = KCNQ1OT1_probes_mean,
    t(used[KCNQ1OT1_probes, ]),
    chr11p15 = meta$chr11p15
  )
  result <- data.frame(
    SAMPLE_NAME = colnames(used), SAMPLE_GROUP = meta$Sample_Group,H19_probes_mean = H19_probes_mean,KCNQ1OT1_probes_mean = KCNQ1OT1_probes_mean,
    chr11p15 = meta$chr11p15
  )
  # results <- cbind(meta[IDs, c("Sample_Name", "Sample_Group")], results)
  if (!is.null(prefix)) {
    outFile1 <- paste0(prefix, "_chr11p15.status.txt")
    write.table(result, outFile1, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile1), "[saved]\n")
    tab <- table(result[,c("Sample_Group","chr11p15")])
    summary_df <-  as.data.frame.matrix(tab)

    outFile2 <- paste0(prefix, "_chr11p15.status_summary.txt")
    write.table(cbind(SAMPLE_GROUP=rownames(summary_df),summary_df), outFile2, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile2), "[saved]\n")
    #outFile2 <- paste0(prefix, "_11p15.status_details.txt")
    #write.table(detail, outFile2, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    #cat("\n", basename(outFile2), "[saved]\n")
  }
  return(result)
}

# ====================================================================

Chr11p15_Classifier2 <- function(beta,meta, probeset = "chr11p15", prefix = NULL,high_cutoff=0.7,low_cutoff=0.3){
  # betaFile
  # probeset format
  #     Two columns: TargetID and GROUP;
  #     -TargetID: Illumina probeID;  like cg11753499
  #     -GROUP: values must be H19 or KCNQ1OT1

  #Loss of Heterozygosity (LOH): This is not directly related to imprinting but rather to the loss of one allele's genetic material. At 11p15, LOH can affect tumor suppressor genes like CDKN1C or the imprinted genes, potentially leading to cancer.
  
  #Loss of Imprinting (LOI): This occurs when the normal imprinting pattern is disrupted, leading to biallelic expression or silencing of genes that should be monoallelically expressed. 
  
  #Retention of Imprinting (ROI):This refers to the normal state where the methylation pattern of genes at the 11p15 locus is maintained as it should be according to the parental origin. 

  tmp  <- SubsetBeta_By_Probeset(beta, probeset=probeset,prefix=prefix)
  probesets <- tmp[["probesets"]]
  used <- tmp[["beta"]]
  used <- na.omit(used) # removed NA
  H19_probes <- intersect(probesets$NAME[grep("H19", probesets$GROUP)], rownames(used))
  KCNQ1OT1_probes <- intersect(probesets$NAME[grep("KCNQ1OT1", probesets$GROUP)], rownames(used))
  if (length(H19_probes) < 2) {
    cat("\nERROR: less than 2 probes in H19 locus..\n")
    q("no")
  }
  if (length(KCNQ1OT1_probes) < 2) {
    cat("\nERROR: less than 2 probes in KCNQ1OT1 locus..\n")
    q("no")
  }

  if (!all(unique(probesets$GROUP) %in% c("H19", "KCNQ1OT1"))) {
    cat("\nERROR: Invalid GROUP column in annotation file.\n")
    stop("exit.")
  }
  H19_probes_mean <- colMeans(used[H19_probes, ])   # IC1, paternal allele methylated 
  KCNQ1OT1_probes_mean <- colMeans(used[KCNQ1OT1_probes, ]) #IC2,  maternal allele methylated
  IC1_ROI <- H19_probes_mean < high_cutoff & H19_probes_mean > low_cutoff
  IC2_ROI <- KCNQ1OT1_probes_mean < high_cutoff & KCNQ1OT1_probes_mean > low_cutoff
  ROI <- IC1_ROI & IC2_ROI
  IC1_GOM <-  H19_probes_mean > high_cutoff & IC2_ROI == TRUE  #Paternal uniparental disomy (UPD), paternal gain (BWS)
  IC1_LOM  <-  H19_probes_mean < 0.5 & IC2_ROI == TRUE & (KCNQ1OT1_probes_mean-H19_probes_mean)>0.1 #IC1 loss of methylation ,or Maternal duplication, SRS-like
  IC2_GOM <-  IC1_ROI == TRUE &  KCNQ1OT1_probes_mean > high_cutoff  #IC2 gain of methylation (e.g. BWS subtype)
  IC2_LOM <-  IC1_ROI == TRUE  & KCNQ1OT1_probes_mean < low_cutoff & H19_probes_mean > 0.45 #IC2 loss of methylation (e.g. BWS subtype)
  pUPD <- H19_probes_mean > high_cutoff & KCNQ1OT1_probes_mean < low_cutoff # Mixed patterns, often paternal UPD
  mUPD <- H19_probes_mean < 0.4  & KCNQ1OT1_probes_mean > high_cutoff
  LOM <- H19_probes_mean < low_cutoff & KCNQ1OT1_probes_mean < low_cutoff

  #LOH <- (H19_probes_mean > high_cutoff & KCNQ1OT1_probes_mean < low_cutoff) & (abs(H19_probes_mean-KCNQ1OT1_probes_mean)>0.3)
  meta$chr11p15 <- "Unknown" #"undertermined"
  meta$chr11p15[ROI] <- "ROI"
  meta$chr11p15[IC1_GOM] <- "IC1_GOM,IC2_ROI"  # pUPD_pGOM,IC2_ROI
  meta$chr11p15[IC1_LOM] <- "IC1_LOM,IC2_ROI"  
  meta$chr11p15[IC2_GOM] <- "IC1_ROI,IC2_GOM"
  meta$chr11p15[IC2_LOM] <- "IC1_ROI,IC2_LOM"
  meta$chr11p15[LOM] <- "LOM,11p15 deletion"  
  meta$chr11p15[pUPD] <- "pUPD"
  meta$chr11p15[mUPD] <- "mUPD"
  detail <- data.frame(
    SAMPLE_NAME = colnames(used), SAMPLE_GROUP = meta$Sample_Group,
    H19_probes_mean = H19_probes_mean, t(used[H19_probes, ]),
    KCNQ1OT1_probes_mean = KCNQ1OT1_probes_mean,
    t(used[KCNQ1OT1_probes, ]),
    chr11p15 = meta$chr11p15
  )
  result <- data.frame(
    SAMPLE_NAME = colnames(used), SAMPLE_GROUP = meta$Sample_Group,IC1_mean = H19_probes_mean,IC2_mean = KCNQ1OT1_probes_mean,
    chr11p15 = meta$chr11p15
  )
  # results <- cbind(meta[IDs, c("Sample_Name", "Sample_Group")], results)
  if (!is.null(prefix)) {
    outFile1 <- paste0(prefix, "_chr11p15.class.txt")
    write.table(result, outFile1, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile1), "[saved]\n")
    tab <- table(result[,c("Sample_Group","chr11p15")])
    summary_df <-  as.data.frame.matrix(tab)

    outFile2 <- paste0(prefix, "_chr11p15.class_summary.txt")
    write.table(cbind(SAMPLE_GROUP=rownames(summary_df),summary_df), outFile2, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile2), "[saved]\n")
    #outFile2 <- paste0(prefix, "_11p15.status_details.txt")
    #write.table(detail, outFile2, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    #cat("\n", basename(outFile2), "[saved]\n")
  }
  return(result)
}
# ====================================================================

Chr11p15_Classifier3 <- function(beta,meta, probeset = "chr11p15", prefix = NULL,high_cutoff=0.7,low_cutoff=0.3){
  # betaFile
  # probeset format
  #     Two columns: TargetID and GROUP;
  #     -TargetID: Illumina probeID;  like cg11753499
  #     -GROUP: values must be H19 or KCNQ1OT1

  #Loss of Heterozygosity (LOH): This is not directly related to imprinting but rather to the loss of one allele's genetic material. At 11p15, LOH can affect tumor suppressor genes like CDKN1C or the imprinted genes, potentially leading to cancer.
  
  #Loss of Imprinting (LOI): This occurs when the normal imprinting pattern is disrupted, leading to biallelic expression or silencing of genes that should be monoallelically expressed. 
  
  #Retention of Imprinting (ROI):This refers to the normal state where the methylation pattern of genes at the 11p15 locus is maintained as it should be according to the parental origin. 

  tmp  <- SubsetBeta_By_Probeset(beta, probeset=probeset,prefix=prefix)
  probesets <- tmp[["probesets"]]
  used <- tmp[["beta"]]
  used <- na.omit(used) # removed NA
  H19_probes <- intersect(probesets$NAME[grep("H19", probesets$GROUP)], rownames(used))
  KCNQ1OT1_probes <- intersect(probesets$NAME[grep("KCNQ1OT1", probesets$GROUP)], rownames(used))
  if (length(H19_probes) < 2) {
    cat("\nERROR: less than 2 probes in H19 locus..\n")
    q("no")
  }
  if (length(KCNQ1OT1_probes) < 2) {
    cat("\nERROR: less than 2 probes in KCNQ1OT1 locus..\n")
    q("no")
  }

  if (!all(unique(probesets$GROUP) %in% c("H19", "KCNQ1OT1"))) {
    cat("\nERROR: Invalid GROUP column in annotation file.\n")
    stop("exit.")
  }

  H19_probes_mean <- colMeans(used[H19_probes, ])   # IC1, paternal allele methylated 
  KCNQ1OT1_probes_mean <- colMeans(used[KCNQ1OT1_probes, ]) #IC2,  maternal allele methylated
  abs_diff <- abs(KCNQ1OT1_probes_mean-H19_probes_mean) >0.2
  IC1_ROI <- H19_probes_mean < high_cutoff & H19_probes_mean > low_cutoff
  IC2_ROI <- KCNQ1OT1_probes_mean < high_cutoff & KCNQ1OT1_probes_mean > low_cutoff
  ROI <- IC1_ROI & IC2_ROI
  IC1_GOM <-  H19_probes_mean > high_cutoff & IC2_ROI == TRUE & abs_diff #Paternal uniparental disomy (UPD), paternal gain (BWS)
  IC1_LOM <-  H19_probes_mean < low_cutoff & IC2_ROI == TRUE & abs_diff #IC1 loss of methylation ,or Maternal duplication, SRS-like
  IC2_GOM <-  IC1_ROI == TRUE &  KCNQ1OT1_probes_mean > high_cutoff & abs_diff #IC2 gain of methylation (e.g. BWS subtype)
  IC2_LOM <-  IC1_ROI == TRUE  & KCNQ1OT1_probes_mean < low_cutoff & abs_diff #IC2 loss of methylation (e.g. BWS subtype)
  pUPD <- H19_probes_mean > high_cutoff & KCNQ1OT1_probes_mean < low_cutoff # Mixed patterns, often paternal UPD
  mUPD <- H19_probes_mean < low_cutoff  & KCNQ1OT1_probes_mean > high_cutoff
  LOM <- H19_probes_mean < low_cutoff & KCNQ1OT1_probes_mean < low_cutoff

  #LOH <- (H19_probes_mean > high_cutoff & KCNQ1OT1_probes_mean < low_cutoff) & (abs(H19_probes_mean-KCNQ1OT1_probes_mean)>0.3)
  meta$chr11p15 <- "Unknown" #"undertermined"
  meta$chr11p15[ROI] <- "ROI"
  meta$chr11p15[IC1_GOM] <- "IC1_GOM,IC2_ROI"  # pUPD_pGOM,IC2_ROI
  meta$chr11p15[IC1_LOM] <- "IC1_LOM,IC2_ROI"  
  meta$chr11p15[IC2_GOM] <- "IC1_ROI,IC2_GOM"
  meta$chr11p15[IC2_LOM] <- "IC1_ROI,IC2_LOM"
  meta$chr11p15[LOM] <- "LOM,11p15 deletion"  
  meta$chr11p15[pUPD] <- "pUPD"
  meta$chr11p15[mUPD] <- "mUPD"
  detail <- data.frame(
    SAMPLE_NAME = colnames(used), SAMPLE_GROUP = meta$Sample_Group,
    H19_probes_mean = H19_probes_mean, t(used[H19_probes, ]),
    KCNQ1OT1_probes_mean = KCNQ1OT1_probes_mean,
    t(used[KCNQ1OT1_probes, ]),
    chr11p15 = meta$chr11p15
  )
  result <- data.frame(
    SAMPLE_NAME = colnames(used), SAMPLE_GROUP = meta$Sample_Group,IC1_mean = H19_probes_mean,IC2_mean = KCNQ1OT1_probes_mean,
    chr11p15 = meta$chr11p15
  )
  # results <- cbind(meta[IDs, c("Sample_Name", "Sample_Group")], results)
  if (!is.null(prefix)) {
    outFile1 <- paste0(prefix, "_chr11p15.class.v3.txt")
    write.table(result, outFile1, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile1), "[saved]\n")
    tab <- table(result[,c("Sample_Group","chr11p15")])
    summary_df <-  as.data.frame.matrix(tab)

    outFile2 <- paste0(prefix, "_chr11p15.class.v3_summary.txt")
    write.table(cbind(SAMPLE_GROUP=rownames(summary_df),summary_df), outFile2, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile2), "[saved]\n")
    #outFile2 <- paste0(prefix, "_11p15.status_details.txt")
    #write.table(detail, outFile2, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    #cat("\n", basename(outFile2), "[saved]\n")
  }
  return(result)
}

# ====================================================================

ComputeGenotypePvalue <- function(loh_results,input=NULL, status_cols=c("Tumor_Genotype","Normal_Genotype"),method="chisq", group="Mosaic", verbose=F){
  if(! all(status_cols %in% colnames(loh_results))){
    if(verbose) cat(paste0("\nERROR: invaid status_cols."))
     return(NA)
  }
  if(is.null(input)){
   # input <- rbind(table(loh_results[,status_cols[1]]), table(loh_results[,status_cols[2]]))  
   #print(table(loh_results[,status_cols[1]]))
   #print(table(loh_results[,status_cols[2]]))
    Tumor_Genotype <- c(sum (loh_results[,status_cols[1]] %in% "Heterozygous"),  sum (loh_results[,status_cols[1]] %in% "Homozygous"), sum (loh_results[,status_cols[1]] %in% "Mosaic"))
    Normal_Genotype <- c(sum (loh_results[,status_cols[2]] %in% "Heterozygous"),  sum (loh_results[,status_cols[2]] %in% "Homozygous"), sum (loh_results[,status_cols[2]] %in% "Mosaic"))
    input <- rbind(Tumor_Genotype,Normal_Genotype)
    colnames(input) <- c("Heterozygous","Homozygous","Mosaic")
    rownames(input) <- status_cols    
  }
  pvalue <- NA
  if(method=="chisq"){#Overall shift in genotype distribution (2Ã—3 chi-square)
    #print(input)
    res <- chisq.test(input)
    if(verbose) cat("\nINFO: Overall shift in genotype distribution pvalue by chi-square is ", res$p.value)
    pvalue <- res$p.value  
  }else if(method=="fisher"){   # Mosaic LOH specifically (Mosaic vs non-Mosaic; Fisherâ€™s exact)    
    input2 <-  cbind(input, Others=rowSums(input[, !grepl(group, colnames(input))]))
    input2 <- input2[ , colnames(input2) %in% c(group, "Others")]
    max_per_col <- apply(input2, 2, max)
    names(max_per_col) <- colnames(input2)
    if(max_per_col[group]<10){
      cat("\nWARN:",paste0("Too few SNPs (n=",max_per_col[group],") in [",group,"] group for reliable LOH estimation."))
    }
    res <- fisher.test(input2) 
    if(verbose) cat(paste0("\nINFO: ", group,"_vs_other pvalue by Fisher\'s extact is ", res$p.value))  
    pvalue <- res$p.value    
  }else if(method=="paired"){     
   input3 <- loh_results[,status_cols]
   input3 <- input3[apply(input3== group, 1, any), ]
   res<- DescTools::McNemarExactTest(input3)
   if(verbose) cat(paste0("\nINFO: ", group,"_vs_other pvalue by paired extact test is ", res$p.value))
   pvalue <- res$p.value   
  }else{
    if(verbose) cat(paste0('\nWARN: invalid method was given.',method ))
    return(NA)
  }
  return(pvalue)
}

##################################################################
#  08/14/2025,16:36:00 
##################################################################


Create.anno.EPICv2 <- function(outFile="~/bin/COMET/conumee_data/conumee.EPICv2.annotation.rds"){
  # Create EPICv2 annotation with conumee 2.0
  anno_v2 <- conumee2::CNV.create_anno(array_type = "EPICv2", chrXY = FALSE)

  # Extract exclude regions (optional)
  exclude_regions2 <- anno_v2@exclude
  detail_regions2 <- anno_v2@detail
  # Create base annotation with original conumee (EPIC as fallback)
  anno_base <- conumee::CNV.create_anno(bin_minprobes = 15, bin_minsize = 50000,
    bin_maxsize = 5000000, array_type = "EPIC", chrXY = FALSE,
    exclude_regions = exclude_regions, detail_regions=detail_regions)

  # Extract probe info from anno_v2
  probe_data <- as.data.frame(anno_v2@probes)
  probe_df <- data.frame(
    chr = probe_data$seqnames,
    start = probe_data$start,
    end = probe_data$end,
    name = rownames(probe_data)
  )
  # Replace probes with EPICv2 full set
  library(GenomicRanges)
  epicv2_gr <- GRanges(
    seqnames = probe_df$chr,
    ranges = IRanges(start = probe_df$start, end = probe_df$end,NAMES=probe_df$name),
    names = probe_df$name,
  )
  anno_base@probes <- epicv2_gr
  outFile <- "~/bin/COMET/conumee_data/conumee.EPICv2.annotation.rds"
  saveRDS(anno_base,file=rdsFile)
  cat(paste0('\n ',basename(rdsFile),' [saved]'))
  return(anno_base)
}

##################################################################
#  04/04/2025,11:48:32 
##################################################################




DETECT_LOH_BATCH <- function(metaFile,betaFile, normal_id=NULL, het_threshold = 0.1, mosaic_threshold = 0.2, hom_threshold = 0.3, verbose=FALSE, outFile="LOH_SNP.txt"){
    if(class(metaFile) == "data.frame" & class(betaFile) == "data.frame"){
      meta <- metaFile
      beta <- betaFile
    } else{
      input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
      meta <- input[["meta"]]
      beta <- input[["beta"]]      
    }
   
    if(is.null(normal_id)){
      normal_id <- meta$Sample_Name[grep("germline", meta$Sample_Group)[1]]
    }
    if(! normal_id %in% meta$Sample_Name){
      cat(paste0('\nERROR: invalid normal_id',normal_id))
      q('no')
    }

    status <- data.frame(
      SAMPLE_NAME = character(),
      SAMPLE_GROUP = character(),
      Heterozygous =numeric(), 
      Homozygous=numeric(),
      Mosaic=numeric(), 
      LOH_status=character(),
      LOH_p.value = logical()
    )
    r <- 0
    for (id in meta$Sample_Name ){ 
      r <- r+1
        if ("ID2" %in% colnames(meta)) {
          cat("\n\n**",   meta$ID2[meta$Sample_Name %in% id],"**\n")
        }else{
          cat("\n\n**",  id) 
        }
        #x <- estimate_tumor_purity (beta,  normal_id, id)
        x= DETECT_LOH_SINGLE(beta, normal_id, id, het_threshold = 0.1, mosaic_threshold = 0.2, hom_threshold = 0.3,verbose=FALSE)
        # cat("\n") ; print(table(x$Tumor_Genotype,useNA="always"));cat("\n")
        genotype_counts <-  c(sum (x$Tumor_Genotype %in% "Heterozygous"),  sum (x$Tumor_Genotype %in% "Homozygous"), sum (x$Tumor_Genotype %in% "Mosaic"))
        final <- SampleLevelLOH_STAT(x,status_cols=c("Tumor_Genotype","Normal_Genotype"),method="chisq", group="Mosaic", verbose=F)
        cat("\nSNP_LOH_status=", final$status, ", p.value=",final$p.value)
        status[r,] <- c(id,NA, genotype_counts, final$status, final$p.value)
    }
    status$SAMPLE_GROUP <- meta[status$SAMPLE_NAME,"Sample_Group"]
    if(!is.null(outFile)){
      write.table(status, outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
      cat("\n[",basename(outFile),"[saved]")
    }
    loh_tmp= DETECT_LOH_SINGLE(beta, normal_id, normal_id, het_threshold = 0.1, mosaic_threshold = 0.2, hom_threshold = 0.3,verbose=FALSE)
    het_probeset <- loh_tmp$NAME[loh_tmp$Normal_Genotype %in% "Heterozygous"]
    pdfFile <- paste0(tools::file_path_sans_ext(outFile),"_hetSNPs_lineplot.pdf")
    plot_tmp <- PLOT_SNP_LOH (beta, meta, summary_tbl=status, SAMPLEID = "Sample_Name", outFile = pdfFile, alpha = 1, usedProbes=het_probeset)
    return(status)
}
#================================================================


DETECT_LOH_ICR <- function(beta, meta, chr="all", group="ORIGIN", mosaic_threshold = 0.1, hom_threshold = 0.2,prefix=NULL,probeset="selected"){
  if(!is.null(probeset)){
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggridges")))
    probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds") 
    if (probeset %in% names(probesets)) {
      probes <- probesets[[probeset]]
    } else {
      cat("\nERROR: unavailable probeset & probes not given.\n")
      q("no")
    }
    if(group %in% colnames(probes)){
       anno <- probes[,c("CHR","MAPINFO","Closest_TSS_gene_name",group)]  
       colnames(anno)[3:4] <- c("GENE","CATEGORY")
    }else{
     anno <- probes[,c("CHR","MAPINFO","Closest_TSS_gene_name")] 
     anno$CATEGORY <- "NA"
     colnames(anno)[3] <- "GENE"
    }
    rownames(anno) <- probes$NAME
  }else{
    version <- "HG19"
    # load aggregated annotation object
    if (is.null(probes.all)) {
      probes.all <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/anno.uniq_harmonized.liftover.rds")
    }
    chr <- paste0("CHR_", toupper(version))
    mapinfo <- paste0("MAPINFO_", toupper(version))
    anno <- probes.all[probes.all$NAME %in% rownames(beta), c(chr, mapinfo, "UCSC_REFGENE_NAME")]
    colnames(anno) <- c("CHR", "MAPINFO", "GENE")
    anno$CATEGORY <- "NA"
  }
  if( chr != "all"){
  cat("\nINFO: subset probes by ", chr)
    anno$CHR <- paste0("chr",gsub("chr","",anno$CHR))
    chr <- paste0("chr",gsub("chr","",chr))
    idx <- anno$CHR %in% tolower(chr)
    if(sum(idx) <10){
      cat("\nERROR: no matched [",chr,"] in probeset [",probeset,"]\n")
      return(NULL)
    }
    anno <- anno[anno$CHR %in% chr,]
  }else{
    cat("\nINFO: use all probes in probeset.")
  }
  common_probes <- intersect(rownames(anno), rownames(beta))

  beta <- beta[common_probes, ]

  TargetIDs <- rownames(beta)
  validIds <- intersect(meta$Sample_Name, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$Sample_Name %in% validIds]
  if (length(validIds) ==1) {
    beta=data.frame(beta[, validIds])
    rownames(beta) <- rownames(beta)
    colnames(beta) <- validIds
    meta <- meta[validIds, ]
  }else  if (length(validIds) > 1) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$Sample_Name. \n")
    return(NULL)
  } 
  colnames(beta) <- newIDs 
  beta$Probe=rownames(beta)
  beta$CATEGORY= anno[common_probes,"CATEGORY"]

  suppressMessages({
    used <- reshape2::melt(beta, id.vars = c("Probe", "CATEGORY"),variable.name = "ID",value.name = "value")
  })

  used <- used[used$CATEGORY %in% c("paternal","maternal"),]
  used$value <- as.numeric(as.character(used$value))
  print(dim(used))

  median_paternal <-  median(used$value[used$CATEGORY %in% "paternal"])
  median_maternal <-  median(used$value[used$CATEGORY %in% "maternal"])

    # Assign biological states
  classify <- function(median_paternal, median_maternal,hom_threshold,mosaic_threshold) {
        if (median_paternal > (0.5+hom_threshold) & median_maternal < (0.5-hom_threshold )) return("LOH [paternal]")
        else if (median_paternal < (0.5-hom_threshold ) & median_maternal > (0.5+hom_threshold) ) return("LOH [maternal]")
        else if (median_paternal > (0.5+mosaic_threshold) || median_paternal < (0.5-mosaic_threshold)) return("Mosaic LOH [paternal]")
        else if (median_maternal > (0.5+mosaic_threshold) || median_maternal < (0.5-mosaic_threshold)) return("Mosaic LOH [maternal]")
        else return("Normal")       
  }

  test_res <-  classify(median_paternal, median_maternal,hom_threshold,mosaic_threshold)
  cat("\nINFO: paternal_median=",median_paternal, "; median_maternal=",median_maternal )
  cat("\nINFO: status could be ",test_res  )
  id <- meta$Sample_Name[1]
  cat("\nINFO: generate density plot ...\n")
  scale = 1.2; alpha = 0.5
  pg <- ggplot(used, aes(x = value,fill = CATEGORY)) +
    geom_density(alpha = alpha) +
    theme_classic(base_size = 8) +
    theme(axis.text.x = element_text(angle = 0, vjust = 0.5, hjust = 1)) +
    labs(x = "methylation level", y="density",  title=id, subtitle=paste0("chr: ",chr,"; state:", test_res)) +
    geom_vline(xintercept = c(median_paternal, median_maternal), colour = "grey70", linetype = "dashed", linewidth = 0.25) +
    annotate("text", x =median_paternal, y = 2, label = round(median_paternal,2), angle = 90, size = 2) +
    annotate("text", x =median_maternal, y = 2, label = round(median_maternal,2), angle = 90, size = 2)+
    theme(
      plot.title = element_text(size = 10),
      plot.subtitle = element_text(size = 8)
    )

    outFile <- paste0(prefix, "_ICR_LOH_",chr,".pdf")
    ggsave(file = outFile, pg, width = 6, height = 4, units = "in", limitsize = F)
    cat(paste0('INFO:\n ',basename(outFile),' [saved]'))
}
#================================================================



DETECT_LOH_SINGLE <- function(beta, normal_id, tumor_id, het_threshold = 0.1, mosaic_threshold = 0.2, hom_threshold = 0.3, verbose=FALSE) {
  # provide probe level details about Allelic_Imbalance, Normal_Genotype, Tumor_Genotype,LOH and MosaicLOH
   # Mosaic LOH involves a partial loss of one allele in a subset of cells, leading to a shift in Beta values 
  # (e.g., from ~0.5 for heterozygous SNPs to values like 0.3 or 0.7) rather than a complete shift to homozygosity (Beta ~0 or ~1).
  # The probability of mosaic LOH quantifies the likelihood that such a shift reflects allelic imbalance due to mosaicism,
  # accounting for factors like tumor purity and technical noise.
  # method -binomial, use model to estimate mosaic LOH probability for paired samples
  # method -mixture, use a mixture model for unpaired or robust analysis.
  # The function doesnâ€™t account for copy number variations (CNV), which can mimic LOH signals (e.g., copy-neutral LOH). Combine with CNV analysis (e.g., conumee) for robustness.

  # Initialize results
  loh_results <- data.frame(
    NAME = rownames(beta),
    Het_Flag = FALSE,
    Normal_Beta = beta[, normal_id],
    Tumor_Beta = beta[, tumor_id],
    Allelic_Imbalance = 0,
    Normal_Genotype=NA,
    Tumor_Genotype=NA,    
    LOH = FALSE,
    MosaicLOH = FALSE
  )
  
  # Handle NA values
  loh_results$Normal_Beta[is.na(loh_results$Normal_Beta)|is.infinite(loh_results$Normal_Beta)|is.nan(loh_results$Normal_Beta)] <- 0.5
  loh_results$Tumor_Beta[is.na(loh_results$Tumor_Beta)|is.infinite(loh_results$Tumor_Beta)|is.nan(loh_results$Tumor_Beta)] <- 0.5
 
  # Identify heterozygous probes in normal (0.4 <= Beta <= 0.6)
  het <- abs(loh_results$Normal_Beta - 0.5) <= het_threshold
  if(verbose)  cat(paste0('\nINFO: using abritary norm of 0.5, num_het_probes = ',sum(het)))
  het_mean <- mean(loh_results$Normal_Beta[het],na.rm = TRUE)

  if(abs(het_mean -0.5)>0.05){
    het <- abs(loh_results$Normal_Beta - het_mean) <= het_threshold
    if(verbose)  cat(paste0(', num_het_probes = ',sum(het),"[used]"))
  }else{
    het_mean <- 0.5
  }  
  if (sum(het) < 10) {
    warning("Too few heterozygous SNPs for probability/p-value calculation.")
  }
   if(verbose)  cat(paste0('\nINFO: using het_mean_actual of ',round(het_mean,3)))
   loh_results$Het_Flag <- het
  # Calculate allelic imbalance (absolute deviation from 0.5, or het_mean)
  loh_results$Allelic_Imbalance[het] <- abs(loh_results$Tumor_Beta[het] - het_mean)
  
  hom <- abs(loh_results$Normal_Beta - het_mean) >= hom_threshold
  mos <- abs(loh_results$Normal_Beta - het_mean) > het_threshold & abs(loh_results$Normal_Beta - het_mean) < mosaic_threshold

  # Identify homozygous in tumor (Beta <= 0.2 or Beta >= 0.8)
  tumor_het <- abs(loh_results$Tumor_Beta - het_mean) <= het_threshold
  tumor_mos <- abs(loh_results$Tumor_Beta - het_mean) > het_threshold & abs(loh_results$Tumor_Beta - het_mean) < mosaic_threshold
  tumor_hom <- abs(loh_results$Tumor_Beta - het_mean) >= hom_threshold | abs(loh_results$Tumor_Beta - het_mean) >= mosaic_threshold


  # LOH: heterozygous in normal AND homozygous in tumor
  loh_results$LOH[het & tumor_hom] <- TRUE
  if(verbose)  cat(paste0('\nINFO: LOH probes by thresholds, ',sum(loh_results$LOH))) 
  #MosaicLOH:  heterozygous in normal AND homozygous in tumor
  loh_results$MosaicLOH[het & tumor_mos ] <- TRUE
  if(verbose)  cat(paste0('\nINFO: MosaicLOH probes by thresholds, ',sum(loh_results$MosaicLOH))) 

 # Classify tumor Beta values
 loh_results$Normal_Genotype[het] <- "Heterozygous"
 loh_results$Normal_Genotype[hom] <- "Homozygous"
 loh_results$Normal_Genotype[mos] <- "Mosaic"
 
 loh_results$Tumor_Genotype[tumor_het] <- "Heterozygous"
 loh_results$Tumor_Genotype[tumor_hom] <- "Homozygous"
 loh_results$Tumor_Genotype[tumor_mos] <- "Mosaic"
 #print(table(loh_results$Normal_Genotype,useNA="always"))
 #print(table(loh_results$Tumor_Genotype,useNA="always"))
 cat("\n")
 #print(loh_results[is.na(loh_results$Tumor_Genotype),])
  return(loh_results)
}

#================================================================

DIST_FAST <- function(sample, control, probeset = "selected", outPrefix = NULL, ncores = 20, verbose = TRUE) {
  # 02/09/2025, 17:23:25 
  library("parallel")
  RUN_TEST <- function(x, sampleSet, controlSet,ctrlGroup) {
    sample1 <- sampleSet[, x]
    dist <- NULL
    PVAL <- NULL
    cat(paste0("\n processing ", x, ".."))
    for (y in seq(ncol(controlSet))) {
      #cat(y,".")
      sample2 <- controlSet[, y]
      #res <- Calc_KS(sample1, sample2)
      res <- Calc_Wasserstein(sample1, sample2)

      dist <- c(dist, res[["dist"]])
      PVAL <- c(PVAL, res[["p.value"]])
    }
    dist_grp <- aggregate(dist ~ ctrlGroup, FUN = min)
    dist_grp_values <- dist_grp$dist
    names(dist_grp_values) <- dist_grp$ctrlGroup
    PVAL_grp <- aggregate(PVAL ~ ctrlGroup, FUN = min)
    PVAL_grp_values <- PVAL_grp$PVAL
    names(PVAL_grp_values) <- PVAL_grp$ctrlGroup
    category= names(dist_grp_values)[which.min(dist_grp_values)]
    result <- c(dist_grp_values, PVAL_grp_values, category)
    names(result) <- c(paste(names(dist_grp_values), "_dist", sep = ""), paste(names(PVAL_grp_values), "_p.value", sep = ""), "category")
    # print(result)
    return(invisible(result))
  }
  #================================================================
   #skip run if previous scoring result is 
  outFile <- paste0(outPrefix,"_dist_test.txt")
  if(file.exists(outFile)){
      result <- read.table(outFile, sep="\t",header=TRUE,fill=TRUE,stringsAsFactors = FALSE, as.is=TRUE,row.names=NULL ,check.names=FALSE ,comment.char = "")
      cat("\n\t", basename(outFile), "[loaded]")
      return(result)
  }

  probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
  # need to be pre-loaded from package.
  beta <- sample[["beta"]]
  meta <- sample[["meta"]]
  if (probeset %in% names(probesets)) {
    probes <- probesets[[probeset]]$NAME
  } else if (is.null(probes)) {
    cat("\nERROR: unavailable probeset & probes not given.\n")
    q("no")
  }
  if (sum(probes %in% rownames(beta)) == 0) {
    cat("\nERROR: invalid beta table .\n")
    q("no")
  }

  controlSet <- control[["beta"]]
  commonProbes <- intersect(intersect(rownames(beta), rownames(controlSet)), probes)
  ctrlGroup <- control[["meta"]]$SAMPLE_GROUP
  controlSet <- controlSet[commonProbes, ]
  sampleSet <- beta[commonProbes, ]

  # controlSet [ controlSet == NA] <- 0.5
  if (any(is.na(controlSet)) | any(is.na(sampleSet))) {
    cat("\nINFO: remove NA from controlSet and sampleSet.")
    controlSet <- na.omit(controlSet)
    sampleSet <- na.omit(sampleSet)
    commonProbes <- intersect(intersect(rownames(sampleSet), rownames(controlSet)), probes)
    controlSet <- controlSet[commonProbes, ]
    sampleSet <- beta[commonProbes, ]
  }

  IDs <- colnames(sampleSet) 
  avai_cores <- detectCores() - 1
  ncores <- min(min(avai_cores, length(IDs)), ncores)
  if (verbose) {
    outfile <- ""
  } else {
    outfile <- "/dev/null"
  }
  # ================================================================
  #  library("parallel")
  start_time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat("\nINFO: start parallelization [", start_time, "]\n")
  cl <- makeCluster(ncores, outfile = outfile) # silent run
  clusterExport(cl,
    varlist = c("Calc_KS","Calc_Wasserstein", "RUN_TEST", "sampleSet", "controlSet","ctrlGroup"),
    envir = environment()
  )
  resultsX <- parLapply(
    cl, IDs,
    function(x) RUN_TEST(x, sampleSet, controlSet,ctrlGroup)
  )
  stop_time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat("\nINFO: stop parallelization [", stop_time, "]\n")
  stopCluster(cl)
  # ================================================================
  results <- do.call(rbind, resultsX)
  #---------------------------------
  results <- data.frame(meta[IDs, c("Sample_Name", "Sample_Group")], results)

  write.table(results, outFile, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
  cat("\n\t", basename(outFile), "[saved]")
  #---------------------------------
  return(results)
}

#================================================================


##################################################################

Ecdf_Points <- function(plot_data, paternal_x, maternal_x){
  # Separate beta by CATEGORY
  beta_A <- plot_data$value[plot_data$CATEGORY == "paternal"]
  beta_B <- plot_data$value[plot_data$CATEGORY == "maternal"]

  # Compute ECDFs
  ecdf_A <- ecdf(beta_A)
  ecdf_B <- ecdf(beta_B)

  # Get y-values (ECDF at x_value)
  y_A <- ecdf_A(paternal_x)
  y_B <- ecdf_B(maternal_x)

  # Create data frame for points
  points_data <- data.frame(
    x = c(paternal_x,maternal_x),
    y = c(y_A, y_B),
    CATEGORY = c("paternal", "maternal")
  )
  return(points_data)
}

##################################################################

Filter_Dist_Prediction <- function(upd_score, dist_cutoff = 0.1, diff_cutoff = 0.23, outFile = NULL) {
  fmt1 <- all(c("ROI_dist", "mUPD_dist", "pUPD_dist", "ROI_p.value", "mUPD_p.value", "pUPD_p.value", "category") %in% colnames(upd_score))
  fmt2 <- all(c("Ref_Control_dist", "Ref_mUPD_dist", "Ref_pUPD_dist", "Ref_Control_p.value", "Ref_mUPD_p.value", "Ref_pUPD_p.value", "category") %in% colnames(upd_score))
  
  if (!fmt1 & !fmt2) {
    cat("\nERROR: invalid UPD_score passed to function[Adjust_UPD_prediction]\n")
    q("no")
  }else if (fmt1){
    groups <- c("ROI", "mUPD", "pUPD")
  }else{
    groups <- c("Ref_Control", "Ref_mUPD", "Ref_pUPD")
  }
  category <- upd_score[, "category"]
  cat("\nINFO: Before filtering.\n")
  print(table(upd_score$category))
  find_upd <- function(row,dist_cutoff,  diff_cutoff) {
    # Sort the values in ascending order
    # Return the absolute difference between the first and second smallest
    delta <- max(as.numeric(row))- min(as.numeric(row))
    upd <- delta >diff_cutoff & min(as.numeric(row)) < dist_cutoff
    return(upd)
  }
  upd_score$UPD_FLAG <- apply(upd_score[,grep("_dist",colnames(upd_score))], 1, function(x){find_upd(x, dist_cutoff,  diff_cutoff)})
  print(table(upd_score$UPD_FLAG))
  idx_like <-  (! upd_score$UPD_FLAG) & grepl("UPD",upd_score$category)
  upd_score$category[idx_like] <- paste0(upd_score[idx_like,"category"],"_like")
  # upd_score$category <- category
  cat("\n\nINFO: After filtering.\n")
  print(table(upd_score$category))
  outFile1 <- gsub(".txt$",".filtered.txt",outFile)
  if (!is.null(outFile)) {
    write.table(upd_score, outFile1, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile1), "[saved]")

    tab <- table(upd_score[,c("Sample_Group","category")])
    summary_df <-  as.data.frame.matrix(tab)

    outFile2 <- gsub(".txt$",".filtered_summary.txt",outFile)
    write.table(cbind(SAMPLE_GROUP=rownames(summary_df),summary_df), outFile2, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile2), "[saved]\n")

  }
  return(upd_score)
}


#================================================================




Filter_UPD_Prediction <- function(upd_score, kl_div_cutoff = 0.5, p_value_cutoff = 0.05, outFile = NULL) {
  #
  # KL Divergence < 0.5.  It suggests that the two distributions are quite similar.
  # KL Divergence >= 0.5.  This value signifies a moderate difference between the distributions
  # KL Divergence >= 1.  This value signifies a substantial difference between the distributions
  fmt1 <- all(c("ROI_kl.div", "mUPD_kl.div", "pUPD_kl.div", "ROI_p.value", "mUPD_p.value", "pUPD_p.value", "category") %in% colnames(upd_score))
  fmt2 <- all(c("Ref_Control_kl.div", "Ref_mUPD_kl.div", "Ref_pUPD_kl.div", "Ref_Control_p.value", "Ref_mUPD_p.value", "Ref_pUPD_p.value", "category") %in% colnames(upd_score))
  
  if (!fmt1 & !fmt2) {
    cat("\nERROR: invalid UPD_score passed to function[Adjust_UPD_prediction]\n")
    q("no")
  }else if (fmt1){
    groups <- c("ROI", "mUPD", "pUPD")
  }else{
    groups <- c("Ref_Control", "Ref_mUPD", "Ref_pUPD")
  }
  category <- upd_score[, "category"]
  cat("\nINFO: Before filtering.\n")
  print(table(upd_score$category))

  find_min_diff <- function(row) {
    # Sort the values in ascending order
    row <- as.numeric(row)
       sorted <- sort(row)
    # Return the absolute difference between the first and second smallest
    abs(sorted[1] - sorted[2])
  }
 upd_score$delta <- apply(upd_score[,grep("_kl.div",colnames(upd_score))], 1, find_min_diff)

  for (grp in groups) {
    idx_group <- which(as.character(category) %in% grp)
    kl_div <- upd_score[idx_group, paste0(grp, "_kl.div")]
    p_value <- upd_score[idx_group, paste0(grp, "_p.value")]
    idx_false <- as.numeric(kl_div) >= kl_div_cutoff | as.numeric(p_value) >= p_value_cutoff 
    upd_score$category[idx_group[idx_false]] <- "undetermined"
    #cat("\nINFO: ", grp, "[kept:", sum(!idx_false), ", filtered:", sum(idx_false), "]")
  }
     
  upd_score$category[as.numeric(upd_score$delta)<0.3] <- "undetermined"
  # upd_score$category <- category
  cat("\n\nINFO: After filtering.\n")
  print(table(upd_score$category))
  outFile1 <- gsub(".txt$",".filtered.txt",outFile)
  if (!is.null(outFile)) {
    write.table(upd_score, outFile1, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile1), "[saved]")

    tab <- table(upd_score[,c("Sample_Group","category")])
    summary_df <-  as.data.frame.matrix(tab)

    outFile2 <- gsub(".txt$",".filtered_summary.txt",outFile)
    write.table(cbind(SAMPLE_GROUP=rownames(summary_df),summary_df), outFile2, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile2), "[saved]\n")

  }
  return(upd_score)
}


##################################################################
# 01/08/2025, 14:53:36

GGplot2Html <- function(pg, prefix) {
  outFile1 <- paste0(prefix, ".html")
  outFile2 <- paste0(prefix, "_selfcontained.html")
  suppressMessages(library(plotly))
  suppressMessages(library("rmarkdown"))
  suppressMessages(library("dplyr"))
  suppressMessages(library("htmlwidgets"))
  # run this first under bash: module load pandoc/1.19.2.1
  pg1 <- ggplotly(pg, width = 1200, height = 900, tooltip = c("text")) %>% toWebGL()
  suffix <- ""
  htmlwidgets::saveWidget(as_widget(pg1), outFile1, selfcontained = FALSE)
  if (pandoc_available()) { # generate selfContained html
    pandoc_self_contained_html(outFile1, outFile2)
    libdir <- paste(tools::file_path_sans_ext(outFile1), "_files", sep = "")
    unlink(libdir, recursive = TRUE, force = TRUE)
    unlink(outFile1, recursive = TRUE, force = TRUE)
    suffix <- "_selfcontained"
  }
  options(warn = 0)
  if (file.exists(outFile1) | file.exists(outFile2)) {
    cat("\n\t", paste0(basename(prefix), suffix, ".html"), "[saved]\n")
  } else {
    cat("\n\tERROR: unable to save interactive plot(html).")
  }
}
##################################################################



ICR_Filepath <- function(icrFile) {
  ICR_DIR <- "/research/rgs01/home/clusterHome/hjin/projects/ImprintomeR/ICR/"
  # Convert to uppercase for comparison
  clean_input <- toupper(basename(icrFile))
  icrFile <- dplyr::case_when(
    clean_input %in% c("NANOIMPRINT") ~ paste0(ICR_DIR,"regions14_hg19_sort.bed"),
    clean_input %in% c("JOSHI") ~ paste0(ICR_DIR, "Joshi_mmc6_simple_merged_d2k.bed"),
    clean_input %in% c("COURT") ~ paste0(ICR_DIR, "Court_WGBS.ICR.hg19_simple.bed"),
    clean_input %in% c("ROSENSKI") ~ paste0(ICR_DIR, "Rosenski_Atlas_hg19_n81.bed"),
    TRUE ~ icrFile # Returns the original path if no shortcut is found
  )
  normalizePath(icrFile)
}

#================================================================



#' Calculate Epigenetic Stochasticity (ImpVar)
#' @param beta_matrix A matrix of beta values (rows = CpGs, cols = samples)
#' @param cpg_annos A data frame or GRanges with CpG positions (must match beta_matrix rows)
#' @param icr_regions A GRanges object defining the start/end of ICRs
#' @return A data frame of Variance scores per ICR per sample

#  icr.bed <- "/research/rgs01/home/clusterHome/hjin/projects/ImprintomeR/ICR/Joshi_mmc6_simple_merged_d2k.bed"
# betaFile <- "/research/rgs01/home/clusterHome/hjin/projects/ImprintomeR/imprintomeR_dev/datasets/GSE52576_CHM_450K/GSE52576_CHM_beta.txt"
# metaFile <- "/research/rgs01/home/clusterHome/hjin/projects/ImprintomeR/datasets/GSE52576/GSE52576_meta.txt"

Imprintome_Classifier <- function(betaFile, metaFile, probeset = "selected",prefix=NULL,low_cutoff=0.3, high_cutoff=0.7 ) {
  # betaFile
  # probeset format
  #     Two columns: TargetID and GROUP;
  #     -TargetID: Illumina probeID;  like cg11753499
  #     -GROUP: values must be H19 or KCNQ1OT1

  #Loss of Heterozygosity (LOH): This is not directly related to imprinting but rather to the loss of one allele's genetic material. At 11p15, LOH can affect tumor suppressor genes like CDKN1C or the imprinted genes, potentially leading to cancer.
  
  #Loss of Imprinting (LOI): This occurs when the normal imprinting pattern is disrupted, leading to biallelic expression or silencing of genes that should be monoallelically expressed. 
  
  #Retention of Imprinting (ROI):This refers to the normal state where the methylation pattern of genes at the 11p15 locus is maintained as it should be according to the parental origin. 
  min_delta <-  high_cutoff-low_cutoff
  tmp  <- SubsetBeta_By_Probeset(beta, probeset=probeset,prefix=prefix)
  probesets <- tmp[["probesets"]]
  used <- tmp[["beta"]]
  used <- na.omit(used) # removed NA
  all_probes <- intersect(probesets$NAME, rownames(used))
  maternal_probes <- intersect(probesets$NAME[grep("maternal", probesets$ORIGIN)], rownames(used))
  paternal_probes <- intersect(probesets$NAME[grep("paternal", probesets$ORIGIN)], rownames(used))
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
  all_roi <- colSums(apply(used[all_probes, ],2, function(x)Between(x, low_cutoff,high_cutoff)))/length(all_probes)  # retention of imprinting 
  all_loi <- colSums(apply(used[all_probes, ],2, function(x)Between(x, 0,low_cutoff)))/length(all_probes) 
  all_goi <- colSums(apply(used[all_probes, ],2, function(x)Between(x, high_cutoff,1)))/length(all_probes) 
 
  paternal_roi <- colSums(apply(used[paternal_probes, ],2, function(x)Between(x, low_cutoff,high_cutoff)))/length(paternal_probes)  # retention of imprinting 
  paternal_goi <- colSums(apply(used[paternal_probes, ],2, function(x)Between(x, high_cutoff,1)))/length(paternal_probes)  # gain of imprinting
  paternal_loi <- colSums(apply(used[paternal_probes, ],2, function(x)Between(x, 0,low_cutoff)))/length(paternal_probes) 
  maternal_roi <- colSums(apply(used[maternal_probes, ],2, function(x)Between(x, low_cutoff,high_cutoff)))/length(maternal_probes) 
  maternal_goi <- colSums(apply(used[maternal_probes, ],2, function(x)Between(x, high_cutoff,1)))/length(maternal_probes) 
  maternal_loi <- colSums(apply(used[maternal_probes, ],2, function(x)Between(x, 0,low_cutoff)))/length(maternal_probes) 

  paternal_probes_mean <- colMeans(used[paternal_probes, ])   # paternal allele
  maternal_probes_mean <- colMeans(used[maternal_probes, ]) # maternal allele
  ROI <- paternal_probes_mean < high_cutoff & maternal_probes_mean > low_cutoff
  LOI <- paternal_probes_mean > high_cutoff | maternal_probes_mean < low_cutoff
  #LOH <- (paternal_probes_mean > high_cutoff & maternal_probes_mean < low_cutoff) | (abs(paternal_probes_mean-maternal_probes_mean)>min_delta)
  LOH <- ((paternal_probes_mean > high_cutoff & maternal_probes_mean < low_cutoff) | (abs(paternal_probes_mean-maternal_probes_mean)>min_delta) | all_roi <0.3) & abs(all_goi-all_loi) >0.2 
  meta$Imprintome <- "undertermined"
  meta$Imprintome[ROI] <- "ROI"
  meta$Imprintome[LOI] <- "LOI"
  meta$Imprintome[LOH] <- "LOH"
  idx_pUPD <- (paternal_goi >0.6|maternal_loi >0.6) & meta$Imprintome == "LOH" & all_roi<0.3 & (paternal_probes_mean > maternal_probes_mean)
  idx_mUPD <- (maternal_goi >0.6|paternal_loi >0.6) & meta$Imprintome == "LOH" & all_roi<0.3 & (paternal_probes_mean < maternal_probes_mean)
  meta$UPD_FLAG <- NA
  meta$UPD_FLAG[idx_pUPD] <- "pUPD"
  meta$UPD_FLAG[idx_mUPD] <- "mUPD"

  detail <- data.frame(
    SAMPLE_NAME = colnames(used), SAMPLE_GROUP = meta$Sample_Group,
    paternal_probes_mean = paternal_probes_mean, t(used[paternal_probes, ]),
    maternal_probes_mean = maternal_probes_mean,
    t(used[maternal_probes, ]),
    Imprintome = meta$Imprintome
  )

  result <- data.frame(
    SAMPLE_NAME = colnames(used), SAMPLE_GROUP = meta$Sample_Group,paternal_probes_mean = paternal_probes_mean,maternal_probes_mean = maternal_probes_mean,
    all_roi=all_roi, all_goi=all_goi, all_loi=all_loi,  paternal_roi=paternal_roi, paternal_goi=paternal_goi, paternal_loi = paternal_loi,
     maternal_roi=maternal_roi,maternal_goi=maternal_goi,  maternal_loi=maternal_loi, 
    Imprintome = meta$Imprintome, UPD_FLAG=meta$UPD_FLAG
  )
  # results <- cbind(meta[IDs, c("Sample_Name", "Sample_Group")], results)
  if (!is.null(prefix)) {
    outFile1 <- paste0(prefix, "_Imprintome.status.txt")
    write.table(result, outFile1, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile1), "[saved]\n")
    tab <- table(result[,c("Sample_Group","Imprintome")])
    summary_df <-  as.data.frame.matrix(tab)

    outFile2 <- paste0(prefix, "_Imprintome.status_summary.txt")
    write.table(cbind(SAMPLE_GROUP=rownames(summary_df),summary_df), outFile2, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile2), "[saved]\n")
    #outFile2 <- paste0(prefix, "_11p15.status_details.txt")
    #write.table(detail, outFile2, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    #cat("\n", basename(outFile2), "[saved]\n")
  }
  return(result)
}

##################################################################
# 02/07/2025, 11:49:11 

Imprintome_Classifier_v3 <- function(betaFile, metaFile, probeset = "selected",prefix=NULL,low_cutoff=0.3, high_cutoff=0.7 ) {
  input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
  beta <- input[["beta"]]
  meta <- input[["meta"]]
  tmp  <- SubsetBeta_By_Probeset(beta, probeset=probeset,prefix=prefix)
  probesets <- tmp[["probesets"]]
  used <- tmp[["beta"]]
  used <- na.omit(used) # removed NA
  all_probes <- intersect(probesets$NAME, rownames(used))
  maternal_probes <- intersect(probesets$NAME[grep("maternal", probesets$ORIGIN)], rownames(used))
  paternal_probes <- intersect(probesets$NAME[grep("paternal", probesets$ORIGIN)], rownames(used))
  maternal_beta <- used[maternal_probes, ]
  paternal_beta <- used[paternal_probes, ]

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
  maternal_median <- apply(maternal_beta, 2, median)
  maternal_sd <- apply(maternal_beta, 2, sd)
  paternal_median <- apply(paternal_beta, 2, median)
  paternal_sd <- apply(paternal_beta, 2, sd)

  abs_diff <- abs(maternal_median-paternal_median) >0.2
  pat_ROI <- paternal_median < high_cutoff & paternal_median > low_cutoff
  mat_ROI <- maternal_median < high_cutoff & maternal_median > low_cutoff
  ROI <- pat_ROI & mat_ROI
  pat_GOM <-  paternal_median > high_cutoff & mat_ROI == TRUE #& abs_diff #Paternal uniparental disomy (UPD), paternal gain (BWS)
  pat_LOM <-  paternal_median < low_cutoff & mat_ROI == TRUE #& abs_diff #pat loss of methylation ,or Maternal duplication, SRS-like
  mat_GOM <-  pat_ROI == TRUE &  maternal_median > high_cutoff #& abs_diff #mat gain of methylation (e.g. BWS subtype)
  mat_LOM <-  pat_ROI == TRUE  & maternal_median < low_cutoff #& abs_diff #mat loss of methylation (e.g. BWS subtype)
  pUPD <- paternal_median > high_cutoff & maternal_median < low_cutoff  
  mUPD <- paternal_median < low_cutoff  & maternal_median > high_cutoff
  LOI <- paternal_median < low_cutoff & maternal_median < low_cutoff
  GOM <- paternal_median > high_cutoff & maternal_median > high_cutoff

  meta$imprintome_status <- "Unknown" #"undertermined"
  meta$imprintome_status[ROI] <- "ROI"
  meta$imprintome_status[pat_GOM] <- "pat_GOM"  # pUPD_pGOM,mat_ROI
  meta$imprintome_status[pat_LOM] <- "pat_LOM"  
  meta$imprintome_status[mat_GOM] <- "mat_GOM"
  meta$imprintome_status[mat_LOM] <- "mat_LOM"
  meta$imprintome_status[LOI] <- "GW_LOM,unusual"  
  meta$imprintome_status[GOM] <- "GW_GOM,unusual"  
  meta$imprintome_status[pUPD] <- "GW_pUPD"
  meta$imprintome_status[mUPD] <- "GW_mUPD"
  result1 <- data.frame(
    paternal_median = paternal_median, paternal_sd= paternal_sd,  
    maternal_median = maternal_median, maternal_sd= maternal_sd, 
    imprintome_status = meta$imprintome_status
  )

  meta_selectedColumns <- meta[, intersect(colnames(meta),c("Sample_Name","Sample_Group","ID2"))]
  result <- cbind(
    meta_selectedColumns,
    paternal_median = paternal_median, paternal_sd= paternal_sd,  
    maternal_median = maternal_median, maternal_sd= maternal_sd, 
    imprintome_status = meta$imprintome_status
  )
  if (!is.null(prefix)) {
    outFile1 <- paste0(prefix, "_imprintome_status.class.v3.txt")
    write.table(result, outFile1, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile1), "[saved]\n")
    tab <- table(result[,c("Sample_Group","imprintome_status")])
    summary_df <-  as.data.frame.matrix(tab)

    outFile2 <- paste0(prefix, "_imprintome_status.class.v3_summary.txt")
    write.table(cbind(SAMPLE_GROUP=rownames(summary_df),summary_df), outFile2, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile2), "[saved]\n")
  }
  return(result)
}


#================================================================

Imprintome_Classifier2 <- function(betaFile, metaFile, probeset = "selected",prefix=NULL,low_cutoff=0.3, high_cutoff=0.7 ) {
  # betaFile
  # probeset format
  #     Two columns: TargetID and GROUP;
  #     -TargetID: Illumina probeID;  like cg11753499
  #     -GROUP: values must be H19 or KCNQ1OT1

  #Loss of Heterozygosity (LOH): This is not directly related to imprinting but rather to the loss of one allele's genetic material. At 11p15, LOH can affect tumor suppressor genes like CDKN1C or the imprinted genes, potentially leading to cancer.
  
  #Loss of Imprinting (LOI): This occurs when the normal imprinting pattern is disrupted, leading to biallelic expression or silencing of genes that should be monoallelically expressed. 
  
  #Retention of Imprinting (ROI):This refers to the normal state where the methylation pattern of genes at the 11p15 locus is maintained as it should be according to the parental origin. 
  delta <- 0.2
  tmp  <- SubsetBeta_By_Probeset(beta, probeset=probeset,prefix=prefix)
  probesets <- tmp[["probesets"]]
  used <- tmp[["beta"]]
  used <- na.omit(used) # removed NA
  all_probes <- intersect(probesets$NAME, rownames(used))
  maternal_probes <- intersect(probesets$NAME[grep("maternal", probesets$ORIGIN)], rownames(used))
  paternal_probes <- intersect(probesets$NAME[grep("paternal", probesets$ORIGIN)], rownames(used))
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
  all_roi <- colSums(apply(used[all_probes, ],2, function(x)Between(x, low_cutoff,high_cutoff)))/length(all_probes)  # retention of imprinting 
  all_loi <- colSums(apply(used[all_probes, ],2, function(x)Between(x, 0,low_cutoff)))/length(all_probes) 
  all_goi <- colSums(apply(used[all_probes, ],2, function(x)Between(x, high_cutoff,1)))/length(all_probes) 
 
  paternal_roi <- colSums(apply(used[paternal_probes, ],2, function(x)Between(x, low_cutoff,high_cutoff)))/length(paternal_probes)  # retention of imprinting 
  paternal_goi <- colSums(apply(used[paternal_probes, ],2, function(x)Between(x, high_cutoff,1)))/length(paternal_probes)  # gain of imprinting
  paternal_loi <- colSums(apply(used[paternal_probes, ],2, function(x)Between(x, 0,low_cutoff)))/length(paternal_probes) 
  maternal_roi <- colSums(apply(used[maternal_probes, ],2, function(x)Between(x, low_cutoff,high_cutoff)))/length(maternal_probes) 
  maternal_goi <- colSums(apply(used[maternal_probes, ],2, function(x)Between(x, high_cutoff,1)))/length(maternal_probes) 
  maternal_loi <- colSums(apply(used[maternal_probes, ],2, function(x)Between(x, 0,low_cutoff)))/length(maternal_probes) 

  paternal_probes_mean <-  apply(used[paternal_probes, ], 2, median)  # colMeans(used[paternal_probes, ])   # paternal allele
  maternal_probes_mean <- apply(used[maternal_probes, ], 2, median)  # colMeans(used[maternal_probes, ]) # maternal allele
  ROI <- paternal_probes_mean < high_cutoff & maternal_probes_mean > low_cutoff
  LOI <- paternal_probes_mean > high_cutoff | maternal_probes_mean < low_cutoff
  LOH <- ((paternal_probes_mean > high_cutoff | maternal_probes_mean < low_cutoff )& abs(paternal_probes_mean-maternal_probes_mean)>0.4| all_roi <0.3) & abs(all_goi-all_loi) >delta  

  meta$Imprintome <- "undertermined"
  meta$Imprintome[ROI] <- "ROI"
  meta$Imprintome[LOI] <- "LOI"
  meta$Imprintome[LOH] <- "LOH"
  idx_pUPD <- (paternal_goi >0.6 & maternal_goi <0.3) & meta$Imprintome == "LOH" & (paternal_probes_mean > maternal_probes_mean)  & all_roi<0.3
  idx_mUPD <- (maternal_goi >0.6 & paternal_goi <0.3) & meta$Imprintome == "LOH" &  (paternal_probes_mean < maternal_probes_mean)  & all_roi<0.3
  meta$UPD_FLAG <- NA
  meta$UPD_FLAG[idx_pUPD] <- "pUPD"
  meta$UPD_FLAG[idx_mUPD] <- "mUPD"

  detail <- data.frame(
    SAMPLE_NAME = colnames(used), SAMPLE_GROUP = meta$Sample_Group,
    paternal_probes_mean = paternal_probes_mean, t(used[paternal_probes, ]),
    maternal_probes_mean = maternal_probes_mean,
    t(used[maternal_probes, ]),
    Imprintome = meta$Imprintome
  )

  result <- data.frame(
    SAMPLE_NAME = colnames(used), SAMPLE_GROUP = meta$Sample_Group,paternal_probes_mean = paternal_probes_mean,maternal_probes_mean = maternal_probes_mean,
    all_roi=all_roi, all_goi=all_goi, all_loi=all_loi,  paternal_roi=paternal_roi, paternal_goi=paternal_goi, paternal_loi = paternal_loi,
     maternal_roi=maternal_roi,maternal_goi=maternal_goi,  maternal_loi=maternal_loi, 
    Imprintome = meta$Imprintome, UPD_FLAG=meta$UPD_FLAG
  )
  # results <- cbind(meta[IDs, c("Sample_Name", "Sample_Group")], results)
  if (!is.null(prefix)) {
    outFile1 <- paste0(prefix, "_Imprintome.status.txt")
    write.table(result, outFile1, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile1), "[saved]\n")
    tab <- table(result[,c("Sample_Group","Imprintome")])
    summary_df <-  as.data.frame.matrix(tab)

    outFile2 <- paste0(prefix, "_Imprintome.status_summary.txt")
    write.table(cbind(SAMPLE_GROUP=rownames(summary_df),summary_df), outFile2, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(outFile2), "[saved]\n")
    #outFile2 <- paste0(prefix, "_11p15.status_details.txt")
    #write.table(detail, outFile2, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    #cat("\n", basename(outFile2), "[saved]\n")
  }
  return(result)
}
#================================================================
  Calculate_Stat_by_range <- function(value,low_cutoff=0.3, high_cutoff=0.7) {
    ranges <- list(
      "low" = value[Between(value, 0,low_cutoff)],
      "med" = value[Between(value, low_cutoff,high_cutoff)],
      "high" = value[Between(value, high_cutoff,1)]
    )
    total_probes <- length(value)
    medians <- sapply(ranges, function(x) if (length(x) > 0) median(x) else 0) # NA
    ratio <- sapply(ranges, function(x) (length(x) / total_probes))
    sd <- sapply(ranges,  function(x) if (length(x) > 0) sd(x) else 0)
    result <- c(round(medians,3),round(ratio,3),round(sd,3))
    names(result) <- c("median_low","median_med","median_high","ratio_low","ratio_med","ratio_high", "sd_low","sd_med","sd_high")
    return(result)
   }


##################################################################
# 03/23/2025, 20:17:45 
##################################################################

Impute_chr_dataset_v6 <- function(metaFile=NULL, betaFile=NULL,outPrefix=NULL,probeset="selected"){
   # 1. chr7- mUPD+pUPD + UPD_chr7
   # 2. chr11 - mUPD+pUPD + UPD_chr11
   # 3. chr20 ...
    if(is.null(metaFile) & is.null(betaFile) ){
      metaFile <- "/home/hjin/projects/imprintomeR_dev/final2025/final_std1_joined_ML_meta.txt"
      betaFile <- "/home/hjin/projects/imprintomeR_dev/final2025/final_std1_selected_joined_beta.txt"
    }  
    dir.create(dirname(outPrefix), showWarnings = FALSE,recursive=T)
    if(is.null(outPrefix) ){
      outPrefix <- "/home/hjin/projects/imprintomeR_dev/final2025/model_v6/final_std1_joined_ML_v6_imputed"
    } 

    input <- LoadMetaBeta(metaFile, betaFile, probeset = probeset)
    meta <- input[["meta"]]
    beta <- input[["beta"]]
   

    probesets_all <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")    
    probeset <- probesets_all[[probeset]]
    common_probes <- intersect(probeset$NAME, rownames(beta))
    probeset <- probeset[probeset$NAME %in% common_probes, ]
    beta <- beta[common_probes,] 


    # imputation 
    beta_pUPD <- beta[,meta$Sample_Name[grep("pUPD_chr",meta$Sample_Group)]]
    beta_mUPD_imputed <- Mirror_BetaValues(beta_pUPD)
    meta_mUPD_imputed <- meta[meta$Sample_Name[grep("pUPD_chr",meta$Sample_Group)],]
    meta_mUPD_imputed$SAMPLE_NAME <- paste0(gsub("pat","mat", meta_mUPD_imputed$SAMPLE_NAME),"_imputed")
    meta_mUPD_imputed$SAMPLE_GROUP <- gsub("pUPD","mUPD", meta_mUPD_imputed$SAMPLE_GROUP)
    meta_mUPD_imputed$ID2 <- meta_mUPD_imputed$SAMPLE_NAME
    rownames(meta_mUPD_imputed) <- meta_mUPD_imputed$SAMPLE_NAME
    colnames(beta_mUPD_imputed) <-   meta_mUPD_imputed$SAMPLE_NAME

    beta_mUPD <- beta[,meta$Sample_Name[grep("mUPD_chr",meta$Sample_Group)]]
    beta_pUPD_imputed <-Mirror_BetaValues(beta_mUPD)
    meta_pUPD_imputed <- meta[meta$Sample_Name[grep("mUPD_chr",meta$Sample_Group)],]
    meta_pUPD_imputed$SAMPLE_NAME <- paste0(gsub("mat","pat", meta_pUPD_imputed$SAMPLE_NAME),"_imputed")
    meta_pUPD_imputed$SAMPLE_GROUP <- gsub("mUPD","pUPD", meta_pUPD_imputed$SAMPLE_GROUP)
    meta_pUPD_imputed$ID2 <- meta_pUPD_imputed$SAMPLE_NAME
    rownames(meta_pUPD_imputed) <- meta_pUPD_imputed$SAMPLE_NAME
    colnames(beta_pUPD_imputed) <-   meta_pUPD_imputed$SAMPLE_NAME
    beta_all <- cbind(beta, beta_mUPD_imputed, beta_pUPD_imputed)
    meta_all <- rbind(meta, meta_mUPD_imputed, meta_pUPD_imputed)    
    dataset <- list()
    chrs <- c("chr1","chr4","chr6","chr7","chr8","chr11", "chr14","chr15","chr16","chr19","chr20","all") #"chr13","chr2","chr22" have <10 probes
    x <- 0
    for(chr in chrs){
      cat("\n [",chr,"]")
      x <- x +1 
      if(chr=="all"){  # all means GWpUPD + GWmUPD + ROI
        probes_chr <- probeset$NAME
        idx_grp <- c(grep("UPD$", meta_all$SAMPLE_GROUP), grep("ROI",meta_all$SAMPLE_GROUP))
        meta_subset <- meta_all[meta_all$SAMPLE_GROUP %in% meta_all$SAMPLE_GROUP[idx_grp],]
        meta_subset$SAMPLE_GROUP <- gsub("GW","", meta_subset$SAMPLE_GROUP)
        print(table(meta_subset$SAMPLE_GROUP))
        beta_subset <- beta_all[probes_chr,meta_subset$SAMPLE_NAME]

      }else{  # impute GWpUPD + GWmUPD samples  to UPD_chr samples (use ROI probes for )  , UPD_chr samples + ROI samples
        # UPD_chr specific samples
        idx_chr <- grep(paste0("UPD_",chr,"$"), meta_all$SAMPLE_GROUP)
        meta_chr <- meta_all[idx_chr,]
        beta_chr <- beta_all[, meta_chr$SAMPLE_NAME] #
        
        # extract probes_chr from GWUPD + other probes from ROI
        idx_ROI_all <- grep("ROI",meta_all$SAMPLE_GROUP)
        meta_ROI <- meta_all[idx_ROI_all,]
        #beta_ROI <- beta_all[, meta_ROI$SAMPLE_NAME] #    
    
        idx_GWUPD <- grep("UPD$", meta_all$SAMPLE_GROUP)
        if(chr %in% "chr15"){  # exclude CHM samples 
          idx_GWUPD <- setdiff(idx_GWUPD, grep("CHM_sample", meta_all$SAMPLE_NAME,ignore.case=T))
          idx_GWUPD <- setdiff(idx_GWUPD, grep("OT_sample[34]", meta_all$SAMPLE_NAME,ignore.case=T))
          idx_GWUPD <- setdiff(idx_GWUPD, grep("5806361009_R03C01", meta_all$SAMPLE_NAME,ignore.case=T)) #GSM1270037_Leukocytes
          idx_GWUPD <- setdiff(idx_GWUPD, grep("5806361009_R04C01", meta_all$SAMPLE_NAME,ignore.case=T)) #GSM1270039_Leukocytes
        }
        if(chr %in% "chr2"){  # exclude OT sample3 and 4
          idx_GWUPD <- setdiff(idx_GWUPD, grep("OT_sample[34]", meta_all$SAMPLE_NAME,ignore.case=T))
          idx_GWUPD <- setdiff(idx_GWUPD, grep("5806361009_R04C02", meta_all$SAMPLE_NAME,ignore.case=T)) #GSM1270040_Leukocytes
        }   
        if(chr %in% "chr14"){  # exclude 
          idx_GWUPD <- setdiff(idx_GWUPD, grep("CHM_sample", meta_all$SAMPLE_NAME,ignore.case=T))
          idx_GWUPD <- setdiff(idx_GWUPD, grep("OT_sample", meta_all$SAMPLE_NAME,ignore.case=T))
          idx_GWUPD <- setdiff(idx_GWUPD, grep("5806361009_R04C02", meta_all$SAMPLE_NAME,ignore.case=T)) #GSM1270040_Leukocytes
          idx_GWUPD <- setdiff(idx_GWUPD, grep("5806361009_R03C01", meta_all$SAMPLE_NAME,ignore.case=T)) #GSM1270037_Leukocytes
        }   
        if(chr %in% "chr22"){  # exclude OT sample3 and 4
          idx_GWUPD <- setdiff(idx_GWUPD, grep("OT_sample[234]", meta_all$SAMPLE_NAME,ignore.case=T))
          idx_GWUPD <- setdiff(idx_GWUPD, grep("5806361009_R04C02", meta_all$SAMPLE_NAME,ignore.case=T)) #GSM1270040_Leukocytes
        }      
        if(chr %in% "chr16"){  # exclude OT sample3 and 4
          idx_GWUPD <- setdiff(idx_GWUPD, grep("CHM_sample[1]", meta_all$SAMPLE_NAME,ignore.case=T))
          idx_GWUPD <- setdiff(idx_GWUPD, grep("OT_sample4", meta_all$SAMPLE_NAME,ignore.case=T))
          idx_GWUPD <- setdiff(idx_GWUPD, grep("5806361009_R0[34]C01", meta_all$SAMPLE_NAME,ignore.case=T)) #	Leukocytes	GSM1270037_Leukocytes
          idx_GWUPD <- setdiff(idx_GWUPD, grep("207059680038", meta_all$SAMPLE_NAME,ignore.case=T)) #	ACT
          idx_GWUPD <- setdiff(idx_GWUPD, grep("208356070115", meta_all$SAMPLE_NAME,ignore.case=T)) #	ACT
        }         
        if(chr %in% "chr6"){  # exclude OT sample3 and 4
          idx_GWUPD <- setdiff(idx_GWUPD, grep("CHM_sample[34]", meta_all$SAMPLE_NAME,ignore.case=T))
          idx_GWUPD <- setdiff(idx_GWUPD, grep("OT_sample4", meta_all$SAMPLE_NAME,ignore.case=T))
          idx_GWUPD <- setdiff(idx_GWUPD, grep("5806361009_R03C01", meta_all$SAMPLE_NAME,ignore.case=T)) #	Leukocytes	GSM1270037_Leukocytes, GSM1270039_Leukocytes
        }      
        if(chr %in% c("chr7","chr19")){  # exclude OT sample3 and 4
          idx_GWUPD <- setdiff(idx_GWUPD, grep("5806361009_R03C01", meta_all$SAMPLE_NAME,ignore.case=T)) #	Leukocytes	GSM1270037_Leukocytes
        }             
        meta_GWUPD <- meta_all[idx_GWUPD,]
        meta_GWUPD$SAMPLE_GROUP <- gsub("GW","", meta_GWUPD$SAMPLE_GROUP)
        beta_GWUPD <- beta_all[, meta_GWUPD$SAMPLE_NAME]  

        probes_chr <- probeset$NAME[probeset$CHR %in% c(chr, gsub("chr","", chr))]
        probes_chr_others <- probeset$NAME[! probeset$CHR %in% c(chr, gsub("chr","", chr))]
       
        ids_GWUPD_part <- meta_GWUPD$SAMPLE_NAME
        beta_GWUPD_part  <- beta_all[probes_chr, ids_GWUPD_part]

        ids_subset_ROI <- sample(1:nrow(meta_ROI), length(ids_GWUPD_part))
        ids_ROI_part <-    meta_ROI$SAMPLE_NAME[ids_subset_ROI]    # from ROI
        beta_ROI_part <- beta_all[probes_chr_others, ids_ROI_part]     

        colnames(beta_ROI_part) <- ids_GWUPD_part #
        beta_GWUPD_to_chr <- rbind(beta_GWUPD_part,beta_ROI_part)
        beta_GWUPD_to_chr <- beta_GWUPD_to_chr[rownames(beta_all),] # keep  rownames in original order
 
        # extract ROI_kept
        ids_ROI_kept <-    meta_ROI$SAMPLE_NAME[setdiff(1:nrow(meta_ROI),ids_subset_ROI)]
        meta_ROI_kept <- meta_ROI[meta_ROI$SAMPLE_NAME %in% ids_ROI_kept, ]
        beta_ROI_kept <- beta_all[, ids_ROI_kept]

        beta_subset <- cbind(beta_chr, beta_GWUPD_to_chr, beta_ROI_kept)
        meta_subset <- rbind(meta_chr, meta_GWUPD,meta_ROI_kept )
        
      }
      meta_subset$SAMPLE_GROUP <- gsub("_chr.*","", meta_subset$SAMPLE_GROUP)   
      print(table(meta_subset$SAMPLE_GROUP))
      dataset[[x]] <- list(beta=beta_subset, meta=meta_subset)
    }
    names(dataset) <- chrs
    rdsFile <- paste0(outPrefix,"_chr_dataset_for_rf.rds")
    saveRDS(dataset,file=rdsFile)
    cat(paste0('\n ',basename(rdsFile),' [saved]'))
    return(dataset)
}

#================================================================


ImputedNorm <- function(nrow=600,ncol=1,size=50, p_success=0.5,adj=0,seed=123){
  set.seed(seed)
  #nrow <- 100    # Number of values
  #size <- 50     # Number of trials per binomial (adjust for spread)
  #p_success <- 0.5   # Probability to center at 0.5
  # Generate 100 binomial proportions
  sim_values <- rbinom(nrow, size = size, prob = p_success) / size + adj
  sim_probes <- paste0("sp", sprintf("%06d", 1:nrow))
    #names(sim_values) <- sim_probes
     
  spread <- sd(sim_values / size)
  print(spread)
  df <- as.data.frame(replicate(ncol, sim_values))
  rownames(df) <- sim_probes
  return(df)
}




ImputeImprintedNorm <- function(ncol=1,nrow=1000, low=0.1, high=0.9, seed=123){
  set.seed(seed)
  # Use binomial to simulate a distribution, scaled to 0.3â€“0.7 range
  step <- (high-low)/nrow
  # Generate the sequence
  sim_values <- seq(low, high, by = step)[1:nrow]
  # Assign names (probe IDs)
  sim_probes <- paste0("sp", sprintf("%05d", 1:nrow))
  #names(sim_values) <- sim_probes
   sim_values <- sim_values[1:nrow]
  df <- as.data.frame(replicate(ncol, sim_values))
  rownames(df) <- sim_probes
  return(df)
}

#================================================================


ImputeImprintedNorm0 <- function(ncol=1,nrow=1000,  center=0.5, low=0.3, high=0.7, adj=0, seed=123){
  set.seed(seed)
  # Use binomial to simulate a distribution, scaled to 0.3â€“0.7 range
  sim_values <- rbinom(ceiling(nrow*1.001), size = 100, prob = center) / 100  # binomial [0,1] centered at 0.5
  sim_values <- sim_values[sim_values >= low & sim_values <= high]  # filter to target range
  sim_values <- sim_values[1:nrow]  # ensure length
  sim_values[is.na(sim_values)] <- center # if anly missing values replaced with center
  # Assign names (probe IDs)
  sim_probes <- paste0("sp", sprintf("%05d", 1:nrow))
  #names(sim_values) <- sim_probes
  df <- as.data.frame(replicate(ncol, sim_values+adj))
  rownames(df) <- sim_probes
  return(df)
}
#================================================================
#================================================================

ImputeImprintedNorm1 <- function(ncol=1,nrow=1000,  center=0.5, low=0.1, high=0.9, seed=123){
  set.seed(seed)
  # Use binomial to simulate a distribution, scaled to 0.3â€“0.7 range
  sim_values_center <- rbinom(ceiling(nrow*0.34), size = 100, prob = center) / 100  # binomial [0,1] centered at 0.5
  sim_values_high <- rbinom(ceiling(nrow*0.34), size = 100, prob = low) / 100  # binomial [0,1] centered at 0.5
  sim_values_low <- rbinom(ceiling(nrow*0.34), size = 100, prob = high) / 100  # binomial [0,1] centered at 0.5  
  # Assign names (probe IDs)
  sim_probes <- paste0("sp", sprintf("%05d", 1:nrow))
  #names(sim_values) <- sim_probes
  sim_values <- c(sim_values_center,sim_values_high,sim_values_low)
   sim_values <- sim_values[1:nrow]
  df <- as.data.frame(replicate(ncol, sim_values))
  rownames(df) <- sim_probes
  return(df)
}
#================================================================

Meth_Clust <- function(pred_res, classifier="UPD2", ann_col = "Sample_Group",IdColumn='Sample_Name', dist_method = "euclidean",
      k = 3, clust_method = "ward.D2", outFile = NULL) {
   # pred_res: prediction result     
   # classifier : UPD or chr11p15        
  suppressMessages(suppressWarnings(library(ComplexHeatmap)))
  suppressMessages(suppressWarnings(library(dendextend)))
  #================================================================
  # upd_score
    # ann_col="Sample_Group"; dist_method='euclidean';k=3; clust_method = "ward.D2"; outFile="test.pdf"
    # column names:
    # [1] "Sample_Name"     "Sample_Group"    "Control_kl.div"  "mUPD_kl.div"
    # [5] "pUPD_kl.div"     "Control_p.value" "mUPD_p.value"    "pUPD_p.value"
    # [9] "category"
  #================================================================
  #================================================================
  # chr11p15
  # column names: SAMPLE_NAME     SAMPLE_GROUP    H19_probes_mean KCNQ1OT1_probes_mean    chr11p15

 
  if( tolower(classifier) == "upd2"){
   used <- pred_res[, c(grep("dist",colnames(pred_res)),  grep("p.value",colnames(pred_res)))] 
   used[ used == Inf] <- 5 # set maximum KL value to avoid error 
   ann_col <- intersect(c("category", ann_col), colnames(pred_res))
  }else  if( tolower(classifier) == "upd1"){
   used <- pred_res[, c("ROI_kl.div", "mUPD_kl.div", "pUPD_kl.div", "ROI_p.value", "mUPD_p.value", "pUPD_p.value")] 
   used[ used == Inf] <- 5 # set maximum KL value to avoid error 
   ann_col <- intersect(c("category", ann_col), colnames(pred_res))
  }else if (tolower(classifier) == "chr11p15"){
   used <- pred_res[, intersect(c("H19_probes_mean", "KCNQ1OT1_probes_mean","IC1_mean","IC2_mean"),colnames(pred_res))] 
   ann_col <- intersect(c("chr11p15", ann_col), colnames(pred_res))
  }else if (tolower(classifier) == "imprintome"){
   used <- pred_res[, c("paternal_probes_mean", "maternal_probes_mean")] 
   ann_col <- intersect(c("Imprintome", ann_col), colnames(pred_res))
  }else{
    cat("\n[meth_clust] ERROR: invalid classifier. ",classifier, "\n")
  }

  if(IdColumn %in% colnames(pred_res)){
     rownames(used) <- pred_res[,IdColumn]
  }else{
     rownames(used) <- pred_res$SAMPLE_NAME
  }

  cat ("\n[meth_clust] INFO: annotation columns:",ann_col,"\n")
  annotation_col <- data.frame(pred_res[, ann_col])
  rownames(annotation_col) <- rownames(used)
  colnames(annotation_col) <- ann_col

  if (dist_method %in% c("dist", "euclidean")) {
    hc <- hclust(dist(used), method = clust_method)
  } else if (dist_method == "cor") {
    hc <- hclust(as.dist(1 - cor(t(used))), method = clust_method)
  }

  # hc <-  hclust(dist(t(used)))

  dend <- as.dendrogram(hc)
  cluster_labels_K3 <- cutree(dend, k = 3)
  annotation_col$clusters_k3 <- cluster_labels_K3
  cluster_labels_K4 <- cutree(dend, k = 4)
  annotation_col$clusters_k4 <- cluster_labels_K4

  anno_colors <- list()
  for (i in 1:ncol(annotation_col)) {
    #myColors <- standardColors()[as.integer(as.factor(annotation_col[, i]))]
    extractColors <- GetColors(palette=PALETTES[i],n= length(unique(annotation_col[, i])))
    myColors <- extractColors[as.integer(as.factor(annotation_col[, i]))]
    anno_colors[[i]] <- setNames(unique(myColors), unique(annotation_col[, i]))
  }
  names(anno_colors) <- colnames(annotation_col)
  top_ha <- HeatmapAnnotation(
    df = annotation_col,
    col = anno_colors,
    annotation_name_side = "right"
  )

  dend_height <- 70
  mock_mat <- matrix(nc = nrow(used), nr = 0)
  colnames(mock_mat) <- rownames(used)
  ht_list <- Heatmap(mock_mat,
    cluster_columns = hc,
    top_annotation = top_ha, column_dend_height = unit(dend_height, "mm")
  )

  plotWidth <- 5 + log10(nrow(used)+1) * 6
  plotHeight <- 10
  outFile <- paste0(tools::file_path_sans_ext(outFile), ".pdf") # make sure its extension is pdf
  pdf(outFile, width = plotWidth, height = plotHeight)
  ht <- draw(ht_list, heatmap_legend_side = "bottom", annotation_legend_side = "bottom")
  garbage <- dev.off()
  cat("\n\t", basename(outFile), "[saved]\n")
}
# ================================================================

Meth_cor <-function(data, outPrefix=NULL, fontsize=10, width=10, height=10 ){
  suppressMessages(suppressWarnings(library(ComplexHeatmap)))
  suppressMessages(suppressWarnings(library(circlize))) # For color scheme
  cor_matrix <- cor(data)
  file1<- paste0(outPrefix,"_cor.txt")
  write.table(cor_matrix, file1, sep="\t", quote=FALSE, row.names=TRUE, col.names=TRUE)
  cat("\n[",basename(file1),"[saved]")
    
  # Define custom color scale for correlation (-1 to 1)
  col_fun = colorRamp2(c(-1, 0, 1), c("blue", "white", "red"))
  hm <- Heatmap(cor_matrix, 
        name = "Correlation",            # Legend title
        col = col_fun,                   # Color function
        row_names_gp = gpar(fontsize = fontsize),  # Adjust font size of row names
        column_names_gp = gpar(fontsize = fontsize),  # Adjust font size of column names
        row_names_side = "left",         # Place row names on the left
        column_names_side = "top",       # Place column names at the top
        row_title = "ID",         # Title for rows
        column_title = "ID",      # Title for columns
        row_title_rot = 90,              # Rotate row title
        cluster_rows = TRUE,             # Cluster rows
        cluster_columns = TRUE,          # Cluster columns
        show_row_dend = TRUE,            # Show row dendrogram
        show_column_dend = TRUE,         # Show column dendrogram
        heatmap_legend_param = list(title = "Correlation", direction = "horizontal", title_position = "topcenter")
 )
  filename<- paste0(outPrefix,"_cor.pdf")
  pdf(filename,width = width, height = height)
  ht <- draw(hm, merge_legend=T)
  garbage<-dev.off()
  cat(paste0(basename(filename),"[saved]\n"))
}
# ================================================================


Mirror_BetaValues <- function(values){
  Mirrored_Values=0.5+(0.5-values)
  return(Mirrored_Values)
}
#================================================================

MLR <- function(data,p=0.8){
    library(nnet)  # For multinomial logistic regression
    library(MASS)
    library(caret)
    # Fit the multinomial logistic regression model
    full_model <- multinom(group ~ ., data = data)
    summary(full_model)

    # Stepwise feature selection
    step_model <- stepAIC(full_model, direction = "both", trace = FALSE)

    summary(step_model)

    # Split the data into training and testing sets
    set.seed(123)  # For reproducibility
    trainIndex <- createDataPartition(data$group, p = p, 
                                    list = FALSE, 
                                    times = 1)
    trainData <- data[trainIndex, ]
    testData <- data[-trainIndex, ]


    # Summarize the model
    summary(step_model)

    # Make predictions on the dataset
    predictions1 <- predict(full_model, newdata = testData)

    # Evaluate the model
    confusionMatrix(as.factor(predictions1), as.factor(testData$group))

        # Make predictions on the dataset
    predictions2 <- predict(step_model, newdata = testData)

    # Evaluate the model
    confusionMatrix(as.factor(predictions2), as.factor(testData$group))
   return(full_model)
}


#================================================================


MLR_PRED <- function(score, meta=NULL, model,SAMPLEID="Sample_Name", usedColumns= c("UpScore" , "UpDispersion" ,"DownScore","DownDispersion"), prefix = NULL, probs_cutoff=0.9){
  library(nnet)  # For multinomial logistic regression
  library(MASS)
  library(caret)
  #usedColumns <- c("UpScore" , "UpDispersion" ,"DownScore","DownDispersion")
  # usedColumns <- c("TotalScore","TotalDispersion","UpScore" , "UpDispersion" ,"DownScore","DownDispersion")
  if(!all(usedColumns %in% colnames(score))){
      cat(paste0('\nERROR: invalid score format as input.'))
      return(NULL)
   }
  if(is.null(meta)){
     meta <- score[,setdiff(colnames(score), usedColumns)]
  }

  data <- score
  SAMPLEID <- ifelse(SAMPLEID %in% colnames(meta),SAMPLEID,"Sample_Name")
  rownames(meta) <- meta[,SAMPLEID]
  common_ids <- intersect(data$SAMPLE_NAME, meta[,SAMPLEID])
  if(length(common_ids) <1){
    cat('\nInfo: no common IDs between data and meta.\n')
    return(NULL)
  }
  meta <- meta[common_ids,]
  if(length(common_ids) ==1){
      data <- data.frame(data[,common_ids])
      colnames(data) <-common_ids 
  }else{
      data <- data[common_ids,]
  } 
  if(!is.null(prefix)){
    logFile <- paste0(prefix,"_predict.log")
    sink(logFile)   
  } 
  #used <- data[,c("TotalScore","TotalDispersion","UpScore" , "UpDispersion" ,"DownScore","DownDispersion")]
  used <- data[,usedColumns]
  rownames(used) <- data[,SAMPLEID]
  rf_predictions0 <- predict(model, newdata = used, type = "probs")
  # Get the predicted class and the max probability
  rf_predictions <- apply(rf_predictions0, 1, function(x) {
    if (max(x) < probs_cutoff) {
      return("unknown")
    } else {
      return(names(x)[which.max(x)])
    }
  })
   prob_value <- apply(rf_predictions0, 1, function(probs) {max(probs)})
  common_ids <- intersect(meta[,SAMPLEID],names(rf_predictions)) #intersect(meta[,SAMPLEID],names(prob_value))
  result <- data.frame(PRED=rf_predictions[common_ids], 
                    PROBS= prob_value[common_ids]) 

  print(table(result$PRED))
  combined <- cbind(score, result)
  #================================================================
  if(!is.null(prefix)){
   sink()
   outFile <- paste0(prefix,"_score_predicted.txt")
   write.table(combined, outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
   cat("\n[",basename(outFile),"[saved]\n")
  }
  return(combined)                    
}


#================================================================

Peak_Stat <- function(values, topn=0){
    # return value
    #     height_y index_peak index_left index_right   value_x occurrence
    # 1 2.7736569        118          1         229 0.1068553        104
    # 2 0.4824231        262        229         332 0.5107667         77
    # 3 0.7601190        407        332         512 0.9174830        488
    library(pracma)
    values <- na.omit(values)
    dens <- density(values)
    # Find peaks
    peaks <- findpeaks(dens$y, nups = 1, ndowns = 1, npeaks = Inf)
    # Output Structure of findpeaks()
    # Column	Description
    # 1	Peak height (the y-value of the peak)
    # 2	Index of the peak (position in the input vector)
    # 3	Index of the left valley (local minimum before the peak)
    # 4	Index of the right valley (local minimum after the peak)    

    peaks_df <- as.data.frame(peaks)
    colnames(peaks_df) <- c("height_y","index_peak","index_left","index_right")
    # Get the x-values of the peaks
    peaks_df$value_x <- dens$x[peaks[,2]]  # 
    occurrences <- sapply(1:nrow(peaks), function(i ) {
    left_valley_idx <- peaks[i,3]  # Left valley index
    right_valley_idx <- peaks[i,4] # Right valley index
    sum(values >= dens$x[left_valley_idx] & values <= dens$x[right_valley_idx])
    })
    peaks_df$occurrence <- occurrences
    if(topn != 0){ # only largest peak
       peaks_df <- peaks_df[ order(peaks_df[,"occurrence"],decreasing=TRUE), ]
       return(head(peaks_df,n=as.integer(topn)))       
    }else{
       return(peaks_df)
    }
   
}


plot_imprintome_polar <- function(data) {
  library(ggplot2)
  suppressMessages(suppressWarnings(library(dplyr)))
  # 1. Transform Cartesian scores to Polar Coordinates
  # We center the data so (0,0) is the "Normal" hemimethylated state
  plot_data <- data %>%
    mutate(
      x = maternal_median - 0.5,
      y = paternal_median - 0.5,
      angle = Angle,
      distance = IDS
    )
# 2. Define the Polar Plot
  ggplot(plot_data, aes(x = angle, y = distance, color = distance)) +
    # Background segments for the "3x3" equivalent sectors
    annotate("rect", xmin = -pi, xmax = pi, ymin = 0, ymax = 0.1, 
             fill = "green", alpha = 0.1) + # "Normal" Zone
    geom_point(size = 3, alpha = 0.8) +
    coord_polar(theta = "x") +
    scale_color_viridis_c(option = "magma", name = "Imprint Deviation") +
    scale_x_continuous(
      breaks = c(0, pi/2, pi, -pi/2),
      labels = c("Maternal Gain", "Paternal Gain", "Maternal Loss", "Paternal Loss")
    ) +
    theme_minimal() +
    labs(
      title = "imprintomeR: Polar Plot",
      subtitle = "Mapping Sample Deviations from Hemimethylated Equilibrium",
      x = "Mechanism (Angle)",
      y = "Severity (Distance)"
    )
}

#================================================================


plot_imprintome_polar2 <- function(data, outFile=NULL,colorColumn="Sample_Group", title="ImprintomeR:Polar",palette="default", alpha=0.5) {
  library(ggplot2)
  options(bitmapType = "cairo")
  
  # Define our 8 mechanism anchors
  mechanism_labels <- c(
    "Pat-Gain", "Global-Hyper", "Mat-Gain", "Mat-Gain/Pat-Loss", 
    "Pat-Loss", "Global-Hypo", "Mat-Loss", "Pat-Gain/Mat-Loss"
  )
  
  # Calculate break points in radians (0 to 2pi)
  # 0, 45, 90, 135, 180, 225, 270, 315 degrees
  #degree_breaks <- seq(0, 7*pi/4, by = pi/4)
  degree_breaks = seq(0, 316, by = 45)
  y_ticks <- c( 0.2, 0.4, 0.6, 0.8)
  y_labels <- c("0.2", "0.4", "0.6","0.8")
# 2. Define the Sector Boundaries (The Green Lines)
  # Shifting by -22.5 degrees to create the "grid" boundaries
  boundary_lines <- seq(22.5, 360, by = 45) 

  data$COLOR <- GetColors(palette=palette,n=length(unique(data[,colorColumn])))[as.integer(factor(data[,colorColumn],levels=unique(data[,colorColumn])))]
  uniqCombs <- data.frame(COLOR=data$COLOR, GROUP=data[,colorColumn])
  uniqCombs <- uniqCombs[!duplicated(uniqCombs$COLOR),]
  # sort chr1, chr2...
  data[,colorColumn] <- factor( data[,colorColumn], levels=stringr::str_sort( unique(data[,colorColumn]), numeric = TRUE) )
  
  dotSize <-   4/log10(nrow(data)+10)
  imgSize <-  ifelse(nrow(data) >1000, 12, 8)

  pg <- ggplot(data, aes(x = Angle, y = IDS)) +
    geom_vline(xintercept = degree_breaks, color = "grey90", linetype = "dashed") +
    geom_point(aes(fill = .data[[colorColumn]]),color="grey40",shape=21,size=dotSize, alpha = alpha) +
    coord_polar(theta = "x", start =0,clip = "off") +  # move 0 degree to 
    scale_x_continuous(
      limits = c(0, 360),
      breaks = degree_breaks,
      labels = mechanism_labels,
      expand = c(0, 0)
    ) +
   geom_vline(xintercept = boundary_lines, 
               color = "#2ecc71", # A professional "Bio-Green"
               linetype = "solid", 
               linewidth = 0.8, 
               alpha = 0.6) +    
    annotate("text", x = 90, y = y_ticks, label = y_labels, 
             size = 3.5, color = "darkred", fontface = "bold", vjust = -0.5) + 
    theme_minimal() +
    scale_y_continuous(
      limits = c(0, 0.8),
      breaks = y_ticks,
      expand = c(0, 0),
      labels = NULL # Hide default y-labels to use our annotated ones,
    )+
    scale_fill_manual(name="Color", values=setNames(uniqCombs$COLOR,uniqCombs$GROUP))+ 
    geom_hline(yintercept = 0.2, color = "grey60", linewidth = 0.7, linetype = "solid")+
    theme(
    # Positions the radial (y) axis labels
      axis.text.y = element_text(size = 8, color = "grey40", hjust = 1),
      axis.title.y = element_blank(),
      axis.title = element_blank(),
      # Clean up the circular grid
      panel.grid.major.x = element_line(color = "grey90"), # Radial lines
      panel.grid.major.y = element_line(color = "grey90"), # Circular rings
      
      # Ensure labels don't get cut off
      plot.margin = margin(20, 20, 20, 20),
      axis.text.x = element_text(size = 9, face = "bold")
    ) + 
      labs(
      title = title,
      x = NULL, y = NULL
    )

    if(!is.null(outFile)){
        ggsave(file=outFile,pg,width=imgSize,height=imgSize,units="in", limitsize = TRUE)
    }
    return(pg)
}


#================================================================

PLOT_SNP_LOH <- function(beta, meta, summary_tbl=NULL, SAMPLEID = SAMPLEID, outFile = NULL, alpha = 1, usedProbes=het_probeset){
  library(ggplot2)
  library(gridExtra)
  library(patchwork)
  plot0 <- BetaBeePlot(beta, meta, SAMPLEID=SAMPLEID, outFile=NULL,xlab="", legend=FALSE)   
  plot1 <- BetaBeePlot_line(beta, meta, SAMPLEID = SAMPLEID, outFile = NULL, alpha = 1, usedProbes=usedProbes) 
  if(!is.null(summary_tbl)){
    tbl_grob <- tableGrob(summary_tbl,  
        theme = ttheme_default(
        core = list(fg_params = list(cex = 0.8)),   # cell text size
        colhead = list(fg_params = list(cex = 0.8)) # header text size
      ))
    final_plot <- (plot0|plot1) / tbl_grob
    imgHeight <- 6 + nrow(meta)/5
    imgWidth <- 9
  }else{
    final_plot <- (plot0|plot1) 
    imgHeight < - 5
    imgWidth <- 9
  }
  if(!is.null(outFile)){
      ggsave(file = outFile, final_plot, width = imgWidth, height = imgHeight, units = "in", limitsize = T)
      cat("\n\t", basename(outFile), "[saved]")
  }
  return(final_plot)
}


##################################################################
#  09/11/2025,10:36:15 
##################################################################


PlotCDFs <- function(objCDFstat,prefix, text="ks_dist", ggside="boxplot"){
  library(ggplot2)
  library(ggside)
  meta <- objCDFstat[["meta"]]
  data <- objCDFstat[["data"]]
  stat <- objCDFstat[["Statistics"]]
  summary <- objCDFstat[["Summary"]]

  #----------------------------------------------------------------
  cat("\nINFO: generate cdf plot overview facets ...\n")
  imgHeight <- 10 + max(nchar(meta$SAMPLEID)) /5
  pg <- ggplot(data, aes(x = value,  color = CATEGORY)) +
    stat_ecdf() + xlim(-0.5, 0.5) +
    facet_wrap(~ ID) +
      theme_minimal() + 
      theme_classic(base_size = 10) +
      theme(strip.text = element_text(size = 8))+  # Adjust the size of facet titles
      labs(y = "Cumulative Probability", x = "Deviation from Imprinted Norm") 

  if( text %in% colnames(summary)) {   # add distance or specific column in summary table
    display <- data.frame(ID=summary$SAMPLE_NAME, dist=summary[,text]) 
    display$ID <- factor(display$ID, levels=levels(data$ID))
    display <- display[order(display$ID),] 
    pg <- pg +
      geom_text(data = display, aes(x = -0.2, y = 1, label = paste0(text," = ", round(dist,3))), size = 2, color = "blue")
  }else{
    cat("\n[PlotCDFs] WARN: invalid summary column.[skipped]", text,"\n")
  }
  
  outFile <- paste0(prefix,"_overview_facets.pdf")
  if (nrow(meta) > 20) {
      imgWidth <- 10 + nrow(meta) / 10
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = F)
    } else {
      imgWidth <- min(5 + nrow(meta) / 10, 20)
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = T)
   }
   cat("\n\t", basename(outFile), "[saved]")

  #----------------------------------------------------------------
  cat("\nINFO: generate individual ecdf plot ...\n")
  if (!is.null(ggside)){
    pdfFile <- paste0(prefix,"_detail_pages_ggside.",ggside ,".pdf")
  }else{
    pdfFile <- paste0(prefix,"_detail_pages.pdf")
  }
  cat("\n")  
  pdf(pdfFile,width=5, height = 5)
  for (id in meta$SAMPLEID ){ 
      # procesed  by sample
      cat(paste0(id,".."))
      sample_data <- data[data$ID %in% id, ] 
      stat1 <- stat[[id]]
      area <- stat1[["area"]]
      points_data <- stat1[["points_peak"]]
      distance_data <- stat1[["distance_peak"]]
      euclidean_dist <- distance_data["distance"]
      ks_dist <- round(stat1$KS_test$dist,3)
      pg <- ggplot(sample_data, aes(x=value, colour = CATEGORY)) +
        stat_ecdf()+ xlim(-0.5, 0.5) +
        theme_minimal() + 
        theme_classic(base_size = 10) +
        labs(y = "Cumulative Probability", x = "Deviation from Imprinted Norm",title=id, subtitle=paste0("cdf_area=",area,"; euclidean_dist=",euclidean_dist,"; ks_dist=",ks_dist)) 
      if(ggside=="density"){
        library("ggside")
        pg <- pg + geom_xsidedensity(aes(y = after_stat(density)), show.legend = FALSE) +
            theme_classic(base_size = 10) + 
            theme(panel.border = element_rect(color = "grey30", fill = NA, linewidth = 1))
      }else if(ggside=="boxplot"){
        pg <- pg + geom_xsideboxplot(aes(color= CATEGORY, y =value),width = 0.5, orientation = "y",outlier.shape = NA, show.legend = FALSE)+
            theme(panel.border = element_rect(color = "grey30", fill = NA, linewidth = 1))
            theme( ggside.panel.scale.x = 0.15)  # Adjust the height of the xsideviolin panel +
      }else if(ggside=="violin"){
        pg <- pg + geom_xsideviolin(aes(y =CATEGORY),width = 0.6, orientation = "y", show.legend = FALSE) +
              theme(panel.border = element_rect(color = "grey30", fill = NA, linewidth = .5)) +
              theme( ggside.panel.scale.x = 0.15) # Adjust the height of the xsideviolin panel
       }        
      pg <- pg + 
            geom_point(data = points_data, aes(x = x, y = y, color = CATEGORY), 
                size = 3, shape = 16)
      pg <- pg + geom_vline(xintercept = c(-0.2, 0.2), linetype = "dotted", color = "grey30",linewidth=0.2)         # Plot with connecting line
      pg <- pg +
      geom_segment(aes(x =  distance_data["x1"], y =  distance_data["y1"], xend =  distance_data["x2"], yend =  distance_data["y2"]), 
                  color = "blue", linetype = "dotted", linewidth=0.2,)  
      print(pg)
    } 
  garbage<-dev.off()
  cat("\n\t", basename(outFile), "[saved]")
}

#================================================================


PlotCDFs_norm <- function(objCDFstat,prefix, text="ks_dist_pm", ggside="boxplot"){
  library(ggplot2)
  library(ggside)
  meta <- objCDFstat[["meta"]]
  data <- objCDFstat[["data"]]
  norm <- objCDFstat[["norm"]]
  stat <- objCDFstat[["Statistics"]]
  summary <- objCDFstat[["Summary"]]
  norm$CATEGORY <- "norm"
  #----------------------------------------------------------------
  cat("\nINFO: generate cdf plot overview facets ...\n")
  imgHeight <- 10 + max(nchar(meta$SAMPLEID)) /5
  pg <- ggplot(data, aes(x = value,  color = CATEGORY)) +
    stat_ecdf() + xlim(-0.5, 0.5) +
    facet_wrap(~ ID) +
      theme_minimal() + 
      theme_classic(base_size = 10) +
      theme(strip.text = element_text(size = 8))+  # Adjust the size of facet titles
      labs(y = "Cumulative Probability", x = "Deviation from Imprinted Norm") 

  if( text %in% colnames(summary)) {   # add distance or specific column in summary table
    display <- data.frame(ID=summary$SAMPLE_NAME, dist=summary[,text]) 
    display$ID <- factor(display$ID, levels=levels(data$ID))
    display <- display[order(display$ID),] 
    pg <- pg +
      geom_text(data = display, aes(x = -0.2, y = 1, label = paste0(text," = ", round(dist,3))), size = 2, color = "blue")
  }else{
    cat("\n[PlotCDFs] WARN: invalid summary column.[skipped]", text,"\n")
  }
  
  outFile <- paste0(prefix,"_overview_facets.pdf")
  if (nrow(meta) > 20) {
      imgWidth <- 10 + nrow(meta) / 10
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = F)
    } else {
      imgWidth <- min(5 + nrow(meta) / 10, 20)
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = T)
   }
   cat("\n\t", basename(outFile), "[saved]")

  #----------------------------------------------------------------
  cat("\nINFO: generate individual ecdf plot ...\n")
  if (!is.null(ggside)){
    pdfFile <- paste0(prefix,"_detail_pages_ggside.",ggside ,".pdf")
  }else{
    pdfFile <- paste0(prefix,"_detail_pages.pdf")
  }
  cat("\n")  
  pdf(pdfFile,width=5, height = 5)
  for (id in meta$SAMPLEID ){ 
      # procesed  by sample
      # id ="OT_sample1"
      cat(paste0(id,".."))
      sample_data <- data[data$ID %in% id, ] 
      used <- rbind(sample_data, norm) # add norm
      stat1 <- stat[[id]]
      area <- stat1[["area"]]
      points_data <- stat1[["points_peak"]]
      distance_data <- stat1[["distance_peak"]]
      euclidean_dist <- distance_data["distance"]
      area_p <- round(stat1$area$paternal,3);
      area_m <- round(stat1$area$maternal,3);
      ks_dist_pm <- round(stat1$KS_test$dist,3);
      ks_dist_p <- round(stat1$KS_paternal$dist,3);
      ks_dist_m <- round(stat1$KS_maternal$dist,3)
      ks_dist <- round(stat1$KS_test$dist,3)
      subTitle <- paste0("cdf_area=",area,"; ks_dist=",ks_dist_pm,"; euclidean_dist=",euclidean_dist,"\n")
      subTitle <- paste0(subTitle, "ks_dist_p=",ks_dist_p,"; ks_dist_m=",ks_dist_m,"\n")
      subTitle <- paste0(subTitle,"area_p=",area_p,"; area_m=",area_m )
      used$CATEGORY <- factor(used$CATEGORY, levels=c("paternal","norm","maternal"))
      used <- used[ order(used[,"CATEGORY"]), ]
      pg <- ggplot(used, aes(x=value, colour = CATEGORY, linetype=CATEGORY, size=CATEGORY)) +
        stat_ecdf()+ xlim(-0.5, 0.5) +
        theme_minimal() + 
        scale_linetype_manual(values = c("solid", "solid", "solid")) +
        scale_size_manual(values = c(0.5, 0.25,0.5)) +
        theme_classic(base_size = 10) +
        labs(y = "Cumulative Probability", x = "Deviation from Imprinted Norm",title=id, subtitle=subTitle) 
      if(ggside=="density"){
        library("ggside")
        pg <- pg + geom_xsidedensity(aes(y = after_stat(density)), show.legend = FALSE) +
            theme_classic(base_size = 10) + 
            theme(panel.border = element_rect(color = "grey30", fill = NA, linewidth = 1))
      }else if(ggside=="boxplot"){
        pg <- pg + geom_xsideboxplot(aes(color= CATEGORY, y =value),width = 0.5, orientation = "y",outlier.shape = NA, show.legend = FALSE)+
            theme(panel.border = element_rect(color = "grey30", fill = NA, linewidth = 1))
            theme( ggside.panel.scale.x = 0.15)  # Adjust the height of the xsideviolin panel +
      }else if(ggside=="violin"){
        pg <- pg + geom_xsideviolin(aes(y =CATEGORY),width = 0.6, orientation = "y", show.legend = FALSE) +
              theme(panel.border = element_rect(color = "grey30", fill = NA, linewidth = .5)) +
              theme( ggside.panel.scale.x = 0.15) # Adjust the height of the xsideviolin panel
       }        
      pg <- pg + 
            geom_point(data = points_data, aes(x = x, y = y, color = CATEGORY), 
                size = 3, shape = 16)
      pg <- pg + geom_vline(xintercept = c(-0.2, 0.2), linetype = "dotted", color = "grey30",linewidth=0.2) +        
                geom_hline(yintercept = c(0.25, 0.5,0.75), linetype = "dotted", color = "grey30",linewidth=0.2)        
      pg <- pg +
      geom_segment(aes(x =  distance_data["x1"], y =  distance_data["y1"], xend =  distance_data["x2"], yend =  distance_data["y2"]), 
                  color = "blue", linetype = "dotted", linewidth=0.2,)  
      print(pg)
    } 
  garbage<-dev.off()
  cat("\n\t", basename(outFile), "[saved]")
}

##################################################################
#  04/28/2025,13:10:37 
##################################################################

plotDensity2 <- function(rankData, sample, patSet,matSet) {
  library(ggplot2)
  sample =id; patSet=gmt[["paternal"]]; matSet=gmt[["maternal"]]
  ranks <- rankData[, sample]
  plot_data <- data.frame(
      ranks = c(ranks[patSet], ranks[matSet]),
      probeSet = rep(c("paternal", "maternal"), c(length(patSet), length(matSet)))
      ) 
  pg1 <- ggplot(plot_data, aes(x = ranks)) +
      stat_density(aes(x=ranks, colour=probeSet), geom="line",position="identity", linewidth = 0.5) + 
      scale_y_continuous(expand = expansion(mult = c(0.3, 0.3)))+  
      geom_rug(data = subset(plot_data, probeSet == "paternal"), aes(color = probeSet), 
      sides = "t",alpha = 0.7, linewidth =0.2,length = unit(0.1, "npc"),show.legend = FALSE) +
      geom_rug(data = subset(plot_data, probeSet == "maternal"), aes(color = probeSet), 
      sides = "b",alpha = 0.7, linewidth =0.2,length = unit(0.1, "npc"),show.legend = FALSE) #+ scale_color_manual(values = c("paternal" = "blue", "maternal" = "red")) 
  plot <- pg1 +    
      labs(title = "Rank Density", subtitle= sample,   x = "Rank",  y = "Density") + theme_classic(base_size = 10) +
      theme(
      panel.grid.major = element_line(linewidth = 0.1),
      panel.grid.minor = element_line(linewidth = 0.1),
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.25)
      )+ guides(colour = guide_legend(override.aes = list(alpha = 1)))
      
  print(plot)
}
#================================================================

#================================================================



PlotSankey <- function(beta, meta, outFile=NULL,low_cutoff=0.3,high_cutoff=0.7 ) {
  suppressMessages(suppressWarnings(library(dplyr)))
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library(ggsankey))) # devtools::install_github("davidsjoberg/ggsankey")
  #metaFile <- "N2.Mom_meta2.txt" ;  snpBetaFile <- "SNP_N2/N2.Mom_snpBeta.txt"; low_cutoff=0.3; high_cutoff=0.7
  #input <- LoadMetaBeta(metaFile, snpBetaFile, probeset = NULL)
  #meta <- input[["meta"]]
  #beta <- input[["beta"]]
  aveBeta <- CalcAvgByGrp(beta,meta)

  breaks <- c(0, low_cutoff, high_cutoff, 1)
  labels <- c("BB", "AB", "AA")
  genotypes <- as.data.frame(lapply(aveBeta, function(x) cut(x, breaks = breaks, labels = labels, include.lowest = TRUE)))

  rownames(genotypes) <- rownames(aveBeta)
# Define the columns you want to use as variables
  columns <- colnames(aveBeta)
  columns <- sort(columns)
  aveBeta <- aveBeta[,columns]
  df <- genotypes %>% ggsankey::make_long(!!!syms(columns))
  plot <- ggplot(df, aes(
    x = x,
    next_x = next_x,
    node = node,
    next_node = next_node,
    fill = factor(node),
    label = node
  )) +
    geom_sankey(flow.alpha = 0.8) +
    geom_sankey_label(size = 2) +
    theme_sankey(base_size = 12) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  ggsave(file = outFile, plot, width = 6, height = 7, units = "in", limitsize = TRUE)
  cat("\n\t", basename(outFile), " [saved]")
}
#================================================================


#================================================================

Predict_UPD <- function(meta, beta, mdlFile="GSE64244_rf.model.rds", threshold=0.8,threshold2=0.7, outFile=NULL){
  library(randomForest)
  model_path <- "/research/rgs01/home/clusterHome/hjin/projects/imprintomeR_dev/selected/"
  rdsFile <- paste0(model_path,"/",mdlFile)
  rf_model <- readRDS(rdsFile)
  dfTest <- as.data.frame(t(beta))
  rf_predictions0 <- predict(rf_model, dfTest,type = "prob")
  # Define the threshold for assigning "unknown" and  Assign "unknown" label based on the threshold
  rf_predictions <- apply(rf_predictions0, 1, function(probs) {
    if (max(probs) < threshold2) {
      return("unknown")
    }else if (max(probs) >= threshold2 & max(probs) < threshold) {
      return(paste0(colnames(rf_predictions0)[which.max(probs)],"_like") )
    } else {
      return(colnames(rf_predictions0)[which.max(probs)])
    }
  })
  prob_value <- apply(rf_predictions0, 1, function(probs) {
    max(probs)
  })

  meta$PRED_RF <- rf_predictions[intersect(meta$Sample_Name,names(rf_predictions))]
  meta$PROBS_RF <-  prob_value[intersect(meta$Sample_Name,names(prob_value))]
  write.table(meta, outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
  cat("\n[",basename(outFile),"[saved]\n")
  print(table(meta[,c("PRED_RF")]))
}

##################################################################

#==============================================================
# 01/09/2025, 13:41:56

Predict_UPD_CDF_stat <-  function(data,meta,SAMPLEID="ID2",mdlFile="all4sets_classifier2_CDF_stat_rf_models.rds", threshold_high=0.9,threshold_low=0.85, outFile=NULL){
  if (!requireNamespace("randomForest", quietly = TRUE)) install.packages("randomForest")
  suppressMessages(suppressWarnings(library(randomForest)))   
  outPrefix <- tools::file_path_sans_ext(outFile)
  if(!file.exists(mdlFile)){
    model_path <- "/research/rgs01/home/clusterHome/hjin/projects/imprintomeR_dev/final2025/selected"
    rdsFile <- paste0(model_path,"/",mdlFile)  
  }else{
    rdsFile <- mdlFile
  }
  
  if(file.exists(rdsFile)){
      model <- readRDS(rdsFile)
  }else{
    cat("\nError: model file not found.\n", rdsFile,"\n\n")
    return(NULL)
  }
  # input data format; sampleID (row) x features (column)
  SAMPLEID <- ifelse(SAMPLEID %in% colnames(meta),SAMPLEID,"Sample_Name")
  rownames(meta) <- meta[,SAMPLEID]
  common_ids <- intersect(data$SAMPLE_NAME, meta[,SAMPLEID])
  if(length(common_ids) <1){
    cat('\nInfo: no common IDs between data and meta.\n')
    return(NULL)
  }
  meta <- meta[common_ids,]
  if(length(common_ids) ==1){
      data <- data.frame(data[,common_ids])
      colnames(data) <-common_ids 
  }else{
      data <- data[common_ids,]
  } 
  logFile <- paste0(outPrefix,"_predict.log")
  sink(logFile)      
  rf_predictions0 <- predict(model, data,type = "prob")
  if(threshold_high <= threshold_low){
    threshold_low <- threshold_high - 0.1
  }
  print(str(rf_predictions0))
  # Define the threshold for assigning "unknown" and  Assign "unknown" label based on the threshold
  rf_predictions <- apply(rf_predictions0, 1, function(probs) {
          if (max(probs) < threshold_low) {
            return("unknown")
          }else if (max(probs) >= threshold_low & max(probs) < threshold_high) {
            return(paste0(colnames(rf_predictions0)[which.max(probs)],"_like") )
          } else {
            return(paste0(colnames(rf_predictions0)[which.max(probs)]))
          }
        })
  prob_value <- apply(rf_predictions0, 1, function(probs) {max(probs)})
  common_ids <- intersect(meta[,SAMPLEID],names(rf_predictions)) #intersect(meta[,SAMPLEID],names(prob_value))
  result <- data.frame(PRED=rf_predictions[common_ids], 
                    PROBS= prob_value[common_ids])

  print(table(result$PRED))
  sink()
  combined <- cbind(meta, result)
  #================================================================
  if(!is.null(outFile)){
   write.table(combined, outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
   cat("\n[",basename(outFile),"[saved]\n")
  }
  return(combined)
}
#================================================================
##################################################################
#  04/13/2025,17:16:24 
##################################################################

Predict_UPD_chr_v6 <-  function(meta, beta,mdlFile="final_std1_selected_v6_chr_rf_models.rds", threshold_high=0.8,threshold_low=0.7, outFile=NULL){
  suppressMessages(suppressWarnings(library( randomForest)))
  Summarize_Result <- function(metaFile){
      meta <- LoadMeta(metaFile)
      RowCount_UPD <- function(row) {
        sum(grepl("UPD$", row))
      }      
      RowCount_pUPD <- function(row) {
        sum(grepl("pUPD$", row))
      }
      RowCount_mUPD <- function(row) {
        sum(grepl("mUPD$", row))
      }     
      RowCount_unknown <- function(row) {
        sum(grepl("unknown", row))
      }   
      RowCount_ROI <- function(row) {
        sum(grepl("ROI", row))
      }          
      RowCount_pUPD_SelectedChrs <- function(row) {
        sum(c("chr11_pUPD","chr14_pUPD","chr16_pUPD","chr20_pUPD") %in% row)
      } 
      RowCount_mUPD_SelectedChrs <- function(row) {
        sum(c("chr11_mUPD","chr14_mUPD","chr16_mUPD","chr20_mUPD") %in% row)
      }       
      SingleChr_UPD <- function(row) {
        if(sum(grepl("UPD$", row))==1){
          row[grepl("UPD$", row)]
        }else{
          "unknown"
        }
      }

      meta_pred <- meta[, grep("PRED_CHR", colnames(meta))]
      UPD_chr_counts <- apply(meta_pred, 1, RowCount_UPD)
      pUPD_chr_counts <- apply(meta_pred, 1, RowCount_pUPD)
      mUPD_chr_counts <- apply(meta_pred, 1, RowCount_mUPD)
      ROI_chr_counts <- apply(meta_pred, 1, RowCount_ROI)
      pUPD_SelectedChrs_counts <- apply(meta_pred, 1, RowCount_pUPD_SelectedChrs)
      mUPD_SelectedChrs_counts <- apply(meta_pred, 1, RowCount_mUPD_SelectedChrs)
      unknown_chr_counts <- apply(meta_pred, 1, RowCount_unknown)
      SingleChr_UPD_labels <- apply(meta_pred, 1, SingleChr_UPD)
      GW_ROI.UPDs <- gsub("all","GW", meta$PRED_ALL)
      pred_summary <- data.frame( pUPD_CHR_COUNT= pUPD_chr_counts,mUPD_CHR_COUNT= mUPD_chr_counts,ROI_CHR_COUNT=ROI_chr_counts,GW_COUNT=GW_ROI.UPDs)
      pred_summary$CATEGORY <-  "unknown"
      idx_singleChrUPD  <- UPD_chr_counts ==1 & ROI_chr_counts >unknown_chr_counts
      pred_summary$CATEGORY [idx_singleChrUPD] <- SingleChr_UPD_labels[UPD_chr_counts==1 & idx_singleChrUPD]
      idx_GW_UPD <- GW_ROI.UPDs %in% c("GW_pUPD","GW_mUPD") & ROI_chr_counts ==0 & (pUPD_chr_counts==0 | mUPD_chr_counts==0) & (pUPD_SelectedChrs_counts==4|mUPD_SelectedChrs_counts==4)
      idx_GW_UPD_like <- GW_ROI.UPDs %in% c("GW_pUPD","GW_mUPD","GW_pUPD_like","GW_mUPD_like") & ROI_chr_counts ==0 & (pUPD_chr_counts==0 | mUPD_chr_counts==0) & (pUPD_SelectedChrs_counts>=3|mUPD_SelectedChrs_counts>=3)
      pred_summary$CATEGORY [idx_GW_UPD_like] <- GW_ROI.UPDs[idx_GW_UPD_like]
      pred_summary$CATEGORY [idx_GW_UPD] <- GW_ROI.UPDs[idx_GW_UPD]
      idx_GW_ROI_like <- GW_ROI.UPDs %in% "GW_ROI_like" & ROI_chr_counts >0 & pUPD_chr_counts==0 & mUPD_chr_counts==0
      pred_summary$CATEGORY[idx_GW_ROI_like]  <- "GW_ROI_like"     
      idx_GW_ROI <- GW_ROI.UPDs %in% "GW_ROI" & ROI_chr_counts >0 & pUPD_chr_counts==0 & mUPD_chr_counts==0
      pred_summary$CATEGORY[idx_GW_ROI]  <- "GW_ROI"
      res <- cbind(meta[, intersect(c("Sample_Name","Sample_Group","ID2"),colnames(meta)) ], pred_summary)
      return(res)
  }
  Run_Pred_All <- function(beta, meta, models,chrs=NULL,threshold_high=0.8,threshold_low=0.7,outPrefix=NULL){
    if (!requireNamespace("randomForest", quietly = TRUE)) install.packages("randomForest")
    suppressMessages(suppressWarnings(library(randomForest)))   
    if(is.null(chrs)){
      chrs <- names(models)
    }
    outXlsx <- paste0(outPrefix,"_stat.all.xlsx")
    logFile <- paste0(outPrefix,"_predict.log")
    sink(logFile)      
    for(chr in chrs){
      cat("\n [",chr,"]")
      stat <- Calc_Stat_Chr_v6(beta,probeset="selected", chrs=chr)
      SaveTable(stat, sheetName=chr,file=outXlsx, rowNames=T,append=T)
      dfTest <- as.data.frame(stat)
      model1 <- models[[chr]]
      rf_predictions0 <- predict(model1, dfTest,type = "prob")
      if(threshold_high <= threshold_low){
        threshold_low <- threshold_high - 0.1
      }
      print(str(rf_predictions0))
      # Define the threshold for assigning "unknown" and  Assign "unknown" label based on the threshold
      rf_predictions <- apply(rf_predictions0, 1, function(probs) {
              if (max(probs) < threshold_low) {
                return("unknown")
              }else if (max(probs) >= threshold_low & max(probs) < threshold_high) {
                return(paste0(chr,"_",colnames(rf_predictions0)[which.max(probs)],"_like") )
              } else {
                return(paste0(chr,"_",colnames(rf_predictions0)[which.max(probs)]))
              }
            })
      prob_value <- apply(rf_predictions0, 1, function(probs) {max(probs)})
      res <- data.frame(PRED=rf_predictions[intersect(meta$Sample_Name,names(rf_predictions))], 
                        PROBS= prob_value[intersect(meta$Sample_Name,names(prob_value))])
      colnames(res) <- paste0( colnames(res), "_", chr)
      meta <- cbind(meta, res)    
      print(table(res[,1]))   
    }
    sink()
    #================================================================
    return(meta)  
  }
  #================================================================
  library(randomForest)
  outPrefix <- tools::file_path_sans_ext(outFile)
  if(!file.exists(mdlFile)){
      model_path <- "/home/hjin/projects/imprintomeR_dev/final2025/model_v6/"
      rdsFile <- paste0(model_path,"/",mdlFile)
  }
  if(!file.exists(rdsFile)){
      model_path <- "/home/hjin/projects/imprintomeR_dev/final2025/model_v7_mclust/"
      rdsFile <- paste0(model_path,"/",mdlFile)
  }
  if(file.exists(rdsFile)){
      models <- readRDS(rdsFile)
  }else{
    cat("\nError: model file not found.\n", rdsFile,"\n\n")
    q("no")
  }
  outXlsx <- paste0(outPrefix,"_predict.all.xlsx")
  result <- Run_Pred_All(beta, meta, models, chrs=NULL, threshold_high=threshold_high,threshold_low=threshold_low,outPrefix=outPrefix)
  write.table(result, outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
  cat("\n[",basename(outFile),"[saved]\n")
  SaveTable(result, sheetName="predict.all",file=outXlsx, rowNames=F,append=T)
  # summarize predictions 
  idx_PRED <- grep("PRED_",colnames(result))
  result <- result[,idx_PRED]  
  result_label <- cbind(meta[, intersect(c("Sample_Name","Sample_Group","ID2"),colnames(meta))], result)
  outFile2 <- paste0(tools::file_path_sans_ext(outFile), "_label.txt")
  write.table(result_label, outFile2, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
  cat("\n[",basename(outFile2),"[saved]\n")
  SaveTable(result_label, sheetName="predict.label",file=outXlsx, rowNames=F,append=T)
  outFile3 <- paste0(tools::file_path_sans_ext(outFile), "_simple.txt")
  summary <- Summarize_Result(outFile)
  write.table(summary, outFile3, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
  cat("\nInfo: ", basename(outFile3), "[saved]\n")
  SaveTable(summary, sheetName="predict.simple",file=outXlsx, rowNames=F,append=T)
}



Predict_UPD_PCA <-  function(data,meta,SAMPLEID="ID2",mdlFile="final_std3_classifier2_PCA_rf_model.rds", threshold_high=0.9,threshold_low=0.85, outFile=NULL){
  if (!requireNamespace("randomForest", quietly = TRUE)) install.packages("randomForest")
  suppressMessages(suppressWarnings(library(randomForest)))   
  outPrefix <- tools::file_path_sans_ext(outFile)

  if(file.exists(mdlFile)){
    rdsFile <- mdlFile
  }else{
    if(!file.exists(mdlFile)){
      model_path <- "/research/rgs01/home/clusterHome/hjin/projects/imprintomeR_dev/final2025/selected/PCA_selected"
      rdsFile <- paste0(model_path,"/",mdlFile)  
    }
    if(!file.exists(mdlFile)){
      model_path <- "/research/rgs01/home/clusterHome/hjin/projects/imprintomeR_dev/11p15_classifier/set7_censored_PCA"
      rdsFile <- paste0(model_path,"/",mdlFile)  
    }
  }

  if(file.exists(rdsFile)){
      model <- readRDS(rdsFile)
  }else{
    cat("\nError: model file not found.\n", rdsFile,"\n\n")
    return(NULL)
  }
  # input data format; sampleID (row) x features (column)
  SAMPLEID <- ifelse(SAMPLEID %in% colnames(meta),SAMPLEID,"Sample_Name")
  rownames(meta) <- meta[,SAMPLEID]
  common_ids <- intersect(data$SAMPLE_NAME, meta[,SAMPLEID])
  if(length(common_ids) <1){
    cat('\nInfo: no common IDs between data and meta.\n')
    print(head(data$SAMPLE_NAME,n=3))
    print(head(meta[,SAMPLEID],n=3))
    return(NULL)
  }
  meta <- meta[common_ids,]
  if(length(common_ids) ==1){
      data <- data.frame(data[,common_ids])
      colnames(data) <-common_ids 
  }else{
      data <- data[common_ids,]
  } 
  logFile <- paste0(outPrefix,"_predict.log")
  sink(logFile)      
  rf_predictions0 <- predict(model, data,type = "prob")
  if(threshold_high <= threshold_low){
    threshold_low <- threshold_high - 0.1
  }
  print(str(rf_predictions0))
  # Define the threshold for assigning "unknown" and  Assign "unknown" label based on the threshold
  rf_predictions <- apply(rf_predictions0, 1, function(probs) {
          if (max(probs) < threshold_low) {
            return("unknown")
          }else if (max(probs) >= threshold_low & max(probs) < threshold_high) {
            return(paste0(colnames(rf_predictions0)[which.max(probs)],"_like") )
          } else {
            return(paste0(colnames(rf_predictions0)[which.max(probs)]))
          }
        })
  prob_value <- apply(rf_predictions0, 1, function(probs) {max(probs)})
  common_ids <- intersect(meta[,SAMPLEID],names(rf_predictions)) #intersect(meta[,SAMPLEID],names(prob_value))
  result <- data.frame(PRED=rf_predictions[common_ids], 
                    PROBS= prob_value[common_ids])

  print(table(result$PRED))
  sink()
  kept_cols <- intersect(colnames(meta),c("Sample_Name","ID2","Sample_Group","COLOR","SHAPE","GEO_ACCESSION","BATCH","GSM"))
  combined <- cbind(meta[,kept_cols], result)
  #================================================================
  if(!is.null(outFile)){
   write.table(combined, outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
   cat("\n[",basename(outFile),"[saved]\n")
  }
  return(combined)
}
#================================================================


Prepare_control <- function(probeset="selected",assay="EPIC"){
  # availalbe probesets
    #names(probesets)
    #[1] "Jima"     "Joshi"   "NanoImprint"  "chr11p15"  "selected"  
    #[6] "all"    "zambegrp"

  if(grepl("EPIC",assay,ignore.case = T)){
    metaFile1 <- "/home/hjin/projects/imprintomeR_dev/control/EPICV2_imputed.ctrl_meta.txt"
    betaFile1 <- "/home/hjin/projects/imprintomeR_dev/control/EPICV2_imputed.ctrl_beta.txt"
  }else if(grepl("450K",assay,ignore.case = T)) {
    metaFile1 <- "/home/hjin/projects/imprintomeR_dev/control/HM450K_imputed.ctrl_meta.txt"
    betaFile1 <- "/home/hjin/projects/imprintomeR_dev/control/HM450K_imputed.ctrl_beta.txt"
    #metaFile <- "/home/hjin/projects/imprintomeR_dev/GSE64244.UPD_Clay2019.control_join_meta.txt"
    #betaFile <- "/home/hjin/projects/imprintomeR_dev/GSE64244.UPD_Clay2019.control_join_beta.txt"
  }else{
    cat("\nWARN: invalid array.",assay," is unavailable. Use EPIC control instead.")
    metaFile1 <- "/home/hjin/projects/imprintomeR_dev/control/EPICV2_imputed.mUPD_meta.txt"
    betaFile1 <- "/home/hjin/projects/imprintomeR_dev/control/EPICV2_imputed.mUPD_beta.txt"
  }
  rdsFile <- paste0("/home/hjin/projects/ImprintomeR/package/inst/extdata/imprintomeR_control_assay.",assay,"_set.",probeset,".rds")

  if(file.exists(rdsFile)){
     control <- readRDS(rdsFile)
     cat("\nINFO: control set,",probeset," [loaded]")
  }else{
     control <- LoadMetaBeta(metaFile1, betaFile1, probeset =probeset)
     saveRDS( control, file=rdsFile)
     cat("\nINFO: control set,",probeset," [saved]")
  }
  return(control)
}
##################################################################
# ================================================================

Probeset_Imprinting_Source <- function( probeset="selected"){
  cat("\nINFO: Determine probeset's imprinting source \n")  
  # EPIC
    metaFile1 <- "/home/hjin/projects/imprintomeR_dev/control/EPICV2_imputed.ctrl_meta.txt"
    betaFile1 <- "/home/hjin/projects/imprintomeR_dev/control/EPICV2_imputed.ctrl_beta.txt"
    control1 <- LoadMetaBeta(metaFile1, betaFile1, probeset =probeset)
   beta1 <- control1[["beta"]]
   meta1 <- control1[["meta"]]
   probesets1 <-  control1[["probesets"]]
   beta_grp1 <- CalcAvgByGrp(beta1, meta1) 
   max_indices1 <- max.col(beta_grp1)

# Use the indices to get the column names
    beta_grp1$origin <- colnames(beta_grp1)[max_indices1]
    table(beta_grp1$origin)
    beta_grp1[beta_grp1$origin %in% "ROI",]

  # "450K"
    #metaFile2 <- "/home/hjin/projects/imprintomeR_dev/control/HM450K_imputed.ctrl_meta.txt"
    #betaFile2 <- "/home/hjin/projects/imprintomeR_dev/control/HM450K_imputed.ctrl_beta.txt"
    
    metaFile2 <- "/home/hjin/projects/imprintomeR_dev/GSE183798_GCT/GSE183798_GCT_subset21_meta.txt"
    betaFile2 <- "/home/hjin/projects/imprintomeR_dev/GSE183798_GCT/GSE183798_GCT_subset21_beta.txt"
    control2 <- LoadMetaBeta(metaFile2, betaFile2, probeset =probeset)
    beta2 <- control2[["beta"]]
    meta2 <- control2[["meta"]]
    probesets2 <-  control2[["probesets"]]
    beta_grp2 <- CalcAvgByGrp(beta2, meta2) 
    max_indices2 <- max.col(beta_grp2)
    beta_grp2$origin <- colnames(beta_grp2)[max_indices2]
    table(beta_grp2$origin)
    beta_grp2[beta_grp2$origin %in% "Ref_Control",]

   origins <-   merge(x = beta_grp1, y = beta_grp2, by = "row.names", all = TRUE) # Outer join by row.names
   colnames(origins) <- gsub("origin.x","origin.EPIC", colnames(origins))
   colnames(origins) <- gsub("origin.y","origin.HM450K", colnames(origins))
   print(table(origins[,c("origin.EPIC","origin.HM450K")]))
   
#origin.EPIC Ref_Control Ref_mUPD Ref_pUPD
#       mUPD           0      258        0
#       pUPD           5       33       84
#       ROI            0       11        0
   origins$origin <- "undetermined"
   origins$origin [origins$origin.EPIC %in%  c("mUPD","ROI") & origins$origin.HM450K %in%  "Ref_mUPD" ] <- "maternal"
   origins$origin [origins$origin.EPIC %in%  "pUPD" & origins$origin.HM450K %in%  c("Ref_pUPD","Ref_Control") ] <- "paternal"
  print(table(origins$origin))
#  maternal     paternal undetermined
#     269           89          114
    pFile <- "/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds"
    probesets0 <- readRDS(pFile)
    p <- probesets0[[probeset]]
    p$ORIGIN <- origins$origin[match(p$NAME,origins$Row.names)]
    probesets0[[probeset]] <- p
    saveRDS(probesets0, file=pFile)
  cat("\nINFO: probesets_hg19.rds [updated & saved]\n")  
}

# ================================================================

Probeset_Imprinting_Source2 <- function( probeset="selected"){
   # cd /home/hjin/projects/imprintomeR_dev/selected/
    cat("\nINFO: Determine probeset's imprinting source \n")  
    metaFile1 <- "/home/hjin/projects/imprintomeR_dev/selected/golden_std_wb_meta.txt"
    betaFile1 <- "/home/hjin/projects/imprintomeR_dev/selected/golden_std_wb_selected_beta.txt"
    control1 <- LoadMetaBeta(metaFile1, betaFile1, probeset =probeset)
   beta1 <- control1[["beta"]]
   meta1 <- control1[["meta"]]
   probesets1 <-  control1[["selected"]]
   beta_grp1 <- CalcAvgByGrp(beta1, meta1) 
   max_indices1 <- max.col(beta_grp1) 

   beta_grp1$origin <- colnames(beta_grp1)[max_indices1]

    pFile <- "/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds"
    probesets0 <- readRDS(pFile)
    p <- probesets0[[probeset]]
    p$ORIGIN <- beta_grp1$origin[match(p$NAME,rownames(beta_grp1))]
    p$ORIGIN[p$ORIGIN %in% "ROI"] <- "undetermined"
    p$ORIGIN[p$ORIGIN %in% "mUPD"] <- "maternal"
    p$ORIGIN[p$ORIGIN %in% "pUPD"] <- "paternal"
    print(table(p$ORIGIN))
    #    maternal     paternal undetermined
    #        275           86            2
    probesets0[[probeset]] <- p
    saveRDS(probesets0, file=pFile)
   cat("\nINFO: probesets_hg19.rds [updated & saved]\n")  

}

#================================================================

Project2PCA <- function(newdata, PCAobj){
  pca_model <-  PCAobj[["pcs"]]
  rotation <- pca_model$rotation
  model_probes <- rownames(rotation)
  input_probes <- rownames(newdata)
  if(!all(model_probes %in% input_probes)){
    cat("\nWarning: PCA projection requires the same feature set as the original training data.\n")
    missing_probes <- setdiff(model_probes,input_probes)
    cat("\nInfo: length(missing_probes)=",length(missing_probes))
    if(length(missing_probes)<20){
      cat("\nInfo: try to only use common probes..")
       model_probes <- intersect(model_probes,input_probes)
       rotation <- rotation[model_probes,] 
    }else{
      cat("\nTerminated.\n")
      q("no")
    }
  }
  data_used <- t(as.matrix(newdata[model_probes,]))
  new_scaled <- scale(data_used, center = pca_model$center[model_probes], scale = pca_model$scale)
  new_pca_coords <- new_scaled %*% rotation
  return(new_pca_coords)
}

#================================================================

ReadGmtToList <- function(gmtFile) {
  # load GSEA genesets
  tmp <- readLines(con = gmtFile)
  # create temp files
  tmp <- gsub(" ", "\t", tmp)
  genesets <- strsplit(tmp, "\t")
  gsNames <- unlist(lapply(genesets, "[", 1))
  genesets <- lapply(X = tmp, FUN = function(x) {
    x <- unlist(strsplit(x, "\t"))
    x <- x[3:length(x)]
  })
  names(genesets) <- gsNames
  return(genesets)
}


Run_MethylToSNP <- function(){
  b="/research_jude/rgs01_jude/groups/zambegrp/projects/ACT_XAF1_TP53/common/cab/ACT/Methylation/zambegrp_846323_EPICv2/QC.Raw/CAB_7690_beta.txt"
  m="/research_jude/rgs01_jude/groups/zambegrp/projects/ACT_XAF1_TP53/common/cab/ACT/Methylation/zambegrp_846323_EPICv2/CAB_7690_sampleInfo_final.txt"
  input <- LoadMetaBeta(m, b, probeset = NULL)
  meta <- input[["meta"]]
  beta <- input[["beta"]]
  res <- MethylToSNP(
    beta,
    gap.ratio = 0.75,
    gap.sum.ratio = 0.5,
    verbose = FALSE,
    outlier.sd = 3
  )
  # data	 A matrix or a data frame or an GenomicRatioSet, GenomicMethylSet, MethylSet, or RatioSet object (see minfi package)
  # gap.ratio	 The ratio of two gaps should be above the threshold.
  # gap.sum.ratio	 The ratio of the sum of two gaps relative to the total range of values should be above the threshold.
  # verbose	 Show additional information. Useful for debugging.
  # outlier.sd	 Do not consider outliers that are more than the specified number of standard deviations from the cluster center
  rdsFile <- "CAB_7690_MethylToSNP.result.rds"
  saveRDS(res,file=rdsFile)
  cat(paste0('\n ',basename(rdsFile),' [saved]'))

  outFile <-"CAB_7690_MethylToSNP.result.txt"
  write.table(cbind(TargetID=rownames(res),res), outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
  cat("\n[",basename(outFile),"[saved]")

  beta1 <- beta[rownames(res),]

  meta1 <- meta
  meta1$SAMPLE_GROUP [meta1$SAMPLE_GROUP %in% c("ACT","ACT_recurrence","neuroendocrine_tumor","retroperitoneal","retroperitoneal2_Hylo")] <- "ACT"
  meta1$SAMPLE_GROUP [grep("MOM",meta1$ID2)] <- "germline_MOM"

  idx_ACT <- meta1$SAMPLE_GROUP %in% "ACT"
  idx_germline <- meta1$SAMPLE_GROUP %in% "germline"
  low_cutoff <- 0.3 
  high_cutoff <- 0.7
  n_LOH_in_ACT <-  rowSums(apply(beta1[, idx_ACT],2, function(x)!Between(x, low_cutoff,high_cutoff))) 
  n_Het_in_germline <-  rowSums(apply(beta1[, idx_germline],2, function(x) Between(x, low_cutoff,high_cutoff))) 

  x <- data.frame(n_LOH_in_ACT,n_Het_in_germline)
  x1 <- x[x$n_Het_in_germline>0 & (x$n_LOH_in_ACT > x$n_Het_in_germline),]
  probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
  selected_probeset <- probesets[["selected"]]

  probes <- intersect(selected_probeset$NAME,rownames(x1))
  print(length(probes))  # 

  #================================================================
  suppressMessages(suppressWarnings(library(IlluminaHumanMethylationEPICanno.ilm10b4.hg19)))
  data(SNPs.147CommonSingle)

  xx <- 
  x1_ann <- merge(x=res[rownames(x1),], y=SNPs.147CommonSingle, by = "row.names", all.x = TRUE) # left join by row.names

  dim(aveBeta_N2) #15588

  aveBeta <- CalcAvgByGrp(beta1,meta1)
  idx_N1 <- meta$Sample_Name[grep("N1",meta$ID2)]
  beta1_N1 <-  beta1[,idx_N1]
  meta[idx_N1,"Sample_Group"]
  aveBeta_N1 <- CalcAvgByGrp(beta1_N1,meta1[idx_N1,])
  sum(!Between(aveBeta_N1$ACT, low_cutoff,high_cutoff) & Between(aveBeta_N1$germline, low_cutoff,high_cutoff)) #1399
  #================================================================


  idx_N2 <- meta1$SAMPLE_NAME[grep("N2",meta$ID2)]
  beta1_N2 <-  beta1[,idx_N2]
  meta1[idx_N2,"Sample_Group"]

  aveBeta_N2 <- CalcAvgByGrp(beta1_N2,meta1[idx_N2,])
  idx_snplike_N2 <-  !Between(aveBeta_N2$ACT, low_cutoff,high_cutoff) & Between(aveBeta_N2$germline, low_cutoff,high_cutoff)
  sum(idx_snplike_N2) #1502
  head(aveBeta_N2[idx_snplike_N2,]) 


  #================================================================


  idx_N3 <- meta1$SAMPLE_NAME[grep("N3",meta$ID2)]
  beta1_N3 <-  beta1[,idx_N3]
  meta1[idx_N3,"Sample_Group"]

  aveBeta_N3 <- CalcAvgByGrp(beta1_N3,meta1[idx_N3,])
  idx_snplike_N3 <-  !Between(aveBeta_N3$ACT, low_cutoff,high_cutoff) & Between(aveBeta_N3$germline, low_cutoff,high_cutoff)
  sum(idx_snplike) #1557
  head(aveBeta_N3[idx_snplike_N3,])

  #================================================================
  res2 <- MethylToSNP(
    beta1,
    verbose = FALSE,
    outlier.sd = 3,
    SNP=SNPs.147CommonSingle
  )


}

##################################################################
#  05/14/2025,13:10:37 
##################################################################

RunEnricment <- function(beta, meta, probeset="selected", prefix=NULL, method="singscore",gmtFile=NULL){
  if (!is.null(gmtFile)){
    gmt <-  ReadGmtToList(gmtFile)
    if(!all(c("paternal","maternal")) %in% names(gmt)){
      cat("\nERROR: invalid gmt file. two probesets are resuired: paternal, maternal.\n")
      q("no")
    }
  }else if (!is.null(probeset)) {
      probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
      if (probeset %in% names(probesets)) {
        probes <- probesets[[probeset]]
      } else {
        cat("\nERROR: unavailable probeset & probes not given.\n")
        # q("no")
      }
      if(! "ORIGIN" %in% colnames(probes)){
        cat("\nERROR: ORIGIN unavailable in probeset.\n")
         q("no")
      } 
      gmt <- list(paternal=probes$NAME[probes$ORIGIN %in% "paternal"], 
              maternal=probes$NAME[probes$ORIGIN %in% "maternal"])
  }else{
     cat("\nERROR: neither a probeset or a gmtFile is provided.\n")
     q("no")
  }
  print(lengths(gmt))
  if(tolower(method)=="singscore"){
     library(singscore)  #packageVersion("singscore") #â€˜1.14.0â€™
      rankData <- rankGenes(beta)
      scoredf <- simpleScore(rankData, upSet = gmt[["paternal"]], downSet = gmt[["maternal"]])
      result <- cbind( meta[rownames(scoredf), intersect(c("Sample_Name","Sample_Group","ID2"),colnames(meta))], scoredf)
  }else if(tolower(method) %in% c("gsva","ssgsea")){
      library("GSVA")
      scoredf <- data.frame(t(gsva(as.matrix(beta), gmt,mx.diff=FALSE, method=tolower(method), verbose=FALSE, parallel.sz=1)))
      result <- cbind( meta[rownames(scoredf), intersect(c("Sample_Name","Sample_Group","ID2"),colnames(meta))], scoredf)
  }
  if(!is.null(prefix)){
    outFile <- paste0(prefix,"_score.txt")
    write.table(result, outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
    cat("\n[",basename(outFile),"[saved]")    
  }
  if(tolower(method)=="singscore"){
    return(list(rankData=rankData,scoreMeta=result))
  }else{
    return(result)
  }
}

#================================================================

RunFgsea <- function(beta, gmt, ncores=10, nrow_imputed_norm=10000,nPerm=5000,verbose=TRUE){
  library("parallel")
  RUN_TEST <- function(id,beta, gmt, nPerm ){
    library("fgsea")
    rnk <- beta[,id]
    names(rnk) <- rownames(beta)
    fgseaRes <- fgseaMultilevel(pathways = gmt, 
                    stats = rnk,
                    eps=0,
                    minSize  = 15,
                    maxSize  = 500, nPermSimple = nPerm)
    return(fgseaRes)              
  } 
  beta_imputed <- ImputeImprintedNorm(nrow=nrow_imputed_norm, ncol=ncol(beta))
  colnames(beta_imputed) <- colnames(beta)
  beta <- rbind(beta, beta_imputed) #
  #print(tail(beta,n=3))
  start_time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat("\nINFO: start parallelization [", start_time, "]\n")
  avai_cores <- detectCores() - 1
  if (verbose) {
    outfile <- ""
  } else {
    outfile <- "/dev/null"
  }  
  IDs <- colnames(beta)
  ncores <- min(avai_cores, length(IDs), ncores)
  tryCatch(
      {
      cl <- makeCluster(ncores, outfile = outfile) # silent run
      clusterExport(cl,
        varlist = c("RUN_TEST", "id","beta","gmt","nPerm"),
        envir = environment()
      )
      resultsX <- parLapply(
        cl, IDs,
        function(id) RUN_TEST(id, beta, gmt,nPerm)
      )
      stopCluster(cl)
      },
      error = function(e) print(e)
    )
  stop_time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat("\nINFO: stop parallelization [", stop_time, "]\n")
  # ================================================================
  results <- do.call(rbind, resultsX)
    paternal <- results[results$pathway %in% "paternal", ]
    paternal$pathway <- NULL
    colnames(paternal) <- paste0("pat_",colnames(paternal ))
    maternal <- results[results$pathway %in% "maternal", ]
    maternal$pathway <- NULL
    colnames(maternal) <- paste0("mat_",colnames(maternal ))
    combined <- data.frame(SAMPLE_NAME=IDs, paternal[, c("pat_pval","pat_ES","pat_NES")], maternal[, c("mat_pval","mat_ES","mat_NES")])
    return(combined)    
}
#================================================================

#================================================================

RunPSEA <- function(beta, meta, probeset="selected", prefix=NULL,nrow_imputed_norm=10000, method="singscore",gmtFile=NULL){
  if (!is.null(gmtFile)){
    gmt <-  ReadGmtToList(gmtFile)
    if(!all(c("paternal","maternal")) %in% names(gmt)){
      cat("\nERROR: invalid gmt file. two probesets are resuired: paternal, maternal.\n")
      q("no")
    }
  }else if (!is.null(probeset)) {
      probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
      if (probeset %in% names(probesets)) {
        probes <- probesets[[probeset]]
      } else {
        cat("\nERROR: unavailable probeset & probes not given.\n")
        # q("no")
      }
      if(! "ORIGIN" %in% colnames(probes)){
        cat("\nERROR: ORIGIN unavailable in probeset.\n")
         q("no")
      } 
      gmt <- list(paternal=probes$NAME[probes$ORIGIN %in% "paternal"], 
              maternal=probes$NAME[probes$ORIGIN %in% "maternal"])
  }else{
     cat("\nERROR: neither a probeset or a gmtFile is provided.\n")
     q("no")
  }
  print(lengths(gmt))
  beta_imputed <- ImputeImprintedNorm(nrow=nrow_imputed_norm, ncol=ncol(beta))
  colnames(beta_imputed) <- colnames(beta)
  beta <- rbind(beta, beta_imputed) #
  if(tolower(method)=="singscore"){
     library(singscore)  #packageVersion("singscore") #â€˜1.14.0â€™
      rankData <- rankGenes(beta)
      scoredf <- simpleScore(rankData, upSet = gmt[["paternal"]], downSet = gmt[["maternal"]])
      result <- cbind( meta[rownames(scoredf), intersect(c("Sample_Name","Sample_Group","ID2"),colnames(meta))], scoredf)
  }else if(tolower(method) %in% c("gsva","ssgsea")){
      library("GSVA")
      scoredf <- data.frame(t(gsva(as.matrix(beta), gmt,mx.diff=FALSE, method=tolower(method), verbose=FALSE, parallel.sz=1)))
      result <- cbind( meta[rownames(scoredf), intersect(c("Sample_Name","Sample_Group","ID2"),colnames(meta))], scoredf)
  }
  if(!is.null(prefix)){
    outFile <- paste0(prefix,"_PSEA_score.txt")
    write.table(result, outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
    cat("\n[",basename(outFile),"[saved]")    
  }
  if(tolower(method)=="singscore"){
    return(list(rankData=rankData,scoreMeta=result))
  }else{
    return(result)
  }
}

#================================================================


SampleLevelLOH_STAT <- function(snp_results,status_cols=c("Tumor_Genotype","Normal_Genotype"),method="chisq", group="Mosaic", verbose=F){
  pval1<-ComputeGenotypePvalue(snp_results,status_cols=c("Tumor_Genotype","Normal_Genotype"),method="chisq", group="Mosaic",verbose=verbose)
  pval2<-ComputeGenotypePvalue(snp_results,status_cols=c("Tumor_Genotype","Normal_Genotype"),method="fisher", group="Mosaic",verbose=verbose)
  pval3 <- ComputeGenotypePvalue(snp_results,status_cols=c("Tumor_Genotype","Normal_Genotype"),method="fisher", group="Heterozygous",verbose=verbose)
  if(any(is.na(c(pval1, pval2,pval3)))){
    if(verbose) cat(paste0('\nWARN: invalid method was given.' ))
    return(list(status=NA, p.value=NA))
  }
  het_stat_in_tumor <- sum (snp_results$Tumor_Genotype %in% "Heterozygous") >5
  shift_het2hom_in_tumor <- (sum (snp_results$Normal_Genotype %in% "Heterozygous") - sum (snp_results$Tumor_Genotype %in% "Heterozygous"))>5 &  (sum (snp_results$Tumor_Genotype %in% "Homozygous") - sum (snp_results$Normal_Genotype %in% "Homozygous"))>5
  cat("\nshift_het2hom_in_tumor=",shift_het2hom_in_tumor)
  cat("\npval1=",pval1,", pval2=",pval2,"pval3=",pval3)
  if(pval1 >0.05){
    if(shift_het2hom_in_tumor){
      return(list(status="Mosaic LOH", p.value=pval3))
    }else{
      return(list(status="none", p.value=pval1)) 
    }
   }else if(pval1 <0.05 & pval2 <0.05){
    return(list(status="Mosaic LOH", p.value=pval2))
  }else if(pval1 <0.05 & pval3 <0.05){
    if(het_stat_in_tumor){
      return(list(status="Mosaic LOH", p.value=pval3))
    }else{
      return(list(status="LOH", p.value=pval3))
    }
  }else if(pval1 <0.05){
    return(list(status="genotype shift", p.value=pval1))
  }else{
    return(list(status="unknown", p.value=pval1))
  }
}

#================================================================

UPD_SCORE_FAST <- function(sample, control, probeset = "selected", outPrefix = NULL, ncores = 20, verbose = TRUE) {
  # 01/08/2025, 14:53:09
  library("parallel")
  RUN_TEST <- function(x, sampleSet, controlSet,ctrlGroup) {
    sample1 <- sampleSet[, x]
    cat(sample1,"\n")
    KL <- NULL
    PVAL <- NULL
    cat(paste0("\n processing ", x, " .."))
    for (y in seq(ncol(controlSet))) {
      #cat(y,".")
      sample2 <- controlSet[, y]
      res <- CALC_KL_DIV(sample1, sample2)
      KL <- c(KL, res[["kl_div"]])
      PVAL <- c(PVAL, res[["p.value"]])
    }
    KL_grp <- aggregate(KL ~ ctrlGroup, FUN = mean)
    KL_grp_values <- KL_grp$KL
    names(KL_grp_values) <- KL_grp$ctrlGroup
    PVAL_grp <- aggregate(PVAL ~ ctrlGroup, FUN = mean)
    PVAL_grp_values <- PVAL_grp$PVAL
    names(PVAL_grp_values) <- PVAL_grp$ctrlGroup
    category= names(KL_grp_values)[which.min(KL_grp_values)]
    result <- c(KL_grp_values, PVAL_grp_values, category)
    names(result) <- c(paste(names(KL_grp_values), "_kl.div", sep = ""), paste(names(PVAL_grp_values), "_p.value", sep = ""), "category")
    # print(result)
    return(invisible(result))
  }
  #================================================================
   #skip run if previous scoring result is 
  outFile <- paste0(outPrefix,"_KL_div_test.txt")
  if(file.exists(outFile)){
      result <- read.table(outFile, sep="\t",header=TRUE,fill=TRUE,stringsAsFactors = FALSE, as.is=TRUE,row.names=NULL ,check.names=FALSE ,comment.char = "")
      cat("\n\t", basename(outFile), "[loaded]")
      return(result)
  }

  probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
  # need to be pre-loaded from package.
  beta <- sample[["beta"]]
  meta <- sample[["meta"]]
  if (probeset %in% names(probesets)) {
    probes <- probesets[[probeset]]$NAME
  } else if (is.null(probes)) {
    cat("\nERROR: unavailable probeset & probes not given.\n")
    q("no")
  }
  if (sum(probes %in% rownames(beta)) == 0) {
    cat("\nERROR: invalid beta table .\n")
    q("no")
  }

  controlSet <- control[["beta"]]
  commonProbes <- intersect(intersect(rownames(beta), rownames(controlSet)), probes)
  ctrlGroup <- control[["meta"]]$SAMPLE_GROUP
  controlSet <- controlSet[commonProbes, ]
  sampleSet <- beta[commonProbes, ]

  # controlSet [ controlSet == NA] <- 0.5
  if (any(is.na(controlSet)) | any(is.na(sampleSet))) {
    cat("\nINFO: remove NA from controlSet and sampleSet.")
    controlSet <- na.omit(controlSet)
    sampleSet <- na.omit(sampleSet)
    commonProbes <- intersect(intersect(rownames(sampleSet), rownames(controlSet)), probes)
    controlSet <- controlSet[commonProbes, ]
    sampleSet <- beta[commonProbes, ]
  }

  IDs <- colnames(sampleSet)
  avai_cores <- detectCores() - 1
  ncores <- min(min(avai_cores, length(IDs)), ncores)
  if (verbose) {
    outfile <- ""
  } else {
    outfile <- "/dev/null"
  }
  # ================================================================
  start_time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat("\nINFO: start parallelization [", start_time, "]\n")
  cl <- makeCluster(ncores, outfile = outfile) # silent run
  clusterExport(cl,
    varlist = c("CALC_KL_DIV", "RUN_TEST", "sampleSet", "controlSet","ctrlGroup"),
    envir = environment()
  )
  resultsX <- parLapply(
    cl, IDs,
    function(x) RUN_TEST(x, sampleSet, controlSet,ctrlGroup)
  )
  stop_time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat("\nINFO: stop parallelization [", stop_time, "]\n")
  stopCluster(cl)
  # ================================================================
  results <- do.call(rbind, resultsX)

  #---------------------------------
  results <- data.frame(meta[IDs, c("Sample_Name", "Sample_Group")], results)
  #rownames(result) <- results$SAMPLE_NAME
  # suppressMessages(source("~/bin/scRNAseq/Func_SaveTable.R"))
  # SaveTable(results, sheetName="UPD_KL_DIV",file=outXlsx, rowNames=F, append=T)
  
  write.table(results, outFile, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
  cat("\n\t", basename(outFile), "[saved]")
  #---------------------------------
  return(results)
}

#================================================================


VizNineSquares  <- function(datFile, metaFile, 
  ShapeColumn="imprintome_status", IdColumn='Sample_Name', groupColumn='Sample_Group', ColorColumn="COLOR", 
  X="paternal_median", Y="maternal_median",  xlab="paternal_median", ylab="maternal_median",
  xlims=c(0,1) ,ylims=c(0,1), hlines=c(0.3,0.7), vlines=c(0.3,0.7),  
  
  outFile=NA, label=F, title=NULL,palette="Default",alpha=0.6,dotSize=NULL, ggside="density", splitside="group"){
  # ggside: density or boxplot
  # splitside : group; overall; both; available only if ggside=density.
  library(ggplot2)
  library(ggrepel)
  suppressMessages(suppressWarnings(library(ggside)))
  
  
  options(bitmapType = "cairo")
  #-----------------------------------------------
   if(class(datFile) != "data.frame"){
    if(! file.exists(datFile)){
        cat(paste0('\nERROR: File not found.\n\t',datFile,"\n"))
        q('no')
    }
    dat <- read.table(datFile, sep="\t",header=TRUE,fill=TRUE,stringsAsFactors = FALSE, as.is=TRUE,row.names=NULL ,check.names=FALSE ,comment.char = "")
   }else{
    dat <- datFile
   }
  cat("\ndata dim:",nrow(dat)," rows x",ncol(dat),"cols")
  if(class(metaFile) != "data.frame"){
    if(! file.exists(metaFile)){
        cat(paste0('\nERROR: File not found.\n\t',metaFile,"\n"))
        q('no')
    } 
    meta <- LoadMeta(metaFile) 
    #read.table(metaFile, sep="\t",header=TRUE,fill=TRUE,stringsAsFactors = FALSE, as.is=TRUE,row.names=NULL ,check.names=FALSE ,comment.char = "")
  }else{
    meta <- metaFile
  }  
  meta <- Check_Meta_Color(meta, groupColumn)
  #colnames(meta)<- toupper(colnames(meta))
  cat("\nmeta dim:",nrow(meta)," rows x",ncol(meta),"cols")
  #================================================================
  #================================================================
  myTitle <- title
  #ColorColumn <- toupper(ColorColumn)

  meta$GROUP <- meta[,groupColumn]
  givenColumns <- c(ShapeColumn, IdColumn, groupColumn, X,Y)
  givenColumns <- givenColumns[!is.null(givenColumns)]
  if(! all(givenColumns %in% colnames(dat))){
    cat(paste0('\nERROR: missing any given column(s) in input',paste(givenColumns,collapse=" "),"\n"))
    q('no')
  }


  meta$ID <-  meta[, IdColumn]
  if (ColorColumn != "COLOR" | palette != "default"){
    meta$COLOR <- GetColors(palette=palette,n=length(unique(meta[,ColorColumn])))[as.integer(factor(meta[,ColorColumn],levels=unique(meta[,ColorColumn])))]
    meta[,groupColumn]<- meta[,ColorColumn]
  }

  print(table(meta$COLOR))

  commonIDs <- intersect(dat[, IdColumn],   meta$ID )
  #commonIDs <- commonIDs[!is.na(commonIDs)]

  if(length(commonIDs)==0){
    cat(paste0('\nERROR: meta IDs do not match dat IDs.\n'))
    q('no')
  }else{
    cat(paste0('\nINFO: found ',length(commonIDs),' common IDs between meta and dat.'))
  }
  rownames(meta) <- meta$ID
  rownames(dat) <- dat[, IdColumn]
  meta <- meta[commonIDs,]
  dat <- dat[commonIDs,]

  if( ShapeColumn %in% colnames(dat)){
      cat("\nINFO: ShapeColumn in dat.", ShapeColumn,"\n") 
      meta$SHAPE <- dat[,ShapeColumn]
  }

  #cat("\n", table(meta$COLOR))
  if (is.null(ShapeColumn)){
    meta$SHAPE <- "None"
    meta$SYMBOL <- 21
  }else{
    if( ! ShapeColumn %in% colnames(dat)){
      if( ! ShapeColumn %in% colnames(meta)){
        cat("\nWarn: invalid ShapeColumn.", ShapeColumn,"\n") 
        #print(colnames(meta))
        meta$SHAPE <- "None"
        meta$SYMBOL <- 21
      }else{
        meta$SHAPE <- meta[,ShapeColumn]
      }
    }   
      meta$SHAPE[meta$SHAPE=="" | is.na(meta$SHAPE) ] <- "NA"
      if (length(unique(meta$SHAPE)) <= 5){
        shapes<- c(21,23,24,22,25)  # move to ReadMeta()
      }else{
        shapes<- c(19, 17, 15, 18, 16, 14:0)
      }
      if (all(!is.na(as.numeric(as.character(meta$SHAPE))))){
        meta$SYMBOL <- meta$SHAPE
      }else{
        meta$SYMBOL <- shapes[as.integer(as.factor(meta$SHAPE))]
      }
      #print(meta[, c("SHAPE","SYMBOL")])      
   }
  if(is.null(dotSize)){
    dotSize <- 5-log2(nrow(meta))/2
  }
  dotSize <- ifelse(dotSize<1 , 1, dotSize)
    cat("\nused data dim:",nrow(dat)," rows x",ncol(dat),"cols")
  cat("\nused meta dim:",nrow(meta)," rows x",ncol(meta),"cols")
  usedCol <- intersect(c("ID","GROUP","SYMBOL","COLOR","SHAPE"),colnames(meta))

  if("SHOWLABEL" %in% colnames(meta)){
    DF<- data.frame(meta[,usedCol], X=dat[,X], Y=dat[,Y], SHOWLABEL=meta$SHOWLABEL, stringsAsFactors=FALSE)
  }else{
    DF<- data.frame(meta[,usedCol], X=dat[,X], Y=dat[,Y],  stringsAsFactors=FALSE)
  }

  if ("NEWNAME" %in% colnames(meta)){
    DF <- cbind(DF, INFO=paste(meta$ID, meta$NEWNAME,meta$GROUP, meta$SHAPE,sep="\n"))
  }else{
    DF <- data.frame(DF, INFO=paste(meta$ID, meta$GROUP,meta$SHAPE,sep="\n"))
  } 

  if (length(unique(DF$GROUP)) !=length(unique(DF$COLOR))){ # update color
    for(grp in unique(DF$GROUP)) {
      DF$COLOR[DF$GROUP ==grp] <- head(DF$COLOR[DF$GROUP ==grp],n=1)
    }
  }

  if("SHAPE" %in% colnames(meta)){
    DF<- cbind(DF, SHAPE=meta$SHAPE, SYMBOL=meta$SYMBOL)
    if (length(unique(DF$SHAPE)) <= 5){
      shapes<- c(21,23,24,22,25) 
      fill_manual_status <- TRUE
    }else{
      shapes<- c(19, 17, 15, 18, 16, 14:0)
      fill_manual_status <- FALSE
    }
    uniqCombs <- DF[,c("COLOR","GROUP","SYMBOL","SHAPE")]
    uniqCombs$comb <- paste(DF$COLOR,DF$GROUP,DF$SHAPE,sep="_")
    uniqCombs <- uniqCombs[!duplicated(uniqCombs$comb), c("COLOR","GROUP","SYMBOL","SHAPE")]
    SHAPES <- factor(DF$SHAPE, levels=unique(DF$SHAPE))
  }else{
    #when multiple groups use same color, need to put up all groups.
    uniqCombs <- DF[,c("COLOR","GROUP")]
    uniqCombs$comb <- paste(DF$COLOR,DF$GROUP,sep="_")
    uniqCombs <- uniqCombs[!duplicated(uniqCombs$comb), c("COLOR","GROUP")]
  }

  DF$GROUP <- as.factor(DF$GROUP)
  GROUPS <- factor(DF$GROUP, levels=unique(DF$GROUP))

  #Randomize plotting order because ggplot2 draws order of points by the row order of your data frame.
  DF <- DF[sample(nrow(DF)), ]
  cat("\n")
  print(uniqCombs)
  #mutliple groups may share same shape
  if ("SHAPE" %in% colnames(DF) ){
    if(fill_manual_status){
      pg <- ggplot(DF, aes(x = X, y = Y, fill=GROUP)) +
        xlab(xlab) + ylab(ylab) +
        geom_hline(yintercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.25) +
        geom_vline(xintercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.25) +
        geom_point(size = dotSize,  aes(shape=SHAPES),color="grey50",alpha=alpha)+
        scale_fill_manual(name="Color", values=setNames(uniqCombs$COLOR, uniqCombs$GROUP)) + 
        scale_shape_manual(name="Shape", values = setNames(uniqCombs$SYMBOL,uniqCombs$SHAPE))+
        guides(fill=guide_legend(override.aes=list(shape=21))) + 
        theme_bw() + theme_classic(base_size = 10) + theme(aspect.ratio=1)+
        theme(panel.border = element_rect(colour = "grey10", fill=NA, linewidth=1.5)) +
        theme(
          legend.text = element_text(size = 7),
          legend.title = element_text(size = 8, colour = "grey10", face = "bold"),
          plot.title = element_text(size = 10),
          axis.title = element_text(size = 10),
          axis.text.x = element_text(size = 10, color = "grey10"),
          axis.text.y = element_text(size = 10, color = "grey10"),
          plot.margin = unit(c(0.5, 0.5, 0.5, 0.5), "cm")
        ) +
        ggtitle(myTitle)
    }else{
        pg <- ggplot(DF, aes(x = X, y = Y,color=GROUP)) +
         xlab(xlab) + ylab(ylab) +
        geom_hline(yintercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.25) +
        geom_vline(xintercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.25) +
        geom_point(size = dotSize,  aes(shape=SHAPES),alpha=alpha)+ 
        scale_color_manual(name="Color", values=setNames(uniqCombs$COLOR, uniqCombs$GROUP)) + 
        guides(color=guide_legend(override.aes=list(shape=21))) + 
        theme_bw() + theme_classic(base_size = 10) + theme(aspect.ratio=1)+
        theme(panel.border = element_rect(colour = "grey10", fill=NA, linewidth=1.5)) +
        theme(
          legend.text = element_text(size = 7),
          legend.title = element_text(size = 8, colour = "grey10", face = "bold"),
          plot.title = element_text(size = 10),
          axis.title = element_text(size = 10),
          axis.text.x = element_text(size = 10, color = "grey10"),
          axis.text.y = element_text(size = 10, color = "grey10"),
          plot.margin = unit(c(0.5, 0.5, 0.5, 0.5), "cm")
        ) +
        ggtitle(myTitle)

    }
  }else{
    pg <- ggplot(DF, aes(x = X, y = Y, fill=GROUP),color=GROUP) +
      xlab(xlab) + ylab(ylab) +
      geom_hline(yintercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.25) +
      geom_vline(xintercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.25) +
      geom_point(size = dotSize, lwd = 2, alpha=0.6,shape=21) + 
      scale_fill_manual(name="Color", values=setNames(uniqCombs$COLOR, uniqCombs$GROUP)) +
      scale_shape_manual(name="Shape", values = setNames(uniqCombs$SYMBOL,uniqCombs$SHAPE))+ 
      theme_bw() + theme_classic(base_size = 10) + theme(aspect.ratio=1)+
      theme(panel.border = element_rect(colour = "grey20", fill = NA, linewidth = 1.5)) +
      theme(
        legend.text = element_text(size = 7),
        legend.title = element_text(size = 8, colour = "grey10", face = "bold"),
        plot.title = element_text(size = 10),
        axis.title = element_text(size = 10),
        axis.text.x = element_text(size = 10, color = "grey10"),
        axis.text.y = element_text(size = 10, color = "grey10"),
        plot.margin = unit(c(0.5, 0.5, 0.5, 0.5), "cm")
      ) +
      ggtitle(label=myTitle)
  }
  if(!is.null(xlims)){
    #xlims <-  as.numeric(unlist(strsplit(xlims, ",")))
    pg <- pg + xlim(xlims) # xlim(xlims[1],xlims[2])
  }
  if(!is.null(ylims)){
    #ylims <-  as.numeric(unlist(strsplit(ylims, ",")))
    pg <- pg + ylim(ylims) #ylim(ylims[1],ylims[2])
  }
  if (!is.null(vlines)){
    # vline <- as.numeric(unlist(strsplit(vline, ",")))
    pg <- pg + geom_vline(xintercept=vlines,linetype=3)
  }
  if (!is.null(hlines)){
    # hline <- as.numeric(unlist(strsplit(hline, ",")))
    pg <- pg + geom_hline(yintercept=hlines,linetype=3)
  }
  adj <- 0
   if(ggside=="density"){
    if(splitside=="both"){
      cat(paste0('\nINFO: density - both'))
       pg <- pg + 
            geom_xsidedensity(aes(x = X, color = GROUP, fill=NULL), show.legend = FALSE, alpha=0.1) +
            geom_xsidedensity(aes(x = X), inherit.aes = FALSE, fill =  "grey40", alpha = 0.5,color ="grey40", linetype = "solid", linewidth = 1.5) +
            geom_ysidedensity(aes(y = Y, color = GROUP, fill=NULL), show.legend = FALSE, alpha=0.1) +
            geom_ysidedensity(aes(y = Y), inherit.aes = FALSE, fill =  "grey40", alpha = 0.5,color ="grey40",  linetype = "solid", linewidth = 1.5) +
            theme_classic(base_size = 10) + 
            theme(panel.border = element_rect(color = "grey30", fill = NA, linewidth = 1))+ 
            theme(  ggside.panel.scale = 0.2 )
    }else if(splitside=="overall"){
        cat(paste0('\nINFO: density - overall'))
       pg <- pg + 
            geom_xsidedensity(aes(x = X), inherit.aes = FALSE, fill =  "grey40", alpha = 0.5,color ="grey40", linetype = "solid", linewidth = 1.5) +
            geom_ysidedensity(aes(y = Y), inherit.aes = FALSE, fill =  "grey40", alpha = 0.5,color ="grey40",  linetype = "solid", linewidth = 1.5) +
            theme_classic(base_size = 10) + 
            theme(panel.border = element_rect(color = "grey30", fill = NA, linewidth = 1))+ 
            theme(  ggside.panel.scale = 0.2 )
    }else if(splitside=="group") { # groupwise
      cat(paste0('\nINFO: density - group'))
       pg <- pg + 
            geom_xsidedensity(aes(x = X, color = GROUP, fill=NULL), show.legend = FALSE, alpha=0.1) +
            geom_ysidedensity(aes(y = Y, color = GROUP, fill=NULL), show.legend = FALSE, alpha=0.1) +
            theme_classic(base_size = 10) + 
            theme(panel.border = element_rect(color = "grey30", fill = NA, linewidth = 1))+ 
            theme(  ggside.panel.scale = 0.2 )
    }
      adj <- 2
   }else if(ggside=="boxplot"){
            pg <- pg + 
              geom_xsideboxplot(aes(color= GROUP, y =Y),width = 0.5, orientation = "y",outlier.shape = NA, show.legend = FALSE,  alpha=0.3)+
              theme( ggside.axis.text.x = element_text(angle = 90, hjust = 1))+
              geom_ysideboxplot(aes(color= GROUP, x =X),width = 0.5, orientation = "x",outlier.shape = NA, show.legend = FALSE,  alpha=0.3)+
              theme(panel.border = element_rect(color = "grey30", fill = NA, linewidth = 1))+
              theme(  ggside.panel.scale = 0.2 ) 

   }
  if("SHOWLABEL" %in% colnames(DF)){
    pg1 <- pg + ggrepel::geom_text_repel(data = DF[nchar(DF$SHOWLABEL)>0, ], aes(label = SHOWLABEL), size = 3, froce=5, nudge_y=0.05, segment.color="grey20",segment.size=0.5,min.segment.length=0)#
  }else{
    if (label){
      pg1 <- pg + geom_text(data = DF, aes(x = X, y = Y, label =ID),   hjust = 0, nudge_x = 0.2, size=2.5)
    }else{
      pg1 <- pg
    }
  }
  if (! is.na(outFile)){
    if (nrow(meta) <= 20 ){
        if (label){
          pg2 <- pg + geom_text_repel(aes(label=ID),size = 2.5)
        }else{
          pg2 <- pg
        } 
    }else{
      pg2 <- pg 
    }
    adj <- adj + ifelse(length(levels(GROUPS))>16,2,0) + ifelse(length(levels(SHAPES))>10,2,0) # in case there are many legend labels
    ggsave(file = outFile, pg2, width = 7+adj, height = 6+adj, units = "in")
    cat("\n\t", basename(outFile),"[saved]")
  }
  return(pg1)
}


##################################################################
#  01/20/2026,11:43:06 
##################################################################

VizNineSquaresChr11 <- function(datFile, metaFile, outFile=NA,title="chr11.p15 classifier",ggside="density", splitside="group"){
tmp <- VizNineSquares(datFile, metaFile, 
  ShapeColumn="chr11p15", IdColumn='Sample_Name', groupColumn='Sample_Group', ColorColumn="COLOR",
  X="X", Y="Y",  xlab="IC1_mean", ylab="IC2_mean",
  xlims=c(0,1) ,ylims=c(0,1), hlines=c(0.3,0.7), vlines=c(0.3,0.7),  
  outFile=outFile, label=F, title=title,palette="Default",alpha=0.6,dotSize=NULL, ggside="density", splitside="group")

}




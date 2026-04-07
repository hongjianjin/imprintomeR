# Auto-refactored from utilities2.R
# Module: probeset

AnnotateProbe2Gene <- function(probeIDs, probes.all = NULL, assay = "EPICV1", version = "HG19", verbose = FALSE, file = NULL) {
  if (is.null(probes.all)) {
    probes.all <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/anno.uniq_harmonized.liftover.rds")
  }
  chr <- paste0("CHR_", toupper(version))
  mapinfo <- paste0("MAPINFO_", toupper(version))
  res <- probes.all[probes.all$NAME %in% probeIDs, c("NAME", chr, mapinfo, "UCSC_REFGENE_NAME", "UCSC_REFGENE_GROUP")]
  if (!is.null(file)) {
    # file <- paste0(prefix, ".annotatedBy", assayType, "_cytoband.", cytoband.used, "_na.txt")
    write.table(res, file, sep = "\t", quote = F, row.names = F, col.names = T)
    cat("\n\t", basename(file), "[saved,nrow=", nrow(res), "]")
  }
  return(res)
}
# ================================================================

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

ExtractProbesByGenelist <- function(genes = NULL, probes.all = NULL, assay = "EPICV1", version = "HG19", promoterOnly = FALSE, file = NULL) {
  if (is.null(probes.all)) {
    probes.all <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/anno.uniq_harmonized.liftover.rds")
  }
  if (promoterOnly) {
    idx <- grepl("TSS200", probes.all$UCSC_REFGENE_GROUP)
    cat("\nUse TSS200 only probes..[n=", sum(idx), "]")
    probes.all <- probes.all[idx, ]
  }
  if (is.null(genes)) {
    cat("\nERROR: must provide a gene list as vector .\n")
    q("no")
  }
  chr <- paste0("CHR_", toupper(version))
  mapinfo <- paste0("MAPINFO_", toupper(version))
  res <- probes.all[probes.all$UCSC_REFGENE_NAME %in% genes, c("NAME", chr, mapinfo, "UCSC_REFGENE_NAME", "UCSC_REFGENE_GROUP")]
  if (!is.null(file)) {
    write.table(res, file, sep = "\t", quote = F, row.names = F, col.names = T)
    cat("\n\t", basename(file), "[saved]")
  }
  return(res)
}

# ================================================================

ExtractProbesByBeds <- function(bed = NULL, probes.all = NULL, assay = NULL, version = "HG19", verbose = FALSE, file = NULL) {
  # assay:  450K,EPICV10b5,EPICV2; NULL- no filtering by assay
  library("bedr")
  if (!check.binary("bedtools")) {
    cat("\nERROR: bedtools not available.\n")
    return(NULL)
  }
  if (is.null(probes.all)) {
    probes.all <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/anno.uniq_harmonized.liftover.rds")
  }
  if (!is.null(assay)){
    probes.all <- probes.all[grep(assay, probes.all$assay,ignore.case=T),]
  }
  chr <- paste0("CHR_", toupper(version))
  mapinfo <- paste0("MAPINFO_", toupper(version))
  if (!all(grepl("chr", probes.all[[chr]][1:1000]))) {
    probes.all[[chr]] <- paste("chr", gsub("chr", "", probes.all[[chr]]), sep = "")
  }
  anno_bed <- paste(probes.all[[chr]], ":", probes.all[[mapinfo]], "-", probes.all[[mapinfo]] + 1, sep = "")
  x <- is.valid.region(anno_bed, verbose = verbose)
  if (sum(x) < 400000) {
    cat("\nERROR: invalid reference bed regions.\n")
    return(NULL)
  }
  anno_bed_used <- bedr.sort.region(anno_bed[x], verbose = verbose)
  cat("\nINFO: valid reference bed regions:", sum(x))
  y <- is.valid.region(bed, verbose = verbose)
  if (sum(y) == 1) {
    cat("\nINFO: only 1 input bed region.")
    input_bed_used <- bed
  } else if (sum(y) > 1) {
    cat("\nINFO: valid input bed regions:", sum(y))
    input_bed_used <- bedr.sort.region(bed[y], verbose = verbose)
  } else {
    cat("\nERROR: invalid input bed regions.\n")
    return(NULL)
  }
  cat("\n")
  is.region <- in.region(anno_bed_used, input_bed_used)
  found.region <- anno_bed_used[is.region]
  idx <- match(found.region, anno_bed)
  mapinfo <- paste0("MAPINFO_", toupper(version))
  used_cols <- intersect(c("TargetID", "NAME", chr, mapinfo ,"UCSC_REFGENE_NAME"), colnames(probes.all))
  res <- probes.all[idx, used_cols]
  rownames(res) <- res$NAME
  if (!is.null(file)) {
    write.table(res, file, sep = "\t", quote = F, row.names = F, col.names = T)
    cat("\n\t", basename(file), "[saved, nrow=", dim(res), "]\n")
  }
  epic_bed<- data.frame(chr=probes.all[[chr]], start=probes.all[[mapinfo]],  end=probes.all[[mapinfo]] + 1, NAME=probes.all[["NAME"]])
  idx_valid <- is.valid.region(epic_bed, verbose = verbose)
  epic_bed <- epic_bed[idx_valid,]
  epic_probes_sorted <- bedr.sort.region(epic_bed)
  
  regions_bed <- bed2[,1:3]
  idx_valid <- is.valid.region(regions_bed, verbose = verbose)
  regions_bed <- regions_bed[idx_valid,]
  regions_bed_sorted <- bedr.sort.region(regions_bed)
   
  matched_probes <- bedr.join.region(
    epic_bed,  # EPIC probes as input A
    regions_bed[,1:3],     # BED regions as input B
    report.n.overlap = TRUE,     # Include overlap size
    check.chr = FALSE      # Skip chr prefix check if consistent
  )

  return(res)
}

# ================================================================

ExtractProbesByBeds2 <- function(bedFile = NULL, probes.all = NULL, assay = NULL, version = "HG19", verbose = FALSE, file = NULL) {
  # assay:  450K,EPICV10b5,EPICV2; NULL- no filtering by assay
  library("bedr")
  if (!check.binary("bedtools")) {
    cat("\nERROR: bedtools not available.\n")
    return(NULL)
  }
  if (is.null(probes.all)) {
    probes.all <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/anno.uniq_harmonized.liftover.rds")
  }
  if (!is.null(assay)){
    probes.all <- probes.all[grep(assay, probes.all$assay,ignore.case=T),]
  }
  chr <- paste0("CHR_", toupper(version))
  mapinfo <- paste0("MAPINFO_", toupper(version))
  if (!all(grepl("chr", probes.all[[chr]][1:1000]))) {
    probes.all[[chr]] <- paste("chr", gsub("chr", "", probes.all[[chr]]), sep = "")
  }
  epic_bed<- data.frame(chr=probes.all[[chr]], start=probes.all[[mapinfo]],  end=probes.all[[mapinfo]] + 1, NAME=probes.all[["NAME"]])
  epic_bed <- na.omit(epic_bed)
  idx_valid1 <- is.valid.region(epic_bed, verbose = verbose)
  table(idx_valid1)
  if (sum(idx_valid1) < 400000) {
    cat("\nERROR: invalid reference bed regions.\n")
    return(NULL)
  }
  epic_bed_valid<- epic_bed[idx_valid1,]
  epic_probes_sorted <- bedr.sort.region(epic_bed_valid)
  cat("\nINFO: valid reference bed regions:", sum(idx_valid1))
  #================================================================
  input <- ParseBedFile2(bedFile)
  regions_bed <- input[["bed"]]
  anno <- input[["anno"]]
  #================================================================
  idx_valid2 <- is.valid.region(regions_bed, verbose = verbose)
  if (sum(idx_valid2) == 1) {
    cat("\nINFO: only 1 input bed region.")
    regions_bed_sorted <- regions_bed[idx_valid2,]
  } else if (sum(idx_valid2) > 1) {
    cat("\nINFO: valid input bed regions:", sum(idx_valid2))
    regions_bed_sorted <- bedr.sort.region(regions_bed[idx_valid2,], verbose = verbose)
  } else {
    cat("\nERROR: invalid input bed regions.\n")
    return(NULL)
  }

  matched_probes <- bedr.join.region(
    epic_probes_sorted,  # EPIC probes as input A
    regions_bed_sorted,     # BED regions as input B
    report.n.overlap = TRUE,     # Include overlap size
    check.chr = FALSE      # Skip chr prefix check if consistent
  )
  colnames(matched_probes) <- c(
    "CHR", "MAPINFO", "probe_end",         # EPIC probe coordinates
    "NAME","region_chr", "region_start", "region_end",      # BED region coordinates
     "overlap_size"                      # Annotation and overlap info
  )
  matched_probes$region <- paste0(matched_probes$region_chr,":",matched_probes$region_start,"-",matched_probes$region_end)
  matched_probes$Closest_TSS_gene_name <- probes.all[matched_probes$NAME, "UCSC_REFGENE_NAME"]
  res <- matched_probes[,c( "NAME","CHR", "MAPINFO","Closest_TSS_gene_name","region")]
  if(!is.null(anno)){
    res <- cbind(res, anno[matched_probes$region,])
  }
  if (!is.null(file)) {
    write.table(res, file, sep = "\t", quote = F, row.names = F, col.names = T)
    cat("\n\t", basename(file), "[saved, nrow=", dim(res), "]\n")
  }
  return(res)
}


##################################################################

SubsetBeta_By_Probeset <- function(beta, probeset=probeset_options, prefix=NULL){
  beta_subset <- beta
  probesets <- NULL
  #print(probeset)
  if (!is.null(probeset)) {
    probeset <- match.arg(probeset)
    probesets_all <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
    if (probeset %in% names(probesets_all)){# c("chr11p15", "Jima", "Joshi", "NanoImprint","zambegrp", "all", "selected")) {
      probesets <- probesets_all[[probeset]]
      rownames(probesets) <- probesets$NAME
      cat("\n\t[SubsetBeta] subset by probeset [query:", length(probesets$NAME))
    } else if (probeset %in% probeset_chrs ){  
      cat(paste0("\n [SubsetBeta] subset probeset 'classifier3' by ",probeset,""))
      probesets <- probesets_all[["classifier3"]]
      probesets <- probesets[probesets$CHR %in% probeset,]
    } else{
      cat("\n [SubsetBeta] ERROR:invalid probeset.")
      q("no")   
    } 
    if(nrow(probesets)==0){
      cat("\n [SubsetBeta] ERROR:invalid probeset. Return 0 matched probe.")
      q("no")      
    }
      probes <- intersect(rownames(beta), probesets$NAME)
          probesets <- probesets[probes, ]
      if(ncol(beta)==1){
        beta_subset <- data.frame(beta[probes, ])
        rownames(beta_subset) <- probes
        colnames(beta_subset) <- colnames(beta)
      }else{
        beta_subset <- beta[probes, ]
      }
      #print(dim(beta_subset))
      cat("; matched probes:", nrow(beta_subset), "]\n")
      if(! is.null(prefix)){
        outFile <- paste0(prefix,"_subset_by_",probeset,"_beta.txt")
        if(file.exists(outFile)){
          cat("\nInfo: found previous subsetBeta file. skip.\n")
        }else{
          write.table(cbind(TargetID=rownames(beta_subset),beta_subset), outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
          cat("\n\t",basename(outFile),"[saved]")          
        }
      }

  } else {
    # cat("\n [SubsetBeta] NULL probeset. [skipped]")
    probesets <- NULL
  }
  #print(head(beta_subset))
  return(list(beta=beta_subset, probesets=probesets) )   
}
#================================================================

#================================================================

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



#================================================================
Beeplot_chr_vs_other <- function (dat, meta,group.by="chr",color.by="CATEGORY", outFile=NULL, verbose=FALSE){
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
  imgHeight <- 6
  imgWidth <- 4
  samples <- intersect(colnames(dat),meta$SAMPLE_NAME)
  pdf(outFile, width = imgWidth, height = imgHeight)
  plots <- list()
  for (sample in samples) {
    if(verbose){
        cat("\n\t", sample)
    }
    sample_data <- data.frame(value=dat[,sample], GROUP=dat[,group.by], CATEGORY =dat[,color.by])
    pg <- ggplot(sample_data, aes(x = 1, y = value,color=CATEGORY), alpha = 1) +
      geom_quasirandom(cex = 1) +
      facet_wrap(~ GROUP, nrow = 1) +  theme_classic(base_size = 10) + 
      labs(y = "methylation level", x = "GROUP") + ylim(0, 1)+
      geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey40",linewidth = 0.5) +
      geom_hline(yintercept = c(0.3,0.7), linetype ="dotted", color = "grey60",linewidth = 0.5) +
      theme(axis.text.x = element_blank(),axis.ticks.x = element_blank(),
      panel.border = element_rect(color = "grey20", fill = NA, linewidth = 0.5)) 
    if("ID2" %in% colnames(meta)){
        sTitle <- meta[meta$SAMPLE_NAME == sample, "ID2"]
        if(sTitle != sample){
          pg <- pg+ ggtitle(label = sample,subtitle=sTitle)
        }else{
           pg <- pg+ ggtitle(label = sample) 
        }
    }else{
        pg <- pg+ ggtitle(label = sample) 
    }      
    print(pg)
 }
 garbage <- dev.off()
 cat("\n\t", basename(outFile), "[saved]")
}

#----------------------------------------------------------------

Beeplot_chr_vs_other_single <- function (input, chrs="chr1,chr11", prefix=NULL,probeset="classifier2"){
     #
    probeset_name <- probeset
    probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
    probeset <- probesets[[probeset_name]] 
    if("ORIGIN" %in% colnames(probeset)){
       anno <- probeset[,c("CHR","MAPINFO","Closest_TSS_gene_name","ORIGIN")]    
       rownames(anno) <- probeset$NAME
       colnames(anno)[3:4] <- c("GENE","CATEGORY")
     }else{
            cat("\nError: ORIGIN column is missing in your probeset.\n")
            q("no")
     }
    beta <- input[["beta"]]
    meta <- input[["meta"]]    
    chrs <- unlist(strsplit(chrs,","))
    for (chr in chrs){   
        cat("\n\t", chr)
        common_probes <- intersect(probeset$NAME, rownames(beta))
        probeset <- probeset[probeset$NAME %in% common_probes, ]
        beta <- beta[common_probes,]
        probes_chr <- probeset$NAME[probeset$CHR %in% c(chr, gsub("chr","", chr))]
        probes_chr_others <- probeset$NAME[! probeset$CHR %in% c(chr, gsub("chr","", chr))]
        beta_chr <- beta[probes_chr, ]
        beta_chr_others <- beta[probes_chr_others, ]
        melt_df <- rbind(cbind(beta_chr,chr=chr), cbind(beta_chr_others, chr="others"))
        melt_df$CATEGORY <-    anno[rownames(melt_df),"CATEGORY"]
        Beeplot_chr_vs_other(melt_df, meta,group.by="chr",color.by="CATEGORY", outFile=paste0(prefix,"_beeplot_",chr,".pdf"))
    }

}
#================================================================

##################################################################
#  09/11/2025,10:36:15 
##################################################################

standardize_array <- function(input) {
  # Convert to uppercase for comparison
  clean_input <- toupper(input)
  dplyr::case_when(
    clean_input %in% c("450K", "450") ~ "450K",
    clean_input %in% c("EPIC", "EPICV1","EPICV10B5", "V1") ~ "EPICv1",
    clean_input %in% c("EPICV2", "V2") ~ "EPICv2",
    TRUE ~ "Unknown"
  )
}

#================================================================

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


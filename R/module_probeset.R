# Auto-refactored from utilities2.R
# Module: probeset

#' @export
AnnotateProbe2Gene <- function(probeIDs, probes.all = NULL, assay = "EPICV1", version = "HG19", verbose = FALSE, file = NULL) {
  if (is.null(probes.all)) {
    probes.all <- readRDS(.resolve_extdata_file("anno.uniq_harmonized.liftover.rds"))
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

#' @export
ExtractProbesByGenelist <- function(genes = NULL, probes.all = NULL, assay = "EPICV1", version = "HG19", promoterOnly = FALSE, file = NULL) {
  if (is.null(probes.all)) {
    probes.all <- readRDS(.resolve_extdata_file("anno.uniq_harmonized.liftover.rds"))
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

#' Extract Probes Overlapping Input BED Region(s)
#'
#' Unified implementation for probe extraction from either in-memory BED
#' coordinates (`bed`) or BED file input (`bedFile`). This harmonizes legacy
#' `ExtractProbesByBeds()` and `ExtractProbesByBeds2()` behavior.
#'
#' @param bed Character vector of BED regions (`chr:start-end`) or a 3-column
#'   BED-like data frame. Used when `bedFile` is `NULL`.
#' @param bedFile Optional BED file path. When provided, this mode is used.
#' @param probes.all Optional annotation table. If `NULL`, loads
#'   `inst/extdata/anno.uniq_harmonized.liftover.rds`.
#' @param assay Optional assay filter.
#' @param version Genome build label (`"HG19"` or `"HG38"`) used to select
#'   annotation columns.
#' @param verbose Logical passed to `bedr` helpers.
#' @param file Optional output path for writing tab-delimited results.
#'
#' @return Data frame of matched probes. In `bedFile` mode, returns region-aware
#'   output compatible with legacy `ExtractProbesByBeds2()`.
#' @export
ExtractProbesByBeds <- function(bed = NULL, bedFile = NULL, probes.all = NULL, assay = NULL,
                                version = "HG19", verbose = FALSE, file = NULL) {
  library("bedr")
  if (!check.binary("bedtools")) {
    cat("\nERROR: bedtools not available.\n")
    return(NULL)
  }

  if (is.null(probes.all)) {
    probes.all <- readRDS(.resolve_extdata_file("anno.uniq_harmonized.liftover.rds"))
  }

  if (!is.null(assay)) {
    assay_col <- intersect(c("ASSAY", "assay"), colnames(probes.all))[1]
    if (!is.na(assay_col) && !is.null(assay_col)) {
      probes.all <- probes.all[grep(assay, probes.all[[assay_col]], ignore.case = TRUE), ]
    }
  }

  chr <- paste0("CHR_", toupper(version))
  mapinfo <- paste0("MAPINFO_", toupper(version))
  if (!all(c(chr, mapinfo, "NAME") %in% colnames(probes.all))) {
    cat("\nERROR: required annotation columns are missing in probes.all.\n")
    return(NULL)
  }

  probes.all[[chr]] <- paste0("chr", gsub("^chr", "", probes.all[[chr]]))
  epic_bed <- data.frame(
    chr = probes.all[[chr]],
    start = probes.all[[mapinfo]],
    end = probes.all[[mapinfo]] + 1,
    NAME = probes.all[["NAME"]],
    stringsAsFactors = FALSE
  )
  epic_bed <- na.omit(epic_bed)

  epic_regions <- paste(epic_bed$chr, ":", epic_bed$start, "-", epic_bed$end, sep = "")
  idx_valid_probe <- is.valid.region(epic_regions, verbose = verbose)
  if (sum(idx_valid_probe) < 1) {
    cat("\nERROR: invalid reference bed regions.\n")
    return(NULL)
  }
  epic_bed_valid <- epic_bed[idx_valid_probe, , drop = FALSE]
  epic_regions_valid <- epic_regions[idx_valid_probe]
  cat("\nINFO: valid reference bed regions:", sum(idx_valid_probe))

  if (!is.null(bedFile)) {
    input <- ParseBedFile2(bedFile)
    regions_bed <- input[["bed"]]
    anno <- input[["anno"]]

    idx_valid2 <- is.valid.region(regions_bed, verbose = verbose)
    if (sum(idx_valid2) == 0) {
      cat("\nERROR: invalid input bed regions.\n")
      return(NULL)
    }
    regions_bed_valid <- regions_bed[idx_valid2, , drop = FALSE]
    regions_bed_sorted <- bedr.sort.region(regions_bed_valid[, 1:3], verbose = verbose)

    matched_probes <- bedr.join.region(
      epic_bed_valid,
      regions_bed_sorted,
      report.n.overlap = TRUE,
      check.chr = FALSE
    )
    colnames(matched_probes) <- c(
      "CHR", "MAPINFO", "probe_end",
      "NAME", "region_chr", "region_start", "region_end",
      "overlap_size"
    )
    matched_probes$region <- paste0(matched_probes$region_chr, ":", matched_probes$region_start, "-", matched_probes$region_end)
    gene_col <- intersect(c("UCSC_REFGENE_NAME", "Closest_TSS_gene_name"), colnames(probes.all))[1]
    if (!is.na(gene_col) && !is.null(gene_col)) {
      matched_probes$Closest_TSS_gene_name <- probes.all[match(matched_probes$NAME, probes.all$NAME), gene_col]
    } else {
      matched_probes$Closest_TSS_gene_name <- NA_character_
    }
    res <- matched_probes[, c("NAME", "CHR", "MAPINFO", "Closest_TSS_gene_name", "region")]
    if (!is.null(anno)) {
      res <- cbind(res, anno[match(res$region, rownames(anno)), , drop = FALSE])
    }
  } else {
    if (is.null(bed)) {
      cat("\nERROR: provide either bed or bedFile.\n")
      return(NULL)
    }

    if (is.data.frame(bed)) {
      input_regions <- paste(bed[, 1], ":", bed[, 2], "-", bed[, 3], sep = "")
    } else {
      input_regions <- as.character(bed)
    }

    idx_valid_input <- is.valid.region(input_regions, verbose = verbose)
    if (sum(idx_valid_input) == 0) {
      cat("\nERROR: invalid input bed regions.\n")
      return(NULL)
    }
    input_regions_used <- bedr.sort.region(input_regions[idx_valid_input], verbose = verbose)

    is_region <- in.region(epic_regions_valid, input_regions_used)
    found_region <- epic_regions_valid[is_region]
    idx <- match(found_region, epic_regions)
    used_cols <- intersect(c("TargetID", "NAME", chr, mapinfo, "UCSC_REFGENE_NAME"), colnames(probes.all))
    res <- probes.all[idx, used_cols, drop = FALSE]
    if ("NAME" %in% colnames(res)) {
      rownames(res) <- res$NAME
    }
  }

  if (!is.null(file)) {
    write.table(res, file, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
    cat("\n\t", basename(file), "[saved, nrow=", nrow(res), "]\n")
  }
  return(res)
}

# ================================================================

##################################################################

#' @export
SubsetBeta_By_Probeset <- function(beta, probeset=probeset_options, prefix=NULL){
  beta_subset <- beta
  probesets <- NULL
  #print(probeset)
  if (!is.null(probeset)) {
    probeset <- match.arg(probeset)
    probesets_all <- readRDS(.resolve_extdata_file("probesets_hg19.rds"))
    if (probeset %in% names(probesets_all)){# c("chr11p15", "Jima", "Joshi", "NanoImprint","zambegrp", "all", "selected")) {
      probesets <- probesets_all[[probeset]]
      rownames(probesets) <- probesets$NAME
      cat("\n\t[SubsetBeta] subset by probeset [query:", length(probesets$NAME))
    } else if (probeset %in% probeset_chrs ){  
      cat(paste0("\n [SubsetBeta] subset probeset 'selected' by ",probeset,""))
      probesets <- probesets_all[["selected"]]
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

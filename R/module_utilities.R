# Auto-refactored from utilities2.R
# Module: utilities

standardColors <- function() {
  colors <- c(
    "turquoise", "blue", "brown", "green", "red", "black", "pink", "magenta", "purple", "greenyellow", "tan", "salmon", "cyan", "midnightblue", "lightcyan",
    "grey60", "lightgreen", "lightyellow", "royalblue", "darkred", "darkgreen", "darkturquoise", "darkgrey", "orange", "darkorange", "white", "skyblue",
    "saddlebrown", "steelblue", "paleturquoise", "violet", "darkolivegreen", "darkmagenta", "sienna3", "yellowgreen", "skyblue3", "plum1", "orangered4", "mediumpurple3",
    "lightsteelblue1", "lightcyan1", "ivory", "floralwhite", "darkorange2", "brown4", "bisque4", "darkslateblue", "plum2", "thistle2", "thistle1", "salmon4",
    "palevioletred3", "navajowhite2", "maroon", "lightpink4", "lavenderblush3", "honeydew1", "darkseagreen4", "coral1", "antiquewhite4", "coral2", "mediumorchid", "skyblue2",
    "yellow4", "skyblue1", "plum", "orangered3", "mediumpurple2", "lightsteelblue", "lightcoral", "indianred4", "firebrick4", "darkolivegreen4", "brown2", "blue2",
    "darkviolet", "plum3", "thistle3", "thistle", "salmon2", "palevioletred2", "navajowhite1", "magenta4", "lightpink3", "lavenderblush2", "honeydew", "darkseagreen3",
    "coral", "antiquewhite2", "coral3", "mediumpurple4", "skyblue4", "yellow3", "sienna4", "pink4", "orangered1", "mediumpurple1", "lightslateblue", "lightblue4",
    "indianred3", "firebrick3", "darkolivegreen2", "blueviolet", "blue4", "deeppink", "plum4", "thistle4", "tan4", "salmon1", "palevioletred1", "navajowhite",
    "magenta3", "lightpink2", "lavenderblush1", "green4", "darkseagreen2", "chocolate4", "antiquewhite1", "coral4", "mistyrose", "slateblue", "yellow2", "sienna2",
    "pink3", "orangered", "mediumpurple", "lightskyblue4", "lightblue3", "indianred2", "firebrick2", "darkolivegreen1", "blue3", "brown1", "deeppink1", "powderblue",
    "tomato", "tan3", "royalblue3", "palevioletred", "moccasin", "magenta2", "lightpink1", "lavenderblush", "green3", "darkseagreen1", "chocolate3", "aliceblue",
    "cornflowerblue", "navajowhite3", "slateblue1", "whitesmoke", "sienna1", "pink2", "orange4", "mediumorchid4", "lightskyblue3", "lightblue2", "indianred1", "firebrick",
    "darkgoldenrod4", "blue1", "brown3", "deeppink2", "purple2", "tomato2", "tan2", "royalblue2", "paleturquoise4", "mistyrose4", "magenta1", "lightpink",
    "lavender", "green2", "darkseagreen", "chocolate2", "antiquewhite", "cornsilk", "navajowhite4", "slateblue2", "wheat3", "sienna", "pink1", "orange3",
    "mediumorchid3", "lightskyblue2", "lightblue1", "indianred", "dodgerblue4", "darkgoldenrod3", "blanchedalmond", "burlywood", "deepskyblue", "red1", "tomato4", "tan1",
    "rosybrown4", "paleturquoise3", "mistyrose3", "linen", "lightgoldenrodyellow", "khaki4", "green1", "darksalmon", "chocolate1", "antiquewhite3", "cornsilk2", "oldlace",
    "slateblue3", "wheat1", "seashell4", "peru", "orange2", "mediumorchid2", "lightskyblue1", "lightblue", "hotpink4", "dodgerblue3", "darkgoldenrod1", "bisque3",
    "burlywood1", "deepskyblue4", "red4", "turquoise2", "steelblue4", "rosybrown3", "paleturquoise1", "mistyrose2", "limegreen", "lightgoldenrod4", "khaki3", "goldenrod4",
    "darkorchid4", "chocolate", "aquamarine", "cyan1", "orange1", "slateblue4", "violetred4", "seashell3", "peachpuff4", "olivedrab4", "mediumorchid1", "lightskyblue",
    "lemonchiffon4", "hotpink3", "dodgerblue1", "darkgoldenrod", "bisque2", "burlywood2", "dodgerblue2", "rosybrown2", "turquoise4", "steelblue3", "rosybrown1", "palegreen4",
    "mistyrose1", "lightyellow4", "lightgoldenrod3", "khaki2", "goldenrod3", "darkorchid3", "chartreuse4", "aquamarine1", "cyan4", "orangered2", "snow", "violetred2",
    "seashell2", "peachpuff3", "olivedrab3", "mediumblue", "lightseagreen", "lemonchiffon3", "hotpink2", "dodgerblue", "darkblue", "bisque1", "burlywood3", "firebrick1",
    "royalblue1", "violetred1", "steelblue1", "rosybrown", "palegreen3", "mintcream", "lightyellow3", "lightgoldenrod2", "khaki1", "goldenrod2", "darkorchid2", "chartreuse3",
    "aquamarine2", "darkcyan", "orchid", "snow2", "violetred", "seashell1", "peachpuff2", "olivedrab2", "mediumaquamarine", "lightsalmon4", "lemonchiffon2", "hotpink1",
    "deepskyblue3", "cyan3", "bisque", "burlywood4", "forestgreen", "royalblue4", "violetred3", "springgreen3", "red3", "palegreen1", "mediumvioletred", "lightyellow2",
    "lightgoldenrod1", "khaki", "goldenrod1", "darkorchid1", "chartreuse2", "aquamarine3", "darkgoldenrod2", "orchid1", "snow4", "turquoise3", "seashell", "peachpuff1",
    "olivedrab1", "maroon4", "lightsalmon3", "lemonchiffon1", "hotpink", "deepskyblue2", "cyan2", "beige", "cadetblue", "gainsboro", "salmon3", "wheat",
    "springgreen2", "red2", "palegreen", "mediumturquoise", "lightyellow1", "lightgoldenrod", "ivory4", "goldenrod", "darkorchid", "chartreuse1", "aquamarine4", "darkkhaki",
    "orchid3", "springgreen1", "turquoise1", "seagreen4", "peachpuff", "olivedrab", "maroon3", "lightsalmon2", "lemonchiffon", "honeydew4", "deepskyblue1", "cornsilk4",
    "azure4", "cadetblue1", "ghostwhite", "sandybrown", "wheat2", "springgreen", "purple4", "palegoldenrod", "mediumspringgreen", "lightsteelblue4", "lightcyan4", "ivory3",
    "gold3", "darkorange4", "chartreuse", "azure", "darkolivegreen3", "palegreen2", "springgreen4", "tomato3", "seagreen3", "papayawhip", "navyblue", "maroon2",
    "lightsalmon1", "lawngreen", "honeydew3", "deeppink4", "cornsilk3", "azure3", "cadetblue2", "gold", "seagreen", "wheat4", "snow3", "purple3",
    "orchid4", "mediumslateblue", "lightsteelblue3", "lightcyan3", "ivory2", "gold2", "darkorange3", "cadetblue4", "azure1", "darkorange1", "paleturquoise2", "steelblue2",
    "tomato1", "seagreen2", "palevioletred4", "navy", "maroon1", "lightsalmon", "lavenderblush4", "honeydew2", "deeppink3", "cornsilk1", "azure2", "cadetblue3",
    "gold4", "seagreen1", "yellow1", "snow1", "purple1", "orchid2", "mediumseagreen", "lightsteelblue2", "lightcyan2", "ivory1", "gold1", "yellow"
  )
  return(colors)
}
##################################################################
suppressMessages(library("openxlsx"))
#-----------------------------------------------------

SegmenPlot <- function() {
  # generate a segment plot displaying identified DMRs from EPIC methylation data
}
##################################################################

Between <-function(values, low_cutoff=0.3,high_cutoff=0.7){
    # return logical if values within the range [low_cutoff,high_cutoff]
     values > low_cutoff & values <=high_cutoff
}
##################################################################


##################################################################
# 01/08/2025, 14:53:36

Meth_QC <- function() {
  # to be done
}
##################################################################

IsValidColors <- function(x) {
  sapply(x, function(X) {
    tryCatch(is.matrix(col2rgb(X)),
      error = function(e) FALSE
    )
  })
}

Check_Meta_Color <- function(meta, groupColumn = "SAMPLE_GROUP") {
  if (!"COLOR" %in% colnames(meta)) {
    meta$COLOR <- standardColors()[as.integer(as.factor(meta[, groupColumn]))]
  } else {
    if (all(!IsValidColors(meta$COLOR))) { # allow custom color by category
      cat("\nINFO: custom color by category..")
      meta$COLORGROUP <- meta$COLOR
      meta$COLOR <- standardColors()[as.integer(as.factor(meta$COLORGROUP))]
    } else {
      cat("\nINFO: custom color by group ?")
      if (length(unique(meta$COLOR)) != length(unique(meta[, groupColumn]))) {
        cat("[No].\n")
        cat("\nPlease add COLORGROUP categorical column to your meta data file.")
        cat("\nAnd ensure COLOR string matches its COLORGROUP category.\n")
        q("no")
      } else {
        cat("[Yes].\n")
      }
    }
  }
  return(meta)
}
#================================================================

ggplotColours <- function(n = 6, h = c(0, 360) + 15){
  if ((diff(h) %% 360) < 1) h[2] <- h[2] - 360/n
  hcl(h = (seq(h[1], h[2], length = n)), c = 100, l = 65)
}
#================================================================
PALETTES <-  c("default","seurat","viridis","plasma", "magma","inferno","inferno","inferno","kako","turbo")

GetColors <- function(palette="Default",n=10) {
  suppressMessages(suppressWarnings(library(viridis)))
  colors <- switch(tolower(palette),
                   "default" = standardColors()[1:n],
                   "seurat" = ggplotColours(n),
                   "viridis" = viridis::viridis(n),
                   "plasma" = viridis::plasma(n),
                   "magma" = viridis::magma(n),
                   "inferno" = viridis::inferno(n),
                   "rocket" = viridis::rocket(n),
                   "cividis" = viridis::cividis(n),
                   "kako" = viridis::mako(n),
                   "turbo" = viridis::turbo(n)
    )
   return(colors)                
}
#-

#================================================================

Meth_Limma <- function() {
  # to be done
}
# ================================================================

Meth_DMR <- function() {
  # to be done
}


##################################################################

Calculate_impvar <- function(betaFile, metaFile,  icr.bed=NULL, probeset=NULL,assay=c("450K","EPICv1","EPICv2"),genome=c("hg19","hg38"),outFile=NULL) {
  suppressMessages(suppressWarnings(library("matrixStats")))
  suppressMessages(suppressWarnings(library("dplyr")))
  suppressMessages(suppressWarnings(library("GenomicRanges")))  
  
  input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
  meta <- input[["meta"]]
  beta <- input[["beta"]]

  if(!is.null(probeset)){
      probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
    if (probeset %in% names(probesets)){
        probeset1 <- probesets[[probeset]]
        rownames(probeset1) <- probeset1$NAME
    } else {
        cat("\nERROR: unavailable probeset.\n")
        q("no")
    }
    commonProbes <- intersect(rownames(beta), probeset1$NAME)
    mapping <- beta[commonProbes, ]
    mapping$NAME <- commonProbes
    mapping$icr_name <- paste(probeset1[commonProbes,"CHR"],probeset1[commonProbes,"ORIGIN"], probeset1[commonProbes,"Closest_TSS_gene_name"],sep='_')

  }else{

        
      if(!is.null(assay)){
        assay <- standardize_array(assay)
        assay <-  match.arg(assay)
      }
      genome <- match.arg(genome)
      genome <- toupper(genome)
      
      cpg_annos <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/anno.uniq_harmonized.liftover.rds")
      if (!is.null(assay)){
        cpg_annos <- cpg_annos[grep(assay, cpg_annos[,"ASSAY"],ignore.case=T),]
      }
      chr <- paste0("CHR_", genome)
      mapinfo <- paste0("MAPINFO_", genome)
      if (!all(grepl("chr", cpg_annos[[chr]][1:1000]))) {
        cpg_annos[[chr]] <- paste("chr", gsub("chr", "", cpg_annos[[chr]]), sep = "")
      }

      # 1. Map CpGs to ICR regions
      cpg_gr <- GRanges(seqnames = cpg_annos[[chr]], 
                        ranges = IRanges(start = cpg_annos[[mapinfo]], end = cpg_annos[[mapinfo]]))
      names(cpg_gr) <- cpg_annos[["NAME"]]

      icr_regions <- Bed2Granges(icr.bed)
      icr_names <- paste0(
          as.character(seqnames(icr_regions)), "_", 
          start(icr_regions), "_", 
          end(icr_regions)
        )
      icr_regions$name <- icr_names
      names(icr_regions) <- icr_names

      hits <- findOverlaps(cpg_gr, icr_regions)
      
      # 2. Extract and Group Data
      # We create a mapping of which CpG belongs to which ICR
      mapping <- data.frame(
        NAME=names(cpg_gr)[queryHits(hits)],
        CHR= as.character(seqnames(cpg_gr)[queryHits(hits)]),
        MAPINFO = start(cpg_gr)[queryHits(hits)],
        cpg_idx = queryHits(hits),
        icr_name = icr_regions$name[subjectHits(hits)]
      )
      
  }

  #beta <- LoadBeta(betaFile)
  if("TargetID" %in% colnames(beta)){
    beta$TargetID <- NULL
  }
  beta_matrix <- as.matrix(beta)

  # 3. Calculate within-region Variance
  # High variance = High stochasticity/instability
  report <- mapping %>%
        filter(NAME %in% rownames(beta_matrix)) %>%
        group_by(icr_name) %>%
          group_modify(~ {
      # Subset the beta matrix for CpGs in this specific ICR
      sub_beta <- beta_matrix[.x$NAME, , drop = FALSE]
      # 2.1 Calculate Median (always possible if nrow > 0)
        # colMedians returns a vector of medians, one per sample
        medians <- colMedians(sub_beta, na.rm = TRUE)

      # 2.2 Check if we have enough CpGs to calculate variance
        # Variance of 0 or 1 point is NA; we handle that here
        if (nrow(sub_beta) < 2) {
            scores <- rep(NA_real_, ncol(sub_beta))
   
        } else {
            scores <- colVars(sub_beta, na.rm = TRUE)
        }
      # Calculate column-wise variance (per sample)
      # We use Var to capture the 'spread' of methylation across the ICR
      data.frame(
        SAMPLE_NAME = colnames(beta_matrix),
        Median_Beta = medians,
        ImpVar_Score = scores,
        CpG_Count = nrow(sub_beta)
      )
    }) %>%
    ungroup()
    # Join metadata to the report
  
  final_report <- report %>%
    left_join(meta, by = "SAMPLE_NAME") %>%
    select(SAMPLE_NAME, any_of(c("SAMPLE_GROUP", "ID2")), icr_name,ImpVar_Score,Median_Beta, CpG_Count) %>%
    arrange(SAMPLE_GROUP,SAMPLE_NAME)

  if(!is.null(outFile)){
    # outFile <- paste0(prefix,"_Stochastic_Drift.txt")
    write.table(final_report, outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
    cat("\n[",basename(outFile),"[saved]")
  }
  return(final_report)
}
#----------------------------------------------------------------


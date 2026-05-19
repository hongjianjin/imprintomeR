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

#' @export
Between <-function(values, low_cutoff=0.3,high_cutoff=0.7){
    # return logical if values within the range [low_cutoff,high_cutoff]
     values > low_cutoff & values <=high_cutoff
}
##################################################################


##################################################################
# 01/08/2025, 14:53:36

.qc_as_numeric_matrix <- function(x, arg_name) {
  if (is.null(x)) {
    return(NULL)
  }

  if (!(is.matrix(x) || is.data.frame(x))) {
    stop(arg_name, " must be a matrix or data.frame.")
  }

  mat <- as.matrix(x)
  storage.mode(mat) <- "numeric"
  mat
}

.qc_extract_sentrix_ids <- function(meta) {
  if (!is.data.frame(meta)) {
    return(NULL)
  }

  if ("Sentrix_ID" %in% colnames(meta)) {
    return(as.character(meta$Sentrix_ID))
  }

  if ("Basename" %in% colnames(meta)) {
    return(basename(as.character(meta$Basename)))
  }

  NULL
}

.qc_subset_to_samples <- function(mat, sample_ids, arg_name) {
  if (is.null(mat)) {
    return(NULL)
  }

  if (is.null(colnames(mat))) {
    if (ncol(mat) != length(sample_ids)) {
      stop(arg_name, " must have column names or the same number of columns as samples.")
    }
    colnames(mat) <- sample_ids
  }

  common_ids <- intersect(sample_ids, colnames(mat))
  if (length(common_ids) == 0L) {
    stop(arg_name, " has no overlapping sample columns.")
  }

  mat[, sample_ids[sample_ids %in% common_ids], drop = FALSE]
}

.qc_calc_recall_rate <- function(detctionPval, pCutoff = 0.05, cnSuffix = NULL) {
  if (is.null(detctionPval)) {
    return(NULL)
  }

  DF <- .qc_as_numeric_matrix(detctionPval, "detection_p")
  if (is.null(dim(DF)) || ncol(DF) < 1L || nrow(DF) < 1L) {
    return(NULL)
  }

  recallRateAll <- apply(DF, 1, FUN = function(x) {
    sum(x < pCutoff, na.rm = TRUE)
  })
  recallRateAll <- recallRateAll / ncol(DF)
  rr_cutoffs <- seq(1, 0.3, by = -0.05)[-1]
  DetectedCpGs <- vapply(rr_cutoffs, function(cutoff) {
    sum(recallRateAll >= cutoff, na.rm = TRUE)
  }, numeric(1))
  pctDetectedCpG <- round(DetectedCpGs / nrow(DF) * 100, 1)

  recallRate <- data.frame(
    recall_rate_cutoffs = rr_cutoffs * 100,
    DetectedCpG_dP = DetectedCpGs,
    pctDetectedCpG_dP = pctDetectedCpG,
    stringsAsFactors = FALSE
  )

  if (is.null(cnSuffix)) {
    cnSuffix <- paste0("_", ncol(DF))
  } else {
    cnSuffix <- paste0(cnSuffix, "_", ncol(DF))
  }
  colnames(recallRate)[2:3] <- paste(colnames(recallRate)[2:3], pCutoff, cnSuffix, sep = "")
  recallRate
}

.qc_extract_minfi_intensity <- function(minfi_object, intensity_cutoff = 11) {
  if (is.null(minfi_object)) {
    return(NULL)
  }

  if (!requireNamespace("minfi", quietly = TRUE)) {
    stop("minfi is required when minfi_object is supplied.")
  }

  U <- minfi::getUnmeth(minfi_object)
  U[is.na(U)] <- 0
  M <- minfi::getMeth(minfi_object)
  M[is.na(M)] <- 0

  if (requireNamespace("matrixStats", quietly = TRUE)) {
    uMed <- log2(matrixStats::colMedians(U, na.rm = TRUE))
    mMed <- log2(matrixStats::colMedians(M, na.rm = TRUE))
  } else {
    uMed <- log2(apply(U, 2, median, na.rm = TRUE))
    mMed <- log2(apply(M, 2, median, na.rm = TRUE))
  }

  intensity_qc <- data.frame(
    SAMPLE_NAME = names(mMed),
    mMed = as.numeric(mMed),
    uMed = as.numeric(uMed),
    aveMedIntensity = as.numeric((mMed + uMed) / 2),
    stringsAsFactors = FALSE
  )
  intensity_qc$intensity_status <- ifelse(
    intensity_qc$aveMedIntensity >= intensity_cutoff,
    "PASS",
    "FAIL"
  )
  intensity_qc
}

.qc_reduce_status <- function(dat, status_cols) {
  if (length(status_cols) == 0L) {
    return(rep(NA_character_, nrow(dat)))
  }

  apply(dat[, status_cols, drop = FALSE], 1, function(x) {
    x <- as.character(x)
    x <- x[!is.na(x) & nzchar(x)]
    if (length(x) == 0L) {
      return(NA_character_)
    }
    if (any(x == "FAIL")) {
      return("FAIL")
    }
    if (all(x == "PASS")) {
      return("PASS")
    }
    "WARN"
  })
}

#' Summarize Core Methylation Array QC Metrics
#'
#' Creates a deterministic QC bundle from matched metadata/beta inputs and
#' optional detection p-values or a minfi object. The returned list is designed
#' Not intended for direct storage in ImprintomeSet (QC data is handled by MethQcSet).
#'
#' @param betaFile Beta matrix/data.frame, file path, or an `ImprintomeSet`.
#' @param metaFile Optional metadata data.frame or file path. Not required when
#'   `betaFile` is an `ImprintomeSet`.
#' @param detection_p Optional detection p-value matrix/data.frame with samples
#'   in columns.
#' @param minfi_object Optional minfi object used to derive methylated and
#'   unmethylated intensity medians.
#' @param assay Optional assay label. When omitted and `betaFile` is an
#'   `ImprintomeSet`, `assay(betaFile)` is used.
#' @param p_cutoff Detection p-value threshold used for per-sample recall.
#' @param mean_detection_cutoff Mean detection p-value threshold for PASS/FAIL.
#' @param intensity_cutoff Minimum average median intensity for PASS/FAIL.
#'
#' @return Named list containing `metadata_qc`, `beta_qc`, optional
#'   `detection_qc`, optional `detection_recall_rate`, optional `intensity_qc`,
#'   and merged `sample_qc`.
#' @export
Meth_QC <- function(betaFile,
                    metaFile = NULL,
                    detection_p = NULL,
                    minfi_object = NULL,
                    assay = NULL,
                    p_cutoff = 0.05,
                    mean_detection_cutoff = 0.03,
                    intensity_cutoff = 11) {
  assay_value <- assay
  if (methods::is(betaFile, "ImprintomeSet") && is.null(assay_value)) {
    assay_value <- methods::slot(betaFile, "assay")
  }
  if (!is.null(assay_value)) {
    assay_value <- standardize_array(assay_value)
  }

  resolved <- .resolve_beta_meta_inputs(betaFile, metaFile, require_meta = TRUE)
  input <- LoadMetaBeta(resolved$meta, resolved$beta, probeset = NULL)

  meta <- input$meta
  beta <- .qc_as_numeric_matrix(input$beta, "betaFile")
  sample_ids <- as.character(meta$Sample_Name)
  beta <- .qc_subset_to_samples(beta, sample_ids, "betaFile")

  sentrix_ids <- .qc_extract_sentrix_ids(meta)
  sentrix_valid <- if (is.null(sentrix_ids)) {
    rep(NA, length(sample_ids))
  } else {
    CheckSentrixID(sentrix_ids)
  }

  metadata_qc <- data.frame(
    SAMPLE_NAME = sample_ids,
    stringsAsFactors = FALSE
  )
  if ("SAMPLE_GROUP" %in% colnames(meta)) {
    metadata_qc$SAMPLE_GROUP <- as.character(meta$SAMPLE_GROUP)
  }
  if (!is.null(assay_value)) {
    metadata_qc$assay <- assay_value
  }
  metadata_qc$sentrix_id <- if (is.null(sentrix_ids)) NA_character_ else as.character(sentrix_ids)
  metadata_qc$sentrix_id_valid <- as.logical(sentrix_valid)
  metadata_qc$sentrix_status <- ifelse(
    is.na(metadata_qc$sentrix_id_valid),
    NA_character_,
    ifelse(metadata_qc$sentrix_id_valid, "PASS", "FAIL")
  )

  beta_qc <- data.frame(
    SAMPLE_NAME = sample_ids,
    beta_median = apply(beta, 2, median, na.rm = TRUE),
    beta_missing_n = colSums(is.na(beta)),
    beta_missing_pct = round(colMeans(is.na(beta)) * 100, 2),
    stringsAsFactors = FALSE
  )

  out <- list(
    metadata_qc = metadata_qc,
    beta_qc = beta_qc
  )

  detection_qc <- NULL
  if (!is.null(detection_p)) {
    detection_mat <- .qc_as_numeric_matrix(detection_p, "detection_p")
    detection_mat <- .qc_subset_to_samples(detection_mat, sample_ids, "detection_p")
    pct_detected_col <- paste0("pctDetectedCpG_dP", format(p_cutoff, trim = TRUE, scientific = FALSE))

    detection_qc <- data.frame(
      SAMPLE_NAME = colnames(detection_mat),
      aveDetectionPval = colMeans(detection_mat, na.rm = TRUE),
      pct_detected = round(colMeans(detection_mat < p_cutoff, na.rm = TRUE) * 100, 1),
      stringsAsFactors = FALSE
    )
    colnames(detection_qc)[colnames(detection_qc) == "pct_detected"] <- pct_detected_col
    detection_qc$detection_status <- ifelse(
      detection_qc$aveDetectionPval < mean_detection_cutoff & detection_qc[[pct_detected_col]] > 95,
      "PASS",
      "FAIL"
    )

    out$detection_qc <- detection_qc
    out$detection_recall_rate <- .qc_calc_recall_rate(detection_mat, pCutoff = p_cutoff, cnSuffix = "_all")
  }

  intensity_qc <- .qc_extract_minfi_intensity(minfi_object, intensity_cutoff = intensity_cutoff)
  if (!is.null(intensity_qc)) {
    intensity_qc <- intensity_qc[intensity_qc$SAMPLE_NAME %in% sample_ids, , drop = FALSE]
    intensity_qc <- intensity_qc[match(sample_ids, intensity_qc$SAMPLE_NAME), , drop = FALSE]
    out$intensity_qc <- intensity_qc
  }

  sample_level_tables <- Filter(function(z) {
    is.data.frame(z) && "SAMPLE_NAME" %in% colnames(z)
  }, out)

  sample_qc <- Reduce(function(left, right) {
    merge(left, right, by = "SAMPLE_NAME", all = TRUE, sort = FALSE)
  }, sample_level_tables)

  status_cols <- intersect(
    c("sentrix_status", "detection_status", "intensity_status"),
    colnames(sample_qc)
  )
  sample_qc$final_qc_status <- .qc_reduce_status(sample_qc, status_cols)
  out$sample_qc <- sample_qc[match(sample_ids, sample_qc$SAMPLE_NAME), , drop = FALSE]

  out
}
##################################################################

IsValidColors <- function(x) {
  sapply(x, function(X) {
    tryCatch(is.matrix(col2rgb(X)),
      error = function(e) FALSE
    )
  })
}

#' @export
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

Select_Top_Features <- function(dat, method = "mad", topn = 3000) {
  if (!("data.frame" %in% class(dat) || "matrix" %in% class(dat))) {
    stop("[Select_Top_Features] dat must be a data.frame or matrix.")
  }
  dat <- as.matrix(dat)
  if (nrow(dat) == 0) {
    return(dat)
  }

  method <- tolower(method)
  scores <- switch(method,
    "mad" = apply(dat, 1, mad, na.rm = TRUE),
    "cv" = apply(dat, 1, function(x) sd(x, na.rm = TRUE) / mean(x, na.rm = TRUE)),
    "cv2" = apply(dat, 1, function(x) var(x, na.rm = TRUE) / (mean(x, na.rm = TRUE)^2)),
    "sd" = apply(dat, 1, sd, na.rm = TRUE),
    "var" = apply(dat, 1, var, na.rm = TRUE),
    "iqr" = apply(dat, 1, IQR, na.rm = TRUE),
    {
      cat("\nWARN: invalid ranking method. use [mad] instead.\n")
      apply(dat, 1, mad, na.rm = TRUE)
    }
  )

  scores[!is.finite(scores)] <- -Inf
  if (is.null(topn)) {
    topn <- nrow(dat)
  } else {
    topn <- as.integer(topn)
    if (is.na(topn) || topn < 1) {
      return(dat[0, , drop = FALSE])
    }
  }

  keep_n <- min(topn, nrow(dat))
  keep_idx <- order(scores, decreasing = TRUE)[seq_len(keep_n)]
  dat[keep_idx, , drop = FALSE]
}
#================================================================

ggplotColours <- function(n = 6, h = c(0, 360) + 15){
  if ((diff(h) %% 360) < 1) h[2] <- h[2] - 360/n
  hcl(h = (seq(h[1], h[2], length = n)), c = 100, l = 65)
}
#================================================================
PALETTES <-  c("default","seurat","viridis","plasma", "magma","inferno","inferno","inferno","kako","turbo")

#' @export
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

#' @export
Calculate_impvar <- function(betaFile, metaFile = NULL,  icr.bed=NULL, probeset=NULL,assay=c("450K","EPICv1","EPICv2"),genome=c("hg19","hg38"),outFile=NULL) {
  suppressMessages(suppressWarnings(library("matrixStats")))
  suppressMessages(suppressWarnings(library("dplyr")))
  suppressMessages(suppressWarnings(library("GenomicRanges")))  

  resolved <- .resolve_beta_meta_inputs(betaFile, metaFile, require_meta = TRUE)
  betaFile <- resolved$beta
  metaFile <- resolved$meta
  
  input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
  meta <- input[["meta"]]
  beta <- input[["beta"]]

  if(!is.null(probeset)){
      probesets <- readRDS("inst/extdata/probesets_hg19.rds")
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
      
      cpg_annos <- readRDS(.resolve_extdata_file("anno.uniq_harmonized.liftover.rds"))
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

#' Aggregate EPICv2 Probes to Base Probe IDs
#'
#' EPICv2 arrays report multiple measurements per base CpG probe (e.g., cg06373096_TC11,
#' cg06373096_TC12, ..., cg06373096_TC110 all measure cg06373096). This function aggregates
#' repeated measurements into a single representative value per unique probe ID.
#'
#' @param beta_df A data.frame with a \code{TargetID} column (probe IDs) and numeric columns
#'   (beta values, detection p-values, etc.). Can be coerced from matrix.
#' @param method Character, one of \code{c("median", "mean")}. Aggregation method for
#'   numeric columns. Default: \code{"median"}.
#'
#' @return A data.frame with the same structure as \code{beta_df}, but with:
#'   \itemize{
#'     \item \code{TargetID} column: base probe IDs (suffixes removed)
#'     \item Numeric columns: aggregated values (median or mean across replicates)
#'   }
#'   If no EPICv2-style suffixes are detected (\code{_[TB].\\d+$}), returns \code{beta_df}
#'   unchanged (with a message).
#'
#' @details
#' The function detects EPICv2 probe suffixes matching the pattern \code{_[TB].\\d+$}
#' (e.g., \code{_TC11}, \code{_TB01}). If found, the suffix is stripped and values are
#' aggregated by base probe ID. Numeric columns are aggregated using the chosen method;
#' all other columns are dropped.
#'
#' @examples
#' \dontrun{
#'   # Load EPICv2 beta matrix
#'   beta_df <- read.delim("epicv2_beta.txt")
#'   
#'   # Aggregate to base probes
#'   beta_agg <- aggregate_beta_epicv2(beta_df, method = "median")
#'   
#'   # Check result
#'   dim(beta_agg)  # Fewer rows (unique base probes)
#' }
#'
#' @export
aggregate_beta_epicv2 <- function(beta_df, method = c("median", "mean")) {
  suppressMessages(suppressWarnings(library(dplyr)))
  
  # Coerce to data.frame if needed
  if (!is.data.frame(beta_df)) {
    beta_df <- as.data.frame(beta_df)
  }
  
  # Validate TargetID column exists
  if (!("TargetID" %in% colnames(beta_df))) {
    stop("TargetID column not found in beta_df. Required for probe aggregation.")
  }
  
  # Check for EPICv2-style suffixes
  if (sum(grepl("_[TB].\\d+$", beta_df$TargetID)) == 0) {
    message("No EPICv2-style suffixes detected in TargetID. Returning data unchanged.")
    return(beta_df)
  }
  
  # Match and validate method argument
  method <- match.arg(method)
  
  # Strip suffixes to get base probe IDs
  beta_df$TargetID <- sub("_[TB].\\d+$", "", beta_df$TargetID)
  
  # Aggregate: group by TargetID, aggregate all numeric columns
  aggregated_data <- beta_df %>%
    dplyr::group_by(TargetID) %>%
    dplyr::summarise(dplyr::across(where(is.numeric), 
                                   list(~ if (method == "median") 
                                          median(., na.rm = TRUE) 
                                        else 
                                          mean(., na.rm = TRUE)),
                                   .names = "{.col}"),
                     .groups = "drop") %>%
    as.data.frame()
  
  aggregated_data
}
#----------------------------------------------------------------


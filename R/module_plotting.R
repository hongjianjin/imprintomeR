# Auto-refactored from utilities2.R
# Module: plotting

#' Internal Color Mapping for Allelic Origin
#'
#' Defines a stable maternal/paternal/reference color mapping for ggplot
#' visualizations in imprintomeR.
#'
#' @return Named character vector with `maternal`, `paternal`, and `reference`.
.imprint_origin_colors <- function() {
  c(
    maternal = "#E69F00",
    paternal = "#56B4E9",
    reference = "#666666"
  )
}


#' Save Plot Conditionally and Return Plot Object
#'
#' Internal helper to standardize optional file saving while always returning
#' the plot object.
#'
#' @param plot_obj A ggplot object.
#' @param outFile Optional output file path. If `NULL`, nothing is written.
#' @param width,height Optional numeric width/height in inches.
#' @param units Units passed to `ggsave`.
#' @param limitsize Passed to `ggsave`.
#'
#' @return The input `plot_obj`.
.imprint_save_plot <- function(plot_obj, outFile = NULL, width = NULL, height = NULL,
                               units = "in", limitsize = TRUE) {
  if (!is.null(outFile)) {
    if (is.null(width) || is.null(height)) {
      ggsave(file = outFile, plot = plot_obj, units = units, limitsize = limitsize)
    } else {
      ggsave(file = outFile, plot = plot_obj, width = width, height = height, units = units, limitsize = limitsize)
    }
    cat("\n\t", basename(outFile), "[saved]")
  }
  plot_obj
}

PlotCorHeatmap <- function(betaFile, metaFile = NULL, SAMPLEID="Sample_Name", prefix=NULL){
  library(pheatmap)
  resolved <- .resolve_beta_meta_inputs(betaFile, metaFile, require_meta = TRUE)
  betaFile <- resolved$beta
  metaFile <- resolved$meta

  if((inherits(betaFile, c('data.frame', 'matrix'))) && inherits(metaFile, 'data.frame')){ # data.frame or matrix as input
    meta <- metaFile
    beta <- as.data.frame(betaFile)
  }else{ # filename as input
    input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
    meta <- input[["meta"]]
    beta <- input[["beta"]]
  }

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
  cor_matrix <- cor(beta)

 
 
  plotWidth<- plotHeight<- ifelse(ncol(cor_matrix)<10, 10, 10+ (ncol(cor_matrix)-10)*0.8 ) 
  color_palette <- colorRampPalette(c("blue", "white", "red"))(100)
 # Define breaks from -1 to 1
   breaks_list <- seq(-1, 1, length.out = 101)
  # Generate heatmap
  outFile1 <- paste0(prefix, "_detail.pdf")  
  hm <- pheatmap(cor_matrix,
          color = color_palette,
          breaks = breaks_list,
          display_numbers = TRUE,     # Optional: show correlation values
          clustering_distance_rows = "euclidean",
          clustering_distance_cols = "euclidean",
          clustering_method = "complete",
          main = "Correlation Heatmap",
          file=outFile1,
          width=plotWidth,height=plotHeight)
  cat(paste0('\nInfo: ',basename(outFile1),'[saved]'))            
  #================================================================
  outFile2 <- paste0(prefix, "_simple.pdf")            
  hm <- pheatmap(cor_matrix,
          color = color_palette,
          breaks = breaks_list,
          display_numbers = FALSE,     # Optional: show correlation values
          clustering_distance_rows = "euclidean",
          clustering_distance_cols = "euclidean",
          clustering_method = "complete",
          main = "Correlation Heatmap",
          file=outFile2,
          width=plotWidth/2,height=plotHeight/2)
  cat(paste0('\nInfo: ',basename(outFile2),'[saved]'))     
  #================================================================
  outFile3 <- paste0(prefix, "_auto.simple.pdf") 
  hm <- pheatmap(cor_matrix,
          color = color_palette,
          breaks = breaks_list,
          display_numbers = FALSE,     # Optional: show correlation values
          clustering_distance_rows = "euclidean",
          clustering_distance_cols = "euclidean",
          clustering_method = "complete",
          main = "Correlation Heatmap",
          file=outFile3,
          width=plotWidth/2,height=plotHeight/2)
  cat(paste0('\nInfo: ',basename(outFile3),'[saved]'))              
  return(cor_matrix)
}
#================================================================



#================================================================

ComputePCA  <- function(df, meta, scale=T, topn = 3000,varMethod="mad",groupColumn = "Sample_Group"){
  #rownames(diff) <- diff_table$gene
  if (! "data.frame" %in% class(df) ){
    cat("\n[ComputePCA] INFO: in ComputePCA function: parameter [df] must be a data.frame! \n")
   df <- as.data.frame(df)
  }
  cat("\n[ComputePCA] INFO: PCA #features ", topn," from", nrow(df),"\n")
  meta <- Check_Meta_Color(meta, groupColumn)
  if (! "data.frame" %in%  class(meta) ){
    cat("\n[ComputePCA] ERROR: parameter [meta] must be a data.frame! \n")
    stop("Exit...")
  }
  #validate input 
  colnames(meta) <- toupper(colnames(meta))
  if (!all(c("Sample_Name","Sample_Group","COLOR") %in% colnames(meta))) {
    cat("\n[ComputePCA] INFO: Invalid meta file. SAMPLE_NAME, SAMPLE_GROUP or COLOR column(s) not found.\n")
    stop("exit.")
  }
  
  isNewName <- length(intersect(colnames(df), meta$NEWNAME )) > length(intersect(colnames(df), meta$ID ))
  if (isNewName){
    cat("\n[ComputePCA] INFO: Use NEWNAME in df table..\n")
    keptSamples <- intersect(colnames(df), meta$NEWNAME )
    idx1 <- match(keptSamples, colnames(df))
    idx2 <- match(keptSamples, meta$ID )
    colnames(df)[idx1] <- meta$NEWNAME[idx2]
    rownames(meta) <- meta$NEWNAME
    #meta$ID <- meta$NEWNAME
  }else{
    cat("\n[ComputePCA] INFO: Use IDs present in meta table..\n")
    rownames(meta) <- meta$Sample_Name
    keptSamples <-  intersect(rownames(meta),colnames(df))
  }
  if (length(keptSamples) ==0){
    cat("\n[ComputePCA] ERROR: ID in metadata table doesn\'t match colnames in input matrix!\n")
    cat("\nIDs in meta: ")
    print(head(rownames(meta),n=3))
    cat("\ncolnames in matrix: ")
    print(head(colnames(df),n=3))
    stop ("[ComputePCA] INFO: Invalid metadata file!\n")
  }
  meta <- meta[keptSamples, ]
  dat <- data.matrix(df[, keptSamples, drop = FALSE])
  row_has_finite <- apply(dat, 1, function(x) any(is.finite(x)))
  row_all_finite <- apply(dat, 1, function(x) all(is.finite(x)))
  dat <- dat[row_has_finite & row_all_finite, , drop = FALSE]
  if (nrow(dat) == 0) {
    stop("[ComputePCA] ERROR: no finite features available after filtering NA/Inf rows.")
  }

  used <- Select_Top_Features(dat, method = tolower(varMethod), topn = topn)
  used <- used[apply(used, 1, function(x) all(is.finite(x))), , drop = FALSE]
  if (nrow(used) == 0) {
    stop("[ComputePCA] ERROR: no valid features selected for PCA after filtering.")
  }
  pcs <- prcomp(t(used), center = TRUE, scale = scale) 
  pctVar <- round(((pcs$sdev)^2 / sum((pcs$sdev)^2) * 100), 2)
  tmp <- as.data.frame(pcs$x)
  #mat <- data.frame(X=tmp[,"PC1"],Y=tmp[,"PC2"], meta[rownames(tmp),])  # data ready for plot
  mat <- data.frame(X=tmp[,"PC1"],Y=tmp[,"PC2"],Z=tmp[,"PC3"])  # data ready for plot
  return(list(pcs=pcs, pctVar=pctVar, topn=topn, varMethod=varMethod, meta=meta[rownames(tmp),], mat=mat))
}

#================================================================

ComputeTSNE  <- function(PCAobj, npcs=50,perplexity=5, max_iter=5000, dims=2, seed=99){
  library("Rtsne")
  pca <- PCAobj[["pcs"]]
  meta <-  PCAobj[["meta"]]
  npcs <- ifelse(ncol(pca$x)>npcs,npcs,ncol(pca$x))
  print(ncol(pca$x))
  topPCS <- pca$x[,1:npcs]  
  
  cat("\nINFO: tSNE [start] \n",apply(topPCS[,1:5],2,class),"\n")
  #print(topPCS[1:3,1:4])
  tmpfile = paste0("tsne.npcs",npcs,".perp",perplexity,".max_iter",max_iter,".tmp");
  zz <- file(tmpfile, open = "wt")
  sink(zz)
  set.seed(seed)
  tsne_out <- Rtsne(topPCS, dims = dims,theta=0, pca=F,max_iter = as.integer(max_iter), perplexity=as.integer(perplexity), verbose=TRUE, check_duplicates = FALSE)
  sink()
  close(zz)
  cat("\nINFO: tSNE [end] \n")
  if (dims == 3){
    mat <- data.frame(X=tsne_out$Y[,1],Y=tsne_out$Y[,2] ,Z =tsne_out$Y[,3])
  }else{
    mat <- data.frame(X=tsne_out$Y[,1],Y=tsne_out$Y[,2])
  }
  return (list(mat=mat, meta=meta,npcs=npcs, perplexity=perplexity,max_iter=max_iter, topn=PCAobj[["topn"]]))
}
#================================================================

DimPlot  <- function(DimReduc,  reduction = "PCA", ShapeColumn=NULL, IdColumn='Sample_Name', groupColumn='Sample_Group', 
  ColorColumn="COLOR",outFile=NA, label=F, title=NA,palette="Default",alpha=0.8){
  library(ggplot2)
  library(ggrepel)
  options(bitmapType = "cairo")
  #-----------------------------------------------
  meta <- DimReduc[["meta"]]   
  DF <- DimReduc[["mat"]]
  topn <- DimReduc[["topn"]]
  if (toupper(reduction) =="PCA"){
     pctVar <- DimReduc[["pctVar"]]
     myTitle <- paste0("topn=",topn)
     if(!is.null(pctVar[1])){
        xlab <- paste0("PC1 (", pctVar[1], "%)")
     }else{
        xlab <- paste0("PC1")
     }
    if(!is.null(pctVar[2])){
       ylab <- paste0("PC2 (", pctVar[2], "%)")
    }else{
       ylab <- paste0("PC2")
    }
  }else if (toupper(reduction) =="TSNE"){
    myTitle <- paste0("topn=",topn, ",npcs=",DimReduc[["npcs"]], ", perplexity=",DimReduc[["perplexity"]],", max_iter=",DimReduc[["max_iter"]])
    xlab <- paste0("tSNE_1")
    ylab <- paste0("tSNE_2")
  } 
  if (! is.na(title) & !is.null(title)){
    myTitle <- paste0(title,"\n", myTitle)
  }
  meta$GROUP <- meta[,groupColumn]
  meta$ID <-  meta[, IdColumn]
  if (ColorColumn != "COLOR" | palette != "Default"){
    meta$COLOR <- GetColors(palette=palette,n=length(unique(meta[,ColorColumn])))[as.integer(factor(meta[,ColorColumn],levels=unique(meta[,ColorColumn])))]
    meta[,groupColumn]<- meta[,ColorColumn]
  }
  #cat("\n", table(meta$COLOR))
  if (is.null(ShapeColumn)){
    meta$SHAPE <- "None"
    meta$SYMBOL <- 21
  }else{
    if( ! ShapeColumn %in% colnames(meta)){
      cat("\nWarn: invalid ShapeColumn.", ShapeColumn,"\n") 
      #print(colnames(meta))
      meta$SHAPE <- "None"
      meta$SYMBOL <- 21
    }else{
      meta$SHAPE <- meta[,ShapeColumn]
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

  }
   sampleSize <- nrow(meta)
  dotSize <- 5-log2(nrow(meta))/2
  dotSize <- ifelse(dotSize<1 , 1, dotSize)
  options(stringsAsFactors = F) 
  DF<- data.frame(DF, ID=meta$ID, GROUP=meta$GROUP, COLOR=meta$COLOR)
  if ("NEWNAME" %in% colnames(meta)){
    DF <- cbind(DF, INFO=paste(meta$ID, meta$NEWNAME,meta$GROUP, meta$SHAPE,sep="\n"))
    #DF<- data.frame(DF, meta[, c("ID", "GROUP",  "COLOR")], )
  }else{
    DF <- data.frame(DF, INFO=paste(meta$ID, meta$GROUP,meta$SHAPE,sep="\n"))
    #DF<- data.frame(DF, meta[, c("ID", "GROUP",  "COLOR")])
  } 

  if (length(unique(DF$GROUP)) !=length(unique(DF$COLOR))){ # update color
    for(grp in unique(DF$GROUP)) {
      DF$COLOR[DF$GROUP ==grp] <- head(DF$COLOR[DF$GROUP ==grp],n=1)
    }
  }
  
  if("SHAPE" %in% colnames(meta)){
    DF<- cbind(DF, SHAPE=meta$SHAPE, SYMBOL=meta$SYMBOL)
    #DF$SHAPE[DF$SHAPE=="" | is.na(DF$SHAPE) ] <- "NA"
    if (length(unique(DF$SHAPE)) <= 5){
      #shapes<- c(21,23,24,22,25) 
      fill_manual_status <- TRUE
    }else{
      #shapes<- c(19, 17, 15, 18, 16, 14:0)
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
  GROUPS <- factor(DF$GROUP, levels=unique(DF$GROUP))
  #mutliple groups may share same shape
  if ("SHAPE" %in% colnames(DF) ){
    if(fill_manual_status){
      pg <- ggplot(DF, aes(x = X, y = Y,text=INFO)) +
        xlab(xlab) + ylab(ylab) +
        geom_hline(yintercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.25) +
        geom_vline(xintercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.25) +
        geom_point(size = dotSize,  aes(fill=GROUPS,shape=SHAPES),color="grey50",alpha=alpha)+
        scale_fill_manual(name="Color", values =setNames(uniqCombs$COLOR, uniqCombs$GROUP)) +
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
      pg <- ggplot(DF, aes(x = X, y = Y,text=INFO)) +
        xlab(xlab) + ylab(ylab) +
        geom_hline(yintercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.25) +
        geom_vline(xintercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.25) +
        geom_point(size = dotSize,  aes(color=GROUPS,shape=SHAPES),alpha=alpha)+
        scale_color_manual(name="Color", values=setNames(uniqCombs$COLOR, uniqCombs$GROUP))+
        scale_shape_manual(name="Shape", values=setNames(uniqCombs$SYMBOL, uniqCombs$SHAPE) )+
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
    pg <- ggplot(DF, aes(x = X, y = Y,text= INFO)) +
      xlab(xlab) + ylab(ylab) +
      geom_hline(yintercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.25) +
      geom_vline(xintercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.25) +
      geom_point(size = dotSize,  aes(fill=GROUPS), colour="grey50",lwd = 2, alpha=0.6,shape=21) + 
      scale_fill_manual(name="GROUP", labels=uniqCombs$GROUP, values = uniqCombs$COLOR) +
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
  if (label){
    pg1 <- pg + geom_text(data = DF, aes(x = X, y = Y, label =ID),   hjust = 0, nudge_x = 0.2, size=2.5)
  }else{
    pg1 <- pg
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
    adj <- ifelse(length(levels(GROUPS))>16,2,0) + ifelse(length(levels(SHAPES))>10,2,0) # in case there are many legend labels
    ggsave(file = outFile, pg2, width = 7+adj, height = 6+adj, units = "in")
    cat("\n\t", basename(outFile),"[saved]")
  }
  return(pg1)
}
#================================================================

Meth_PCA_Adv <- function(dat,meta=NULL, ShapeColumn=NULL,IdColumn='Sample_Name', groupColumn='Sample_Group', 
            ColorColumn="COLOR", scale=F,  topn = 3000, outPrefix=NULL, label=F, palette="Default") {
  #  typically do not need to scale because beta values range from 0 to 1, representing the proportion of methylation.
  rdsFile <- paste0(outPrefix,"_PCAobj.rds")
  if (file.exists(rdsFile)){
    PCAobj   <- readRDS(rdsFile)
    #PCAobj[["meta"]] <- meta  # refresh metadata
    cat('\n\t',basename(rdsFile),'[loaded]')
  }else{
    PCAobj <- ComputePCA(dat, meta=meta, scale=scale,  topn =topn , varMethod="mad", groupColumn=groupColumn)
    saveRDS(PCAobj,file=rdsFile)
    cat('\n\t',basename(rdsFile),'[saved]')
    meta1 <- PCAobj[["meta"]]
    mat1 <- PCAobj[["mat"]]
    res <- cbind(meta1, mat1)
    outFile <- paste0(outPrefix,"_PCA.txt")
    write.table(res, outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
    cat("\n[",basename(outFile),"[saved]")
  }
  pdfFile <-  paste0(outPrefix,"_PCA_",palette,".pdf")
  pg <- DimPlot(PCAobj, reduction = "PCA", ShapeColumn=ShapeColumn, IdColumn=IdColumn, groupColumn=groupColumn,
        ColorColumn=ColorColumn,label=label, title="PCA",palette=palette,outFile=pdfFile) 

  return(pg)
}

Meth_TSNE_Adv <- function(dat,meta=NULL, ShapeColumn=NULL,IdColumn='Sample_Name', groupColumn='Sample_Group', ColorColumn="COLOR", 
     scale=F,  topn = 3000, npcs=50,perplexity=5, max_iter=5000,dims=3, outPrefix=NA, label=F, seed=123,palette="Default") {
  rdsFile <- paste0(outPrefix,"_PCAobj.rds")
  if (file.exists(rdsFile)){
    PCAobj   <- readRDS(rdsFile)
    cat(paste0('\n\t',basename(rdsFile),' [loaded]'))
  }else{
    PCAobj <- ComputePCA(dat, meta=meta, scale=scale,  topn =topn , varMethod="mad")
    saveRDS(PCAobj,file=rdsFile)
    cat(paste0('\n\t',basename(rdsFile),' [saved]'))
  }
  cat("\nINFO:compute.tSNE [start]") 
  objFile <- paste0(outPrefix,"_tSNEobj.rds")
  if (file.exists(objFile)){
     tSNEobj   <- readRDS(objFile)
     cat(paste0('\n\t',basename(objFile),' [loaded]'))   
  }else{ 
     tSNEobj <- ComputeTSNE(PCAobj, npcs=npcs,perplexity=perplexity, max_iter=max_iter, dims=dims, seed=seed)
     saveRDS(tSNEobj,file=objFile)
     cat(paste0('\n\t',basename(objFile),' [saveded]'))   
  }
  cat("\nINFO:compute.tSNE [end]") 
  pdfFile <-  paste0(outPrefix,"_tSNE_",palette,".pdf")
  pg <- DimPlot(tSNEobj, reduction = "tSNE", ShapeColumn=ShapeColumn,IdColumn='Sample_Name', groupColumn='Sample_Group',
         ColorColumn=ColorColumn,label=label, title="tSNE",palette=palette,outFile=pdfFile) 
  return(pg)
}

##################################################################

#' Violin Plot of Methylation Distributions by Sample
#'
#' @param beta Numeric beta matrix with probes as rows and samples as columns.
#' @param meta Sample metadata containing `SAMPLE_NAME` and grouping columns.
#' @param SAMPLEID Metadata column used as x-axis sample label.
#' @param outFile Optional output file path.
#' @param alpha Violin alpha.
#'
#' @return A ggplot object.
BetaVlnPlot <- function(beta, meta = NULL, SAMPLEID = "Sample_Name", outFile = NULL, alpha = 1) {
  suppressMessages(suppressWarnings(library(ggplot2)))
  options(ggplot2.verbose = FALSE)
  resolved <- .resolve_beta_meta_inputs(beta, meta, require_meta = TRUE)
  beta <- resolved$beta
  meta <- resolved$meta

  TargetIDs <- rownames(beta)
  validIds <- intersect(meta$Sample_Name, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$Sample_Name %in% validIds]
  if (length(validIds) > 0) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$Sample_Name. \n")
    return(NULL)
  }
  colnames(beta) <- newIDs
  # Ensure Sample_Group exists; create if missing
  if (!"Sample_Group" %in% colnames(meta)) {
    meta$Sample_Group <- "All"
  }
  suppressMessages({
    used <- reshape2::melt(t(as.matrix(beta)))
  })
  colnames(used)[1] <- "ID"
  used$value <- as.numeric(used$value) #* 100
  # Filter out NA values to avoid warning about removed rows
  used <- used[!is.na(used$value), ]
  meta <- meta[order(meta$Sample_Group), ]
  rownames(meta) <- as.character(meta$SAMPLEID)
  orderedIDs <- meta$SAMPLEID

  GROUP1 <- meta$Sample_Group[match(as.character(used$ID), meta$SAMPLEID)]
  used$GROUP <- factor(GROUP1, levels = unique(meta$Sample_Group))
  uniqCols <- standardColors()[1:length(unique(meta$Sample_Group))]
  uniqComb <- data.frame(GROUP = unique(meta$Sample_Group), COLOR = uniqCols)

  cat("\n generate violin plot ...\n")
  pg <- ggplot(used, aes(x = ID, y = value)) +
    geom_hline(yintercept = 0.5, linetype = "dashed", color = .imprint_origin_colors()["reference"]) +
    geom_violin(aes(x = ID, y = value, fill = GROUP), trim = FALSE, alpha = alpha) +
    theme_classic(base_size = 10) +
    labs(y = "Methylation (Î²)", x = "ID") +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) +
    scale_fill_manual(
      name = "GROUP",
      labels = uniqComb$GROUP,
      values = uniqComb$COLOR
    ) +
    ylim(0, 1) +
    scale_x_discrete(limits = orderedIDs) # a specific order on the X axis with scale_x_discrete

  imgHeight <- 5 + max(nchar(meta$SAMPLEID)) / 20
  # theme(plot.title = element_text(size = 6),plot.subtitle=element_text(size=6)) +
  # ggtitle(label=title,subtitle=subTitle)
  if (!is.null(outFile)) {
    if (ncol(beta) > 20) {
      imgWidth <- 10 + ncol(beta) / 5
      .imprint_save_plot(pg, outFile = outFile, width = imgWidth, height = imgHeight, units = "in", limitsize = FALSE)
    } else {
      imgWidth <- 10 + ncol(beta) / 10
      .imprint_save_plot(pg, outFile = outFile, width = imgWidth, height = imgHeight, units = "in", limitsize = TRUE)
    }
  }
  options(ggplot2.verbose = TRUE)
  return(pg)
}


##################################################################

#' Beeswarm Plot of Methylation by Sample
#'
#' @param beta Numeric beta matrix with probes as rows and samples as columns.
#' @param meta Sample metadata containing `SAMPLE_NAME` and grouping columns.
#' @param SAMPLEID Metadata column used as x-axis sample label.
#' @param outFile Optional output file path.
#' @param alpha Point alpha.
#' @param orderByGroup Logical; whether to order samples by group.
#' @param ylab Y-axis label.
#' @param xlab X-axis label.
#' @param legend Logical; include legend page in saved output.
#'
#' @return A patchwork/ggplot object.
BetaBeePlot <- function(beta, meta = NULL, SAMPLEID = "Sample_Name", outFile = NULL, alpha = 1, orderByGroup=FALSE, ylab="Methylation (Î²)", xlab="ID", legend=TRUE, title="ImprintomeR: beeswarm", subtitle=NULL, width=NULL, height=NULL) {
  # https://r-charts.com/distribution/ggbeeswarm/
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
  suppressMessages(suppressWarnings(library("grid")))
  options(ggplot2.verbose = FALSE)
  resolved <- .resolve_beta_meta_inputs(beta, meta, require_meta = TRUE)
  beta <- resolved$beta
  meta <- resolved$meta

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
  # Ensure Sample_Group exists; create if missing
  if (!"Sample_Group" %in% colnames(meta)) {
    meta$Sample_Group <- "All"
  }
  suppressMessages({
    used <- reshape2::melt(as.matrix(beta))
  })
  used$value <- as.numeric(as.character(used$value))
  colnames(used)[2] <- "ID"
  used$value <- as.numeric(used$value) #* 100

  if(orderByGroup){
      meta <- meta[order(meta$Sample_Group), ] # order GROUP
  }
  orderedIDs <- meta$SAMPLEID # order SMAPLEID by GROUP
  rownames(meta) <- as.character(meta$SAMPLEID)

  GROUP1 <- meta$Sample_Group[match(as.character(used$ID), meta$SAMPLEID)]
  used$GROUP <- factor(GROUP1, levels = unique(meta$Sample_Group))
  uniqCols <- standardColors()[1:length(unique(meta$Sample_Group))]
  uniqComb <- data.frame(GROUP = unique(meta$Sample_Group), COLOR = uniqCols)
  cat("\n generate dotplot ...\n")
  pg <- ggplot(used, aes(x = ID, y = value, color = GROUP)) +
    geom_hline(yintercept = 0.5, linetype = "dashed", color = .imprint_origin_colors()["reference"]) +
    geom_quasirandom(cex = dotSize, alpha = alpha) +
    theme_minimal() +
    theme_classic(base_size = 10) +
    labs(y = ylab, x = xlab, title = title, subtitle = subtitle) +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) +
    scale_color_manual(
      name = "GROUP",
      labels = uniqComb$GROUP,
      values = uniqComb$COLOR
    ) +
    scale_x_discrete(limits = orderedIDs) #  specify order on the X axis
  pg1 <- pg + theme(legend.position = "none")
  if(legend){
    pg2 <- suppressWarnings(cowplot::get_legend(pg + theme(legend.position = "right") + guides(color = guide_legend(ncol = 1))))
    imgHeight <- if (!is.null(height)) height else (5 + max(nchar(meta$SAMPLEID)) / 20)
    #legendWidth <- ifelse(max(nchar(meta$Sample_Group))<30, 1, 2)  # control the width of legend
    plots <- patchwork::wrap_plots(pg1, pg2, ncol = 1, widths = 10)  
  }else{
    plots <- pg1
    imgHeight <- if (!is.null(height)) height else 5
  }

  if (!is.null(outFile)) {
    if (!is.null(width)) {
      imgWidth <- width
      #ggsave(file = outFile, pg1, width = imgWidth, height = imgHeight, units = "in", limitsize = F)
    } else {
      imgWidth <- min(5 + ncol(beta) / 10 + nrow(beta) / 400, 45)
      #ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = T)
    }
    outFile <- paste0(tools::file_path_sans_ext(outFile), ".pdf")
    pdf(outFile,width=imgWidth, height = imgHeight)
    print(pg1)
    if(legend){
        grid.newpage()
        grid.draw(pg2)
    }
    garbage<-dev.off()
    cat("\n\t", basename(outFile), "[saved]")
  }

  #ggsave(file = outFile, pg2, width = imgWidth, height = imgHeight, units = "in", limitsize = F)
  return(plots)
}

#================================================================

BetaBeePlot_SNP <- function(beta, meta, SAMPLEID = "Sample_Name", outFile = NULL, alpha = 1, ctrlgrp="germline",low_cutoff=0.3,  high_cutoff=0.7) {
  # https://r-charts.com/distribution/ggbeeswarm/
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
    if(sum(grepl(ctrlgrp, meta$Sample_Group))==0){
     # no control group found, color dot by SAMPLE_GROUP instead of AA,AB,BB
     plot1 <- BetaBeePlot(beta, meta, SAMPLEID = SAMPLEID, outFile = outFile, alpha = alpha)
     return (plot1)
  }
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

  ctrls <- meta[grep(ctrlgrp, meta$Sample_Group),"SAMPLEID"]
  cat("\nInfo: ctrlgrp samples.", ctrls,"\n")
  if(length(ctrls)>1){
    ctrls_mean <- rowMeans(beta[,ctrls])
  }else{
    ctrls_mean <- as.numeric(beta[,ctrls])
  }
  beta <- data.frame(beta)
  breaks <- c(0, low_cutoff, high_cutoff, 1)
  labels <- c("BB", "AB", "AA")
  beta$CTL_GRP <- cut(ctrls_mean, breaks = breaks, labels = labels, include.lowest = TRUE)
  beta$Probe <- rownames(beta)
  suppressMessages({
    used <- reshape2::melt(beta, id.vars = c("Probe", "CTL_GRP"),variable.name = "ID",value.name = "value")
  })
  used$value <- as.numeric(used$value)
  meta <- meta[order(meta$Sample_Group), ] # order GROUP
  orderedIDs <- meta$SAMPLEID # order SMAPLEID by GROUP
  rownames(meta) <- as.character(meta$SAMPLEID)

  pg <- ggplot(used, aes(x = ID, y = value, color = CTL_GRP), alpha = alpha) +
    geom_quasirandom(cex = dotSize) +
    theme_classic(base_size = 10) +
    labs(y = "methylation level", x = "ID") +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1))  

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
#================================================================

#' Beeswarm Plot for a Single Chromosome by Origin
#'
#' @param beta Numeric beta matrix with probes as rows and samples as columns.
#' @param meta Sample metadata containing `SAMPLE_NAME` and grouping columns.
#' @param SAMPLEID Metadata column used as x-axis sample label.
#' @param outFile Optional output file path.
#' @param alpha Point alpha.
#' @param chr Chromosome label (e.g., `chr11`).
#' @param probeset Probeset name used for annotation lookup.
#'
#' @return A ggplot object.
BetaBeePlot_single_chr <- function(beta, meta, SAMPLEID = "Sample_Name", outFile = NULL, alpha = 0.5,chr="chr11", probeset='chr11p15') {
  # to be done
  # https://r-charts.com/distribution/ggbeeswarm/
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
  suppressMessages(suppressWarnings(library("reshape2")))
  if(!is.null(probeset)){
    probesets <- readRDS(.resolve_extdata_file("probesets_hg19.rds"))
    if (probeset %in% names(probesets)) {
      probes <- probesets[[probeset]]
    } else {
      cat("\nERROR: unavailable probeset & probes not given.\n")
      q("no")
    }
    if("ORIGIN" %in% colnames(probes)){
       anno <- probes[,c("CHR","MAPINFO","Closest_TSS_gene_name","ORIGIN")]  
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
    probes.all <- readRDS(.resolve_extdata_file("anno.uniq_harmonized.liftover.rds"))
    chr_colname <- paste0("CHR_", toupper(version))
    mapinfo <- paste0("MAPINFO_", toupper(version))
    anno <- probes.all[probes.all$NAME %in% rownames(beta), c(chr_colname, mapinfo, "UCSC_REFGENE_NAME")]
    colnames(anno) <- c("CHR", "MAPINFO", "GENE")
    anno$CATEGORY <- "NA"
  }
  anno$CHR <- paste0("chr",gsub("chr","",anno$CHR))
  chr <- paste0("chr",gsub("chr","",chr))
  idx <- anno$CHR %in% chr
  if(sum(idx) <5){
    cat("\nERROR: no matched [",chr,"] in probeset [",probeset,"]\n")
    return(NULL)
  }
  anno <- anno[anno$CHR %in% chr,]
  #print(head(anno))
  common_probes <- intersect(rownames(anno), rownames(beta))
  beta <- beta[common_probes, ]
  options(ggplot2.verbose = FALSE)
  dotSize <- 1
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
  used$value <- as.numeric(as.character(used$value))
  if(nrow(used)<5){
    stop("Not enough probes found/ matched (<5).")
  }
  cat("\n generate dotplot ...\n")
  pg <- ggplot(used, aes(x = ID, y = value, color = CATEGORY)) +
    geom_hline(yintercept = 0.5, linetype = "dashed", color = .imprint_origin_colors()["reference"]) +
    geom_quasirandom(cex = dotSize,alpha = alpha) +
    theme_classic(base_size = 10) +
    labs(y = "Methylation (Î²)", x = "ID", title = "ImprintomeR:beeswarm_chr", subtitle=paste0(probeset,":", chr) ) +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) +
    scale_color_manual(values = .imprint_origin_colors()[c("maternal", "paternal")], drop = FALSE) +
    scale_x_discrete(limits = orderedIDs) #  specify order on the X axis
  imgHeight <- 5 + max(nchar(meta$SAMPLEID)) / 20
  num_groups <- length(unique(used$CATEGORY))
 pg_sep <- ggplot(used, aes(x = interaction(ID, CATEGORY), y = value, color = CATEGORY)) +
    geom_quasirandom(size = dotSize, alpha = alpha, pch=20) + 
    stat_summary(fun = median, geom = "errorbar", aes(ymin = after_stat(y), ymax = after_stat(y)), 
                 width = 0.75, linewidth = 0.8, color="grey30") + 
    facet_wrap(~ ID, nrow = 1, scales = "free_x", strip.position = "bottom") + 
     scale_x_discrete( labels = function(x) {
       labels <- rep("", length(x))
       labels[seq(1, length(x), by = num_groups)] <- unlist(strsplit(as.character(x), "\\."))[1]
       labels
  }) +
    theme_minimal() + 
    theme_classic(base_size = 10) +
    labs(y = "Methylation Level", x = "ID",subtitle=paste0(probeset,":", chr)) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1), 
          axis.title.x = element_blank(),
          axis.ticks.x = element_blank(),
          strip.text = element_blank(), 
          strip.background = element_blank())

  outFile2 <- paste0(tools::file_path_sans_ext(outFile),"_sep.pdf")
  if (!is.null(outFile)) {
    if (ncol(beta) > 20) {
      imgWidth <- 5 + ncol(beta) / 5 + nrow(beta) / 400
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = F)
      ggsave(file = outFile2, pg_sep, width = imgWidth*1.2, height = imgHeight, units = "in", limitsize = F)
    } else {
      imgWidth <- min(5 + ncol(beta) / 10 + nrow(beta) / 400, 45)
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = T)
      ggsave(file = outFile2, pg_sep, width = imgWidth*1.2, height = imgHeight, units = "in", limitsize = F)
    }
    cat("\n\t", basename(outFile), "[saved]")
    cat("\n\t", basename(outFile2), "[saved]")
  }
  options(ggplot2.verbose = TRUE)
  return(pg)
}

#================================================================

#' Beeswarm Plot Split by Probe Category/Origin
#'
#' @param beta Numeric beta matrix with probes as rows and samples as columns.
#' @param meta Sample metadata containing `SAMPLE_NAME` and grouping columns.
#' @param SAMPLEID Metadata column used as x-axis sample label.
#' @param outFile Optional output file path.
#' @param alpha Point alpha.
#' @param probesets Optional annotation object.
#' @param useNA Logical; keep NA category values.
#' @param width,height Optional image dimensions for saving.
#' @param group Annotation column used to define categories.
#'
#' @return A ggplot object.
BetaBeePlot_orgin <- function(beta, meta, SAMPLEID = "Sample_Name", outFile = NULL, alpha = 0.5,probesets=NULL, useNA=FALSE, width=NULL, height=NULL, group="ORIGIN") {
  # https://r-charts.com/distribution/ggbeeswarm/
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
  suppressMessages(suppressWarnings(library("reshape2")))
  if(!is.null(probeset)){
    probesets <- readRDS("inst/extdata/probesets_hg19.rds")
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
      probes.all <- readRDS(.resolve_extdata_file("anno.uniq_harmonized.liftover.rds"))
    }
    chr <- paste0("CHR_", toupper(version))
    mapinfo <- paste0("MAPINFO_", toupper(version))
    anno <- probes.all[probes.all$NAME %in% rownames(beta), c(chr, mapinfo, "UCSC_REFGENE_NAME")]
    colnames(anno) <- c("CHR", "MAPINFO", "GENE")
    anno$CATEGORY <- "NA"
  }
  common_probes <- intersect(rownames(anno), rownames(beta))
  beta <- beta[common_probes, ]

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
  beta$Probe=rownames(beta)
  beta$CATEGORY= anno[common_probes,"CATEGORY"]

  suppressMessages({
    used <- reshape2::melt(beta, id.vars = c("Probe", "CATEGORY"),variable.name = "ID",value.name = "value")
  })
  if(! useNA){
     used <- used[used$CATEGORY %in% c("paternal","maternal"),]
  }
 
  #meta <- meta[order(meta$Sample_Group), ] # order GROUP
  #orderedIDs <- meta$SAMPLEID # order SMAPLEID by GROUP
  #rownames(meta) <- as.character(meta$SAMPLEID)
  used$value <- as.numeric(as.character(used$value))
  if(nrow(meta)==1){
      cat("\n generate dotplot [single sample]...\n")
      

        pg_sep <- ggplot(used, aes(x = 1, y = value, color = CATEGORY)) +
          geom_hline(yintercept = 0.5, linetype = "dashed", color = .imprint_origin_colors()["reference"]) +
          geom_quasirandom(cex = dotSize,alpha = alpha, width = 0.3) +
          stat_summary(fun = median, geom = "errorbar", aes(ymin = after_stat(y), ymax = after_stat(y)), 
          width = 0.5, linewidth = 0.7, color="grey30") + 
          facet_wrap(~ CATEGORY, nrow = 1)+
          theme_classic(base_size = 10) +
          theme(axis.text.x = element_blank(),axis.ticks.x = element_blank(),
          panel.border = element_rect(color = "grey20", fill = NA, linewidth = 0.5)) +
          labs(y = "Methylation (Î²)", x = "GROUP", title=newIDs) +
          scale_color_manual(values = .imprint_origin_colors()[c("maternal", "paternal")], drop = FALSE) +
          theme(legend.position = "none")

        pg_sep_style0 <- ggplot(used, aes(x = CATEGORY, y = value, color = CATEGORY)) +
          geom_quasirandom(cex = dotSize,alpha = alpha, width = 0.25) +
          stat_summary(fun = median, geom = "errorbar", aes(ymin = after_stat(y), ymax = after_stat(y)), 
          width = 0.5, linewidth = 0.7, color="grey30") + 
          theme_classic(base_size = 10) +
          labs(y = "methylation level", x = group, title=newIDs) +
          theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) +
          theme(legend.position = "none")

      imgWidth <-  ifelse(is.null(width), 2, as.numeric(width))
      imgWidth <-  ifelse(!useNA, imgWidth*3/4, imgWidth)
      imgHeight <-  ifelse(is.null(height), 4, as.numeric(height))
      outFile2 <- paste0(tools::file_path_sans_ext(outFile),"_sep.pdf")
      ggsave(file = outFile2, pg_sep, width = imgWidth*1.2, height = imgHeight, units = "in", limitsize = F)
      cat("\n\t", basename(outFile2), "[saved]")
      return(pg_sep)
  }else{
    cat("\n generate dotplot [cohort]...\n")
      pg <- ggplot(used, aes(x = ID, y = value, color = CATEGORY)) +
        geom_hline(yintercept = 0.5, linetype = "dashed", color = .imprint_origin_colors()["reference"]) +
        geom_quasirandom(cex = dotSize,alpha = alpha) +
        theme_classic(base_size = 10) +
        facet_wrap(~CATEGORY, scales = "free_x") +
        labs(y = "Methylation (Î²)", x = "ID", title = "ImprintomeR:beeswarm_origin") +
        scale_color_manual(values = .imprint_origin_colors()[c("maternal", "paternal")], drop = FALSE) +
        theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
              # Optional: hide the legend since the facet labels now show the category
              legend.position = "none")
        #scale_x_discrete(limits = orderedIDs) #  specify order on the X axis
      #pg1 <- pg + theme(legend.position = "none")
      #pg2 <- cowplot::get_legend(pg + theme(legend.position = "right") + guides(color = guide_legend(ncol = 1)))
      if(is.null(height)){
        imgHeight <- 5 + max(nchar(meta$SAMPLEID)) / 20
      }else{
        imgHeight <- as.numeric(height)
      }
      #plots <- patchwork::wrap_plots(pg1, pg2, ncol = 2, widths = c(5, 2))
      #plots <- cowplot::plot_grid(pg1, pg2, ncol = 2, rel_widths = c(8, 1))
      num_groups <- length(unique(used$CATEGORY))
    pg_sep <- ggplot(used, aes(x = interaction(ID, CATEGORY), y = value, color = CATEGORY)) +
        geom_quasirandom(size = dotSize, alpha = alpha, pch=20) + 
        stat_summary(fun = median, geom = "errorbar", aes(ymin = after_stat(y), ymax = after_stat(y)), 
                    width = 0.75, linewidth = 0.8, color="grey30") + 
        facet_wrap(~ ID, nrow = 1, scales = "free_x", strip.position = "bottom") + 
        scale_x_discrete( labels = function(x) {
          labels <- rep("", length(x))
          labels[seq(1, length(x), by = num_groups)] <- unlist(strsplit(as.character(x), "\\."))[1]
          labels
      }) +
        theme_minimal() + 
        theme_classic(base_size = 10) +
        labs(y = "Methylation Level", x = "ID") +
        theme(axis.text.x = element_text(angle = 90, hjust = 1), 
              axis.title.x = element_blank(),
              axis.ticks.x = element_blank(),
              strip.text = element_blank(), 
              strip.background = element_blank())

  }
  
  outFile2 <- paste0(tools::file_path_sans_ext(outFile),"_sep.pdf")
  if (!is.null(outFile)) {
    if (ncol(beta) > 20) {
      if(is.null(width)){
        imgWidth <- 5 + ncol(beta) / 5 + nrow(beta) / 400
      }else{
        imgWidth <- as.numeric(width)
      }
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = F)
      ggsave(file = outFile2, pg_sep, width = imgWidth*1.2, height = imgHeight, units = "in", limitsize = F)
    } else {
      if(is.null(width)){
        imgWidth <- min(5 + ncol(beta) / 10 + nrow(beta) / 400, 45)
      }else{
        imgWidth <-  as.numeric(width)
      }
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = T)
      ggsave(file = outFile2, pg_sep, width = imgWidth*1.2, height = imgHeight, units = "in", limitsize = F)
    }
    cat("\n\t", basename(outFile), "[saved]")
    cat("\n\t", basename(outFile2), "[saved]")
  }
  options(ggplot2.verbose = TRUE)
  return(pg)
}

##################################################################

BetaBeeswarm_chr <- function(beta, meta = NULL, SAMPLEID = "Sample_Name", outFile = NULL, probesets=NULL, pdfFolder='pdf'){
  # Load required libraries
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
  library(reshape2)
  resolved <- .resolve_beta_meta_inputs(beta, meta, require_meta = TRUE)
  beta <- resolved$beta
  meta <- resolved$meta

  #================================================================
  # prepare chromosome
  beta <- as.data.frame(beta)
  if(!is.null(probesets)){
    probesets <- readRDS("inst/extdata/probesets_hg19.rds")
    if (probeset %in% names(probesets)) {
      probes <- probesets[[probeset]]
    } else {
      cat("\nERROR: unavailable probeset & probes not given.\n")
      q("no")
    }
    anno <- probes[,c("CHR","MAPINFO","Closest_TSS_gene_name")]   
    colnames(anno)[3] <- "GENE"
    rownames(anno) <- probes$NAME
  }else{
    version <- "HG19"
    # load aggregated annotation object
    probes.all <- readRDS(.resolve_extdata_file("anno.uniq_harmonized.liftover.rds"))
    chr <- paste0("CHR_", toupper(version))
    mapinfo <- paste0("MAPINFO_", toupper(version))
    anno <- probes.all[probes.all$NAME %in% rownames(beta), c(chr, mapinfo, "UCSC_REFGENE_NAME")]
    colnames(anno) <- c("CHR", "MAPINFO", "GENE")
  }
  common_probes <- intersect(rownames(anno), rownames(beta))
  beta <- beta[common_probes, ]
  #================================================================
  # prepare plot title
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
  #================================================================
  beta$Probe <- rownames(beta)
  beta$Chromosome <-  anno[common_probes,"CHR"]

  # Melt the data for plotting
  beta_melt <- melt(beta, id.vars = c("Probe", "Chromosome"))
  dotSize <- 1; alpha=0.5
  plots <- list()
  # Generate beeswarm plots by chromosome for each sample
  if(! pdfFolder %in% c(NULL, FALSE)){
      outDir <- paste0(dirname(outFile),"/",pdfFolder)
      if(dir.exists(outDir)){
        pdfFolder <- FALSE  # "SKIP" to run because folder exists
      }
      dir.create(outDir, showWarnings = FALSE)
  }
  imgHeight <- 4
  imgWidth <- 10
  pdf(outFile, width = imgWidth, height = imgHeight)
  for (sample in unique(beta_melt$variable)) {
    cat("\n\t", sample)
    sample_data <- subset(beta_melt, variable == sample)
    chr_levels <- stringr::str_sort(unique(sample_data$Chromosome), numeric = TRUE) 
    sample_data$Chromosome <- factor(sample_data$Chromosome, levels=chr_levels)

    pg <- ggplot(sample_data, aes(x = 1, y = value), alpha = alpha) +
      geom_quasirandom(cex = dotSize) +
      facet_wrap(~ Chromosome, nrow = 1) +  theme_classic(base_size = 10) + ggtitle(label = sample) +
      labs(y = "methylation level", x = "Chromosome") + ylim(0, 1)+
      geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey40",linewidth = 0.5) +
      geom_hline(yintercept = c(0.3,0.7), linetype ="dotted", color = "grey60",linewidth = 0.5) +
      theme(axis.text.x = element_blank(),axis.ticks.x = element_blank(),
      panel.border = element_rect(color = "grey20", fill = NA, linewidth = 0.5)) 
     if(! pdfFolder %in% c(NULL, FALSE)){ # plot individual sample to seperate file
        pdfFile<- paste0(outDir,"/",sample,".jpg")
        ggsave(file=pdfFile,pg,width=10,height=4,units="in", limitsize = TRUE)
     }
    print(pg)
  }
  garbage <- dev.off()
  cat("\n\t", basename(outFile), "[saved]")
}

##################################################################
# 03/04/2025, 10:27:24

BetaBeeswarm_chr_color <- function(beta, meta, SAMPLEID = "Sample_Name", outFile = NULL, probesets=NULL,pdfFolder=FALSE){
  # Load required libraries
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
  suppressMessages(suppressWarnings(library(reshape2)))

  #================================================================
  # prepare chromosome
  if(!is.null(probeset)){
    probesets <- readRDS("inst/extdata/probesets_hg19.rds")
    if (probeset %in% names(probesets)) {
      probes <- probesets[[probeset]]
    } else {
      cat("\nERROR: unavailable probeset & probes not given.\n")
      q("no")
    }
    if("ORIGIN" %in% colnames(probes)){
       anno <- probes[,c("CHR","MAPINFO","Closest_TSS_gene_name","ORIGIN")]  
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
      probes.all <- readRDS(.resolve_extdata_file("anno.uniq_harmonized.liftover.rds"))
    }
    chr <- paste0("CHR_", toupper(version))
    mapinfo <- paste0("MAPINFO_", toupper(version))
    anno <- probes.all[probes.all$NAME %in% rownames(beta), c(chr, mapinfo, "UCSC_REFGENE_NAME")]
    colnames(anno) <- c("CHR", "MAPINFO", "GENE")
    anno$CATEGORY <- "NA"
  }
  common_probes <- intersect(rownames(anno), rownames(beta))
  beta <- beta[common_probes, ]
  #================================================================
  # prepare plot title
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
  #================================================================
  beta$Probe <- rownames(beta)
  beta$Chromosome <-  anno[common_probes,"CHR"]
  beta$CATEGORY <-  anno[common_probes,"CATEGORY"]
  # Melt the data for plotting
  beta_melt <- melt(beta, id.vars = c("Probe", "Chromosome","CATEGORY"))

  dotSize <- 1; alpha=0.5
  plots <- list()
  if(! pdfFolder %in% c(NULL, FALSE)){
      outDir <- paste0(dirname(outFile),"/",pdfFolder)
      if(dir.exists(outDir)){
        pdfFolder <- FALSE  # "SKIP" to run because folder exists
      }
      dir.create(outDir, showWarnings = FALSE)
  }
  imgHeight <- 4
  imgWidth <- 10
  pdf(outFile, width = imgWidth, height = imgHeight)
  for (sample in unique(beta_melt$variable)) {
    cat("\n\t", sample)
    sample_data <- subset(beta_melt, variable == sample)
    chr_levels <- stringr::str_sort(unique(sample_data$Chromosome), numeric = TRUE) 
    sample_data$Chromosome <- factor(sample_data$Chromosome, levels=chr_levels)
    #pg0 <- ggplot(sample_data, aes(x = Chromosome, y = value), alpha = alpha) +
    #  geom_quasirandom(cex = dotSize) +
    #  theme_classic(base_size = 10) + ggtitle(label = sample) +
    #  labs(y = "methylation level", x = "Chromosome") +
    #  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1))  
    pg <- ggplot(sample_data, aes(x = 1, y = value,color=CATEGORY), alpha = alpha) +
      geom_quasirandom(cex = dotSize) +
      facet_wrap(~ Chromosome, nrow = 1) +  theme_classic(base_size = 10) + ggtitle(label = sample) +
      labs(y = "methylation level", x = "Chromosome") + ylim(0, 1)+
      geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey40",linewidth = 0.5) +
      geom_hline(yintercept = c(0.3,0.7), linetype ="dotted", color = "grey60",linewidth = 0.5) +
      theme(axis.text.x = element_blank(),axis.ticks.x = element_blank(),
      panel.border = element_rect(color = "grey20", fill = NA, linewidth = 0.5)) 
       if(! pdfFolder %in% c(NULL, FALSE)){ 
       pdfFile<- paste0(outDir,"/",sample,".jpg")
       ggsave(file=pdfFile,pg,width=10,height=4,units="in", limitsize = TRUE)
     }
    print(pg)
  }
  garbage <- dev.off()
  cat("\n\t", basename(outFile), "[saved]")
}
##################################################################


##################################################################

BetaHeatmap <- function(beta, meta = NULL, SAMPLEID = "Sample_Name", annoColumn = "Sample_Group", clusterRows = TRUE, clusterColumns = TRUE, 
   outFile = NULL, imgSizeFactor=0.5) {
  suppressMessages(library(circlize))
  suppressMessages(library(ComplexHeatmap))
  suppressMessages(library(edgeR))
  suppressMessages(library(RColorBrewer))
  resolved <- .resolve_beta_meta_inputs(beta, meta, require_meta = TRUE)
  beta <- resolved$beta
  meta <- resolved$meta

  if( SAMPLEID != "Sample_Name"){
     cat("\nINFO: use alternative label.",SAMPLEID ,"\n")
  }
  TargetIDs <- rownames(beta)
  validIds <- intersect(meta$Sample_Name, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  if (length(validIds) > 0) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$Sample_Name. \n")
    return(NULL)
  }
  colnames(beta) <- meta$SAMPLEID

  # Ensure Sample_Group exists; create if missing
  if (!"Sample_Group" %in% colnames(meta)) {
    meta$Sample_Group <- "All"
  }
  # Ensure annoColumn exists; fallback to Sample_Group if missing
  if (!annoColumn %in% colnames(meta)) {
    annoColumn <- "Sample_Group"
  }
  
  meta <- meta[order(meta$Sample_Group), ] # order GROUP
  beta <- beta[, as.character(meta$SAMPLEID)] # order SMAPLEID by GROUP
  rownames(meta) <- as.character(meta$SAMPLEID)

  if (!"COLOR" %in% colnames(meta)) {
    groupNum <- length(unique(meta$Sample_Group))
    usedColors <- standardColors()[1:groupNum]
    meta$COLOR <- usedColors[as.integer(as.factor(meta$Sample_Group))]
  }

  pheno <- intersect(annoColumn, colnames(meta))
  annotation <- data.frame(meta[, pheno])
  colnames(annotation) <- pheno
  rownames(annotation) <- meta$SAMPLEID
  used <- na.omit(beta) # remove NA 7/13/2022
  used <- used[rowSums(abs(used)) > 0, ] # remove rows with all 0s 7/13/2022, 5/25/2023
  anno_colors <- list()
  for (i in 1:ncol(annotation)) {
    if (colnames(annotation)[i] != "Sample_Group") { # convert to factor
      annotation[, i] <- factor(annotation[, i])
    }
    myColors <- standardColors()[as.integer(as.factor(annotation[, i]))]
    anno_colors[[i]] <- setNames(unique(myColors), unique(annotation[, i]))
  }
  names(anno_colors) <- colnames(annotation) # named list
  # print(anno_colors)
  # print(annotation)
  # print(meta)
  # print(colnames(used))
  # Create heatmap annotation with auto legend
  top_ha <- HeatmapAnnotation(
    df = annotation,
    col = anno_colors,
    annotation_name_side = "right"
  )
  minimum <- min(used)
  maximum <- max(used)
  bk <- unique(c(
    seq(minimum, maximum / 3, length = 30),
    seq(maximum / 3, maximum * 2 / 3, length = 30),
    seq(maximum * 2 / 3, maximum, length = 30)
  ))
  # redblue
  hmCols0 <- colorRampPalette(c("#083160", "#2668AA", "#4794C1", "#94C5DD", "#D2E5EF", "#F7F7F7", "#FCDBC8", "#F2A585", "#D46151", "#B01B2F", "#660220"))
  distMethod <- 1
  hmCols <- hmCols0(length(bk) - 1)
  if (clusterRows) {
    dd <- dist(used, method = "euclidean")
    cluster_rows <- hclust(dd, method = "ward.D") # complete
    row_dend <- TRUE
  } else {
    row_dend <- FALSE
    cluster_rows <- FALSE
  }
  cluster_cols <- clusterColumns
  row_ha <- NULL
  plotWidth <- 5 + log10(ncol(used)+1) * 6
  plotHeight <- 5 + log10(nrow(used)+1) * 7
  fontsize <- (18 - log2(nrow(used)+1)) / 2
  legend_key_title <- "Methylation"
  
  if(! clusterRows){ # sort by rowname
    library(stringr)
    used <- used[str_order(rownames(used), numeric = TRUE), ]
  }
  hm <- Heatmap(as.matrix(used),
    column_dend_height = unit(6, "mm"), col = hmCols, cluster_rows = cluster_rows,
    show_row_dend = row_dend, show_column_dend = cluster_cols, cluster_columns = cluster_cols, border = "grey",
    show_row_names = T, show_column_names = T, name = legend_key_title, clustering_distance_rows = "euclidean",
    clustering_method_rows = "ward.D",
    top_annotation = top_ha, row_names_gp = gpar(fontsize = fontsize), column_names_gp = gpar(fontsize = fontsize),
    right_annotation = row_ha
  )
  if (!is.null(outFile)) {
    outFile <- paste0(tools::file_path_sans_ext(outFile), ".pdf") # make sure its extension is pdf
    pdf(outFile, width = plotWidth*imgSizeFactor, height = plotHeight*imgSizeFactor)
    ht <- draw(hm, merge_legend = T)
    garbage <- dev.off()
    cat("\n\t", basename(outFile), "[saved]")
  }
}

##################################################################

#' Heatmap of Beta Values Aggregated by Gene Symbol
#'
#' Aggregates probe-level beta values to gene-level means by `Closest_TSS_gene_name`
#' from the selected probeset, then generates a heatmap visualization. Genes with
#' the same symbol are aggregated via median across probes.
#'
#' @param beta Numeric beta matrix/data.frame with probe IDs as row names and
#'   samples as columns.
#' @param meta Optional sample metadata data frame with `Sample_Name` and
#'   `Sample_Group` columns.
#' @param probeset Character probeset key (default `"selected"`).
#'   Must be present in `inst/extdata/probesets_hg19.rds`.
#' @param SAMPLEID Metadata column name used as sample label in heatmap
#'   (default `"Sample_Name"`).
#' @param annoColumn Annotation column for heatmap top annotation
#'   (default `"Sample_Group"`).
#' @param clusterRows Logical; cluster genes (rows) hierarchically
#'   (default `TRUE`).
#' @param clusterColumns Logical; cluster samples (columns) hierarchically
#'   (default `TRUE`).
#' @param outFile Optional output PDF file path. If provided, heatmap is saved
#'   to disk.
#' @param imgSizeFactor Numeric scaling factor for saved image dimensions
#'   (default `0.5`).
#'
#' @return Invisibly returns the `ComplexHeatmap::Heatmap` object (or NULL if
#'   no output file and function exits silently).
#'
#' @details
#' **Aggregation Logic:**
#' Probes are matched to the selected probeset by `NAME`. Probes are grouped by
#' their `Closest_TSS_gene_name` annotation. Beta values within each gene are
#' aggregated per sample using the median function, producing one row per unique
#' gene symbol.
#'
#' **Colors & Annotations:**
#' Uses a red-blue color palette spanning the observed beta range. Sample groups
#' are annotated at the top with automatic color assignment via `standardColors()`.
#'
#' **Clustering:**
#' If `clusterRows = TRUE`, genes are clustered via Euclidean distance and
#' Ward linkage. If `clusterRows = FALSE`, genes are sorted by their row names.
#'
#' @examples
#' \dontrun{
#'   # Load beta and metadata
#'   beta <- LoadBeta("beta.txt")
#'   meta <- LoadMeta("meta.txt")
#'
#'   # Generate gene-level heatmap
#'   BetaHeatmapByGene(beta, meta, probeset = "selected",
#'     outFile = "gene_heatmap.pdf")
#' }
#'
#' @export
BetaHeatmapByGene <- function(beta, meta = NULL, probeset = "selected",
                              SAMPLEID = "Sample_Name", annoColumn = "Sample_Group",
                              clusterRows = TRUE, clusterColumns = TRUE,
                              outFile = NULL, imgSizeFactor = 0.5) {
  suppressMessages(library(circlize))
  suppressMessages(library(ComplexHeatmap))
  suppressMessages(library(edgeR))
  suppressMessages(library(RColorBrewer))
  suppressMessages(library(dplyr))
  suppressMessages(library(stringr))

  # Resolve input
  resolved <- .resolve_beta_meta_inputs(beta, meta, require_meta = TRUE)
  beta <- resolved$beta
  meta <- resolved$meta

  # Load probeset and aggregate by gene
  probesets <- readRDS(.resolve_extdata_file("probesets_hg19.rds"))
  if (!(probeset %in% names(probesets))) {
    stop("Unavailable probeset: ", probeset)
  }
  probeset_df <- probesets[[probeset]]
  required_cols <- c("NAME", "Closest_TSS_gene_name")
  missing_cols <- setdiff(required_cols, colnames(probeset_df))
  if (length(missing_cols) > 0) {
    stop("Probeset missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Match probes and aggregate by gene
  common_probes <- intersect(rownames(beta), probeset_df$NAME)
  if (length(common_probes) == 0) {
    stop("No probes match between beta and probeset.")
  }

  beta_sub <- beta[common_probes, , drop = FALSE]
  gene_map <- setNames(probeset_df$Closest_TSS_gene_name, probeset_df$NAME)
  genes <- gene_map[common_probes]

  # Aggregate by gene using median
  unique_genes <- unique(genes)
  beta_agg <- as.data.frame(matrix(NA, nrow = length(unique_genes), ncol = ncol(beta_sub)))
  rownames(beta_agg) <- unique_genes
  colnames(beta_agg) <- colnames(beta_sub)

  for (gene in unique_genes) {
    idx <- which(genes == gene)
    if (length(idx) == 1) {
      beta_agg[gene, ] <- beta_sub[idx, ]
    } else {
      beta_agg[gene, ] <- apply(beta_sub[idx, , drop = FALSE], 2, median, na.rm = TRUE)
    }
  }

  beta_agg <- as.matrix(beta_agg)

  # Prepare samples
  validIds <- intersect(meta$Sample_Name, colnames(beta_agg))
  if (length(validIds) == 0) {
    stop("No samples match between beta and meta.")
  }
  meta$SAMPLEID <- meta[, SAMPLEID]
  meta <- meta[validIds, ]
  beta_agg <- beta_agg[, validIds]
  colnames(beta_agg) <- meta$SAMPLEID

  # Ensure Sample_Group exists
  if (!"Sample_Group" %in% colnames(meta)) {
    meta$Sample_Group <- "All"
  }
  if (!annoColumn %in% colnames(meta)) {
    annoColumn <- "Sample_Group"
  }

  # Order by group
  meta <- meta[order(meta$Sample_Group), ]
  beta_agg <- beta_agg[, as.character(meta$SAMPLEID)]
  rownames(meta) <- as.character(meta$SAMPLEID)

  # Assign colors if needed
  if (!"COLOR" %in% colnames(meta)) {
    groupNum <- length(unique(meta$Sample_Group))
    usedColors <- standardColors()[1:groupNum]
    meta$COLOR <- usedColors[as.integer(as.factor(meta$Sample_Group))]
  }

  # Prepare annotation
  pheno <- intersect(annoColumn, colnames(meta))
  annotation <- data.frame(meta[, pheno])
  colnames(annotation) <- pheno
  rownames(annotation) <- meta$SAMPLEID

  # Remove all-NA genes and all-zero genes
  used <- na.omit(beta_agg)
  used <- used[rowSums(abs(used)) > 0, ]

  if (nrow(used) == 0) {
    stop("No valid genes after filtering NA and zero-only rows.")
  }

  # Prepare colors
  anno_colors <- list()
  for (i in 1:ncol(annotation)) {
    if (colnames(annotation)[i] != "Sample_Group") {
      annotation[, i] <- factor(annotation[, i])
    }
    myColors <- standardColors()[as.integer(as.factor(annotation[, i]))]
    anno_colors[[i]] <- setNames(unique(myColors), unique(annotation[, i]))
  }
  names(anno_colors) <- colnames(annotation)

  # Create heatmap annotation with auto legend
  top_ha <- HeatmapAnnotation(
    df = annotation,
    col = anno_colors,
    annotation_name_side = "right"
  )

  # Define color scale
  minimum <- min(used, na.rm = TRUE)
  maximum <- max(used, na.rm = TRUE)
  bk <- unique(c(
    seq(minimum, maximum / 3, length = 30),
    seq(maximum / 3, maximum * 2 / 3, length = 30),
    seq(maximum * 2 / 3, maximum, length = 30)
  ))

  hmCols0 <- colorRampPalette(c("#083160", "#2668AA", "#4794C1", "#94C5DD", "#D2E5EF", "#F7F7F7", "#FCDBC8", "#F2A585", "#D46151", "#B01B2F", "#660220"))
  hmCols <- hmCols0(length(bk) - 1)

  # Clustering
  if (clusterRows) {
    dd <- dist(used, method = "euclidean")
    cluster_rows <- hclust(dd, method = "ward.D")
    row_dend <- TRUE
  } else {
    row_dend <- FALSE
    cluster_rows <- FALSE
    used <- used[str_sort(rownames(used), numeric = TRUE), ]
  }

  cluster_cols <- clusterColumns

  # Dimensions
  plotWidth <- 5 + log10(ncol(used) + 1) * 6
  plotHeight <- 5 + log10(nrow(used) + 1) * 7
  fontsize <- (18 - log2(nrow(used) + 1)) / 2

  # Create heatmap
  hm <- Heatmap(as.matrix(used),
    column_dend_height = unit(6, "mm"),
    col = hmCols,
    cluster_rows = cluster_rows,
    show_row_dend = row_dend,
    show_column_dend = cluster_cols,
    cluster_columns = cluster_cols,
    border = "grey",
    show_row_names = TRUE,
    show_column_names = TRUE,
    name = "Methylation",
    clustering_distance_rows = "euclidean",
    clustering_method_rows = "ward.D",
    top_annotation = top_ha,
    row_names_gp = gpar(fontsize = fontsize),
    column_names_gp = gpar(fontsize = fontsize)
  )

  # Save if needed
  if (!is.null(outFile)) {
    outFile <- paste0(tools::file_path_sans_ext(outFile), ".pdf")
    pdf(outFile, width = plotWidth * imgSizeFactor, height = plotHeight * imgSizeFactor)
    ht <- draw(hm, merge_legend = TRUE)
    garbage <- dev.off()
    cat("\n\t", basename(outFile), "[saved]")
  }

  invisible(hm)
}

##################################################################

#' Circular Heatmap of Beta Values
#'
#' Generates a circular/radial heatmap visualization of beta values using
#' ComplexHeatmap and circlize packages.
#'
#' @param beta Matrix or data.frame of beta values (rows = probes, columns = samples).
#' @param meta Optional data.frame of sample metadata with `SAMPLEID` column.
#' @param probes.all Optional probe annotation data.
#' @param probeset Character scalar for probeset name or NULL.
#' @param version Character genome version (default "HG19").
#' @param SAMPLEID Column name for sample identifiers (default "Sample_Name").
#' @param sectionColumn Column name for grouping samples into sections. Use "Sample_Name"
#'   to show each sample as its own section, or "Sample_Group" to group multiple samples.
#'   Circular heatmaps work best with 1-5 sections.
#' @param sectionLabels Optional custom section labels.
#' @param outFile Optional output PDF file path.
#' @param nchars Number of characters to show in gene labels (default 5).
#'   Note: This applies to gene names only, not group labels which are shown in full.
#'
#' @details
#' **Crowding considerations:**
#' - Circular heatmaps are optimized for small numbers of samples (1-5 per section).
#' - For 5-10+ samples per section, consider using `plot_type = "heatmap_by_probe"` instead
#'   (rectangular heatmap) which handles many samples better.
#' - Each section represents a unique value in `sectionColumn`.
#'
#' @return Invisibly returns the heatmap object.
#' @export
BetaCircularHeatmap <- function(beta, meta = NULL, probes.all = NULL,probeset=NULL, version = "HG19", SAMPLEID = "Sample_Name", sectionColumn = "Sample_Group", sectionLabels = NULL, outFile = NULL, nchars = 5) {
  # values of SAMPLEID column, sectionColumn must be present in meta column names
  #
  library(ComplexHeatmap)
  # https://jokergoo.github.io/circlize_book/book/circos-heatmap.html
  library(circlize)
  library("colorRamp2")
  library(grid)
  library(gridBase)
  resolved <- .resolve_beta_meta_inputs(beta, meta, require_meta = TRUE)
  beta <- resolved$beta
  meta <- resolved$meta

  circos.heatmap.get.x <- function(row_ind) {
    # https://github.com/jokergoo/circlize/blob/master/R/circos.heatmap.R
    # https://jokergoo.github.io/2022/07/29/add-labels-to-circular-heatmap/
    env <- circos.par("__tempenv__")
    split <- env$circos.heatmap.split

    row_ind_lt <- split(row_ind, split[row_ind])
    row_ind_lt <- row_ind_lt[sapply(row_ind_lt, length) > 0]

    x <- NULL
    for (i in row_ind_lt) {
      subset <- get.cell.meta.data("subset", sector.index = split[i[1]])
      order <- get.cell.meta.data("row_order", sector.index = split[i[1]])

      x <- c(x, which((1:length(split))[subset][order] %in% i))
    }
    df <- data.frame(
      sector = rep(names(row_ind_lt), times = sapply(row_ind_lt, length)),
      x = x - 0.5, row_ind = unlist(row_ind_lt)
    )
    rownames(df) <- NULL
    df
  }
  col_meth <- colorRamp2(c(0, 0.5, 1), c("blue", "white", "red"))
  lgd_meth <- ComplexHeatmap::Legend(title = "Methylation", col_fun = col_meth)
  circlize_plot <- function(beta_list, beta_anno, sectionLabels = NULL, colors = col_meth, track_height = NULL) {
    if (is.null(sectionLabels)) {
      sectionLabels <- names(beta_list)
    }
    # Adaptive track height based on number of groups for better label spacing
    if (is.null(track_height)) {
      track_height <- max(0.10, 0.035 * length(beta_list))
    }
    probe_info <- data.frame(beta_anno[, c("CHR", "MAPINFO", "GENE")])
    probe_info$CHR <- factor(probe_info$CHR, levels = unique(probe_info$CHR))
    sectors <- probe_info$CHR
    print(head(probe_info))
    n <- length(unique(sectors))
    dat1 <- beta_list[[1]]
    #print(head(dat1))
    circos.par(start.degree = 75, gap.after = c(rep(1, n - 1), 30)) # ,track.margin = c(.01,0.01))
    circos.heatmap.initialize(dat1, cluster = FALSE, split = probe_info$CHR)

    # chr layer
    circos.track(sectors,
      ylim = c(0, 1), track.height = track_height,
      bg.border = NA, panel.fun = function(x, y) {
        xlim <- get.cell.meta.data("xlim")
        ylim <- get.cell.meta.data("ylim")
        circos.text(mean(xlim), min(ylim), get.cell.meta.data("sector.index"), facing = "reverse.clockwise", col = "blue", cex = 1, niceFacing = TRUE)
      }
    )
    ## line
    circos.track(sectors,
      ylim = c(1, 2), track.height = track_height,
      bg.border = NA, panel.fun = function(x, y) {
        xlim <- get.cell.meta.data("xlim")
        ylim <- get.cell.meta.data("ylim")
        circos.segments(min(xlim), mean(ylim), max(xlim), mean(ylim), lwd = 1.5) # circos.segments(x1,y,x2,y)
      }
    )
    # gene symbol layer
    idx <- !duplicated(probe_info$GENE)
    geneSymbols <- probe_info$GENE[idx]

    pos <- circos.heatmap.get.x(seq_len(nrow(dat1)))
    circos.labels(pos$sector[idx], x = pos$x[idx], labels = geneSymbols, side = "outside", cex = 0.8) #
    print(sectionLabels)
    print(head(pos))
    # Adaptive font size for section labels based on number of groups
    section_cex <- min(1.2, 0.8 + 0.08 * length(beta_list))
    for (i in seq(length(beta_list))) {
      cat("\nINFO: process section #", i, sectionLabels[i], "\n")
      dat <- beta_list[[i]]
      # dat <- apply(dat, 2, as.numeric)
      circos.heatmap(dat, cluster = FALSE, col = colors, split = probe_info$CHR, track.height = track_height)
      circos.track(track.index = get.current.track.index(), panel.fun = function(x, y) {
        xlim <- get.cell.meta.data("xlim")
        ylim <- get.cell.meta.data("ylim")
        if (CELL_META$sector.numeric.index == n) { # the last sector
          n <- ncol(dat)
          # Adaptive offset: increases spacing for more sections
          offset <- max(2, 10 - i * 2)
          circos.text(max(xlim) + convert_x(offset, "mm"),
            mean(ylim), sectionLabels[i],
            cex = section_cex, adj = c(0, 0.5), col = "blue", facing = "bending.inside"
          )
        }
      }, bg.border = NA)
    }
  }
  # only keep common samples present in both meta and beta matrix
  rownames(meta) <- meta[, SAMPLEID]
  commonIDs <- intersect(colnames(beta), rownames(meta))
  beta <- beta[, commonIDs]
  meta <- meta[commonIDs, ]
  if(!is.null(probeset)){
    probesets <- readRDS(.resolve_extdata_file("probesets_hg19.rds"))
    if (probeset %in% names(probesets)) {
      probes <- probesets[[probeset]]
    } else {
      cat("\nERROR: unavailable probeset & probes not given.\n")
      q("no")
    }
    anno <- probes[,c("CHR","MAPINFO","Closest_TSS_gene_name")]   
    colnames(anno)[3] <- "GENE"
    rownames(anno) <- probes$NAME
  }else{
    # load aggregated annotation object
    if (is.null(probes.all)) {
      probes.all <- readRDS(.resolve_extdata_file("anno.uniq_harmonized.liftover.rds"))
    }
    chr <- paste0("CHR_", toupper(version))
    mapinfo <- paste0("MAPINFO_", toupper(version))
    anno <- probes.all[probes.all$NAME %in% rownames(beta), c(chr, mapinfo, "UCSC_REFGENE_NAME")]
    colnames(anno) <- c("CHR", "MAPINFO", "GENE")
  }
  # merge beta and anno matrix, sort by chr_mapinfo
  beta_anno <- merge(x = beta, y = anno, by = "row.names", all = FALSE) #Inner join #all.x = TRUE)
  beta_anno <- na.omit(beta_anno)
  cat("\nINFO:  number of annotated probes is ", dim(beta_anno)[1],"\n")
  names(beta_anno)[names(beta_anno) == "Row.names"] <- "TargetID"

  beta_anno$tmp <- paste0(beta_anno$CHR, "_", beta_anno$MAPINFO)
  sorted <- stringr::str_sort(beta_anno$tmp, numeric = TRUE)
  beta_anno <- beta_anno[match(sorted, beta_anno$tmp), ]
  rownames(beta_anno) <- beta_anno$TargetID
  beta_anno$tmp <- NULL

  # prepare beta_list
  grpLabels <- unique(meta[, sectionColumn])
  ngroups <- length(grpLabels)
  print(grpLabels)
  beta_list <- list()
  for (x in seq(ngroups)) {
    grpLabel <- grpLabels[x]
    beta_list[[x]] <- beta[rownames(beta_anno), rownames(meta)[meta[, sectionColumn] %in% grpLabel], drop = FALSE]
  }
  # Use full group labels (don't truncate) - replace underscores with spaces for readability
  names(beta_list) <- gsub("_", " ", trimws(grpLabels))

  # generate circular heatmap
  circle_size <- unit(1, "snpc")
  if (is.null(outFile)) {
    timeStamp <- substr(strtrim(gsub("[-: ]", "", Sys.time()), 16), 5, 12) # "11301304"
    outFile <- paste0("circular_heatmap_", timeStamp, ".pdf")
  }
  
  # Clear any previous circos state AFTER setting up parameters
  circos.clear()
  
  pdf(outFile, width = 12, height = 10)  # Larger canvas: 12x10 inches
  # Initialize base graphics system explicitly to avoid blank pages
  plot.new()
  
  pushViewport(viewport(
    x = 0.05, y = 0.5, width = circle_size, height = circle_size,
    just = c("left", "center")
  ))
  par(omi = gridOMI(), new = TRUE)  # new = TRUE to allow overwriting plot.new()
  circlize_plot(beta_list, beta_anno, colors = col_meth, track_height = 0.1)
  upViewport()
  draw(lgd_meth, x = unit(1.2, "npc"), just = "left")
  garbage <- dev.off()
  cat("\n\t", basename(outFile), "[saved]\n")
  # system(paste0("ls ", outFile, ">pdf.lst"))
  #system(" pdf2jpg.sh -i pdf.lst -o jpg")
}


##################################################################

VennDiagram <- function(vennList,setNames=NULL, style="venn", prefix=NULL){
    library("Vennerable")
    library("venn")
    library("UpSetR")
    #style: Vennerable, venn,UpSetR
    cat("\nvennList=", length(vennList))
    if(!is.null(setNames)){
      names(vennList) <- setNames
    }
    style <- tolower(style)
    plot <- NULL
    pdfFile<- paste0(prefix,"_venndiagram_",style,".pdf")
    if (length(vennList) >1) {
     pdf(pdfFile,width=10, height = 6)
     if (style =="venn") {
          plot <- venn::venn(vennList, zcolor = "style", cexsn = 0.7, cexil =0.8,ilcs = 1.5, sncs =2, plotsize=20, box = FALSE)
          # ilabels = "counts", NULL
          # ilcs: size for the intersection labels
          # sncs: size for the set names
          #print(plot)
        }else if (style =="upsetr"){
          plot <- upset(fromList(vennList),
                nsets = length(vennList), order.by = "freq",
                sets.bar.color = "#56B4E9",
                number.angles = 30,
                text.scale=2 ) 
          print(plot, newpage = FALSE) # remove the first blank page
        }else if(style =="vennerable"){
          vobj <- Vennerable::Venn(vennList)
           if (length(vennList) == 4) {
            vobj <- compute.Venn(vobj, doWeights = F,doEuler=T, type="ellipses")
          }else if(length(vennList) < 4){
            vobj <- compute.Venn(vobj, doWeights = T,doEuler=T,type="circles")
          } else{
            vobj <- compute.Venn(vobj, doWeights = T,doEuler=T)
          }
          venn_gp <- VennThemes(vobj)
          venn_gp <- VennThemes(vobj)
          venn_gp$SetText <- lapply(venn_gp$SetText,function(x) {x$fontsize<- 12; return(x)})
          venn_gp$FaceText <- lapply(venn_gp$FaceText,function(x) {x$cex<- 0.8; return(x)})
          Vennerable::plot(vobj, gpList = venn_gp, show = list(Universe = FALSE))
        }
    }
    garbage<-dev.off()   
  return(plot)
}

#================================================================

##################################################################
#  01/20/2026,15:29:49 
##################################################################
#================================================================

#' Plot Imprintome Polar Coordinates
#'
#' @param data Data frame containing `Angle` and `IDS` plus grouping columns.
#' @param outFile Optional output file path.
#' @param colorColumn Column name used for point fill grouping.
#' @param title Plot title.
#' @param palette Palette name passed to `GetColors()`.
#' @param alpha Point alpha.
#'
#' @return A ggplot object.
PlotPolar <- function(data, outFile=NULL,colorColumn="Sample_Group", title="ImprintomeR:Polar", subtitle=NULL, palette="default", alpha=0.8) {
  library(ggplot2)
  options(bitmapType = "cairo")

  if (!(colorColumn %in% colnames(data))) {
    stop("colorColumn not found in data: ", colorColumn)
  }
  
  # Define our 8 mechanism anchors
  mechanism_labels <- c(
    "Pat-Gain\n(0°)", "Global-Hyper\n(45°)", "Mat-Gain\n(90°)", "Mat-Gain+Pat-Loss\n(135°)", 
    "Pat-Loss\n(180°)", "Global-Hypo\n(225°)", "Mat-Loss\n(270°)", "Pat-Gain+Mat-Loss\n(315°)"
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

  groups <- unique(as.character(data[, colorColumn]))
  n_groups <- length(groups)
  palette_values <- NULL
  if (exists("GetColors", mode = "function", inherits = TRUE)) {
    palette_values <- GetColors(palette = palette, n = n_groups)
  } else {
    palette_values <- grDevices::hcl.colors(n_groups, palette = "Dark 3")
  }
  group_colors <- stats::setNames(palette_values, groups)

  data$COLOR <- unname(group_colors[as.character(data[, colorColumn])])
  uniqCombs <- data.frame(COLOR = unname(group_colors), GROUP = names(group_colors), stringsAsFactors = FALSE)
  # sort chr1, chr2...
  data[,colorColumn] <- factor( data[,colorColumn], levels=stringr::str_sort( unique(data[,colorColumn]), numeric = TRUE) )
  
  dotSize <-   4/log10(nrow(data)+10)
  imgSize <-  ifelse(nrow(data) >1000, 12, 8)

  pg <- ggplot(data, aes(x = Angle, y = IDS)) +
    geom_vline(xintercept = degree_breaks, color = "grey90", linetype = "dashed") +
    geom_vline(xintercept = boundary_lines, 
               color = "#2ecc71", # A professional "Bio-Green"
               linetype = "solid", 
               linewidth = 0.8, 
               alpha = 0.6) +       
    geom_hline(yintercept = 0.2, color = "grey60", linewidth = 0.7, linetype = "solid")+
    geom_point(aes(fill = .data[[colorColumn]]),color= "grey30",shape=21,size=dotSize, alpha = alpha) +
    coord_polar(theta = "x", start = -pi/2,clip = "off", direction =-1) +  # move 0 degree to 3 o'clock like standard mathematics, counter-clock-wise
    scale_x_continuous(
      limits = c(0, 360),
      breaks = degree_breaks,
      labels = mechanism_labels,
      expand = c(0, 0)
    ) +
     annotate("text", x = 0, y = y_ticks, label = y_labels, 
             size = 3.5, color = "darkred", fontface = "bold", vjust = -0.5) + 
    theme_minimal() +
    scale_y_continuous(
      limits = c(0, 0.8),
      breaks = y_ticks,
      expand = c(0, 0),
      labels = NULL # Hide default y-labels to use our annotated ones,
    )+
    scale_fill_manual(name="Color", values=stats::setNames(uniqCombs$COLOR, uniqCombs$GROUP))+ 
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
      subtitle = subtitle,
      x = NULL, y = NULL
    )

    if(!is.null(outFile)){
      plotWidth <- 8
      plotHeight <- 8
      .imprint_save_plot(pg, outFile = outFile, width = plotWidth, height = plotHeight, units = "in", limitsize = TRUE)
    }
    return(pg)
}

#==============================================================

MirrorDensity <- function(betaFile,  metaFile = NULL, SAMPLEID="Sample_Name",
                                  probeset = probeset_options,
                                  outFile = NULL ) {
    library(ggplot2)
    suppressMessages(suppressWarnings(library(dplyr)))  
    library(tidyr)
  resolved <- .resolve_beta_meta_inputs(betaFile, metaFile, require_meta = TRUE)
  betaFile <- resolved$beta
  metaFile <- resolved$meta

    if((inherits(betaFile, c('data.frame', 'matrix'))) && inherits(metaFile, 'data.frame')){ # data.frame or matrix as input
      meta <- metaFile
      beta <- as.data.frame(betaFile)
    }else{ # filename as input
      input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
      meta <- input[["meta"]]
      beta <- input[["beta"]]
    }
    tmp  <- SubsetBeta_By_Probeset(beta, probeset = probeset, prefix = NULL)
    
    probesets <- tmp[["probesets"]]
    beta <- tmp[["beta"]]
    beta <- na.omit(beta) 

    validIds <- intersect(meta$Sample_Name, colnames(beta))
    if (length(validIds) ==0) {
      cat("\nERROR: beta column does not match meta$Sample_Name. \n")
      return(NULL)
    } 
    meta <- meta[meta$Sample_Name %in% validIds, , drop = FALSE]
    beta <- beta[, validIds, drop = FALSE]
    meta$SAMPLEID <- meta[,SAMPLEID]
    newIDs <- meta[["SAMPLEID"]]
    colnames(beta) <- newIDs 

    maternal_probes <- intersect(probesets$NAME[grep("maternal", probesets$ORIGIN)], rownames(beta))
    paternal_probes <- intersect(probesets$NAME[grep("paternal", probesets$ORIGIN)], rownames(beta))

    # We move rownames to a column called "NAME" to match your probesets table
    beta_long <- as.data.frame(beta) %>%
      mutate(NAME = rownames(.)) %>%
      pivot_longer(
        cols = -NAME, 
        names_to = "Sample_Name", 
        values_to = "Beta"
      )
  # This adds the 'ORIGIN' (maternal/paternal) and other columns to every row
  used_long <- beta_long %>%
    inner_join(probesets, by = "NAME")

  used_long <- used_long %>%
        filter(!is.na(Beta),!is.na(ORIGIN)) %>%
        mutate(ORIGIN = factor(ORIGIN, levels = c("maternal", "paternal")))
        
    # View the result
    head(used_long)
    # 1. Prepare data (ensure it is in Long Format)
    # You need a column 'Beta' and a column 'ORIGIN' (maternal/paternal)
    plot_data <- used_long 

    # 2. Generate the Vertical Plot
    pg <- ggplot(plot_data, aes(x = Beta, fill = ORIGIN)) +
      # Maternal density on the "right" (positive)
      geom_density(data = filter(plot_data, ORIGIN == "maternal"), 
                  aes(y = after_stat(density)), alpha = 0.7) +
      # Paternal density on the "left" (negative)
      geom_density(data = filter(plot_data, ORIGIN == "paternal"), 
                  aes(y = -after_stat(density)), alpha = 0.7) +
      # Add the 0.5 reference line (now horizontal)
      geom_vline(xintercept = 0.5, linetype = "dashed", color = "black") +
      # Flip the coordinates
      coord_flip() + facet_wrap(~Sample_Name) +
      # Formatting
      scale_fill_manual(values = .imprint_origin_colors()[c("maternal", "paternal")]) +
      theme_minimal() +
      labs(
        title = "Methylation Shift",
        subtitle= paste0("probeset:", probeset),
        x = "Methylation (Î²)", 
        y = "Density (Paternal < 0 > Maternal)"
      )

  
    if(!is.null(outFile)){
      imgSize <- ifelse(nrow(beta) >20, 12, 6)
      .imprint_save_plot(pg, outFile = outFile, width = imgSize, height = imgSize, units = "in", limitsize = TRUE)
    }
    return(pg)
 }

#================================================================
#' Comprehensive Imprinting Analysis for imprintomeR
#' 
#' @param betaFile  Character. file of beta values (Probes as rownames, Samples as colnames).
#' @param metaFile  Character. file of sample information.
#' @param probeset  Character. the name of a predefined imprinting probeset.
#' @param ids_cutoff Numeric. The IDS distance threshold to call an EpiMutation (Default = 0.2).
#' @return A data frame with metrics, directional interpretations, and mutation calls.
#'

PlotRainfall <- function(beta, sampleID, title="Imprinting Rainfall Plot", probeset=c("classifier2","classifier3","selected","signature_hc"), outFile=NULL) {
  library(ggplot2)
  suppressMessages(suppressWarnings(library("dplyr")))
  library(stringr)
  probeset <- match.arg(probeset)
  beta <- .resolve_beta_input(beta)

  beta <- as.data.frame(beta)
  probesets <- readRDS(.resolve_extdata_file("probesets_hg19.rds"))
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
  beta$CHR <-  anno[common_probes,"CHR"]
  beta$ORIGIN <-  anno[common_probes,"ORIGIN"]
  beta$MAPINFO <-  anno[common_probes,"MAPINFO"]

  sample_data <- beta[, c("Probe", "CHR","MAPINFO","ORIGIN",sampleID) ]
  colnames(sample_data)[ncol(sample_data)] <- "beta"
  # 1. Filter for sample and high-confidence probes
  plot_data <- sample_data %>%
    mutate(
      CHR = factor(CHR, levels = str_sort(unique(CHR), numeric = TRUE))
    ) %>%
    arrange(CHR, MAPINFO)%>%
    group_by(CHR) %>%
    # Create an index for even spacing
    mutate(Probe_Index = row_number()) %>% 
    ungroup() %>%
    mutate(IDI = (beta - 0.5) * 2)

  pg <- ggplot(plot_data, aes(x = MAPINFO, y = IDI, color = ORIGIN)) +
    # Reference Line at 0 (Normal Imprinting)
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50", alpha = 0.5) +
    # The Probes
    geom_point(alpha = 0.6, size = 0.5) +
    # Color Scheme (Maternal vs Paternal)
    scale_color_manual(
      values = .imprint_origin_colors()[c("maternal", "paternal")],
      breaks = c("maternal", "paternal"),
      labels = c("maternal", "paternal"),
      name = "Allelic origin"
    ) +
    # Faceting by Chromosome
    facet_wrap(. ~ CHR, scales = "free_x",nrow=1) +
    # Aesthetic styling
    theme_minimal() +
    theme(
      axis.text.x = element_blank(), # Hide coordinates to reduce clutter
      axis.ticks.x = element_blank(),
      panel.spacing = unit(0.1, "lines"),
      strip.background = element_rect(fill = "grey95", color = "white"),
      strip.text.x = element_text(angle = 90, size = 8, face = "bold"),
      legend.position = "bottom"
    ) +
    labs(
      title = title,
      subtitle = paste0("Sample: ", sampleID, " | Probeset: ", probeset),
      y = "IDI = (beta - 0.5) * 2",
      x = "Genomic position (bp)"
    ) +
    ylim(-1, 1)
  if(!is.null(outFile)){
        .imprint_save_plot(pg, outFile = outFile, width = 12, height = 6, units = "in", limitsize = TRUE)
  }
  return(pg)
}
#================================================================

PlotRadar1 <- function(df, id="Sample1", title="Radar plot", pt.size=3, fontsize=5, outFile=NULL) {
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(stringr)

  # 1. Prepare Data
  # Ensure we have a data frame with metrics and values
  plot_data <- data.frame(
    metric = rownames(df),
    value = as.numeric(df[,1])
  )
  
  # Sort metrics numerically/alphabetically
  plot_data <- plot_data[str_order(plot_data$metric, numeric = TRUE), ]
  n_metrics <- nrow(plot_data)
  
  # Shift values to be positive (0 to 2) so coord_polar works
  # -1 -> 0 (center), 0 -> 1 (mid), 1 -> 2 (outer)
  plot_data$value_scaled <- plot_data$value + 1
  
  # 2. Handle the "Short Path" Loop Closure
  # We map metrics to a numeric index 1:N, then add point N+1 as a duplicate of point 1
  plot_data_closed <- plot_data %>%
    mutate(idx = row_number()) %>%
    bind_rows(., slice(., 1) %>% mutate(idx = n_metrics + 1))

  # 3. Calculate Radial Label Angles & Justification
  # This ensures text is readable and points outward from the center
  # Blue for > 0, Brown for < 0, Black for 0
  label_df <- plot_data %>%
    mutate(
      idx = row_number(),
      label_color = case_when(
        value > 0.4  ~ "brown",
        value < -0.4  ~ "blue",
        TRUE       ~ "black"
      ),
      angle = 90 - 360 * (idx - 1) / n_metrics,
      hjust = ifelse(angle < -90 & angle > -270, 1, 0),
      angle_final = ifelse(angle < -90 & angle > -270, angle + 180, angle)
    )

  # 4. Define Spokes (Limited to the outer grid y=2)
  spoke_df <- data.frame(
    x = 1:n_metrics,
    y_start = 0,
    y_end = 2
  )
# Calculate the x-position for 3 o'clock
    # We use (n_metrics / 4) + 1 to find the 90-degree mark
    pos_3_oclock <- (n_metrics / 4) + 1

  # 5. Build the Plot
  p <- ggplot(plot_data_closed, aes(x = idx, y = value_scaled)) +
    # Circular Grid Rings (Drawn as paths to ensure perfect circles)
    annotate("path", x = seq(1, n_metrics + 1, length.out = 200), y = 0, color = "grey85") + # -1 ring
    annotate("path", x = seq(1, n_metrics + 1, length.out = 200), y = 1, color = "grey30", linewidth = 0.7) + # 0 ring
    annotate("path", x = seq(1, n_metrics + 1, length.out = 200), y = 2, color = "grey85") + # 1 ring
    
    # Spokes (Segments instead of vlines to keep them inside the circle)
    geom_segment(data = spoke_df, 
                 aes(x = x, xend = x, y = y_start, yend = y_end), 
                 color = "grey40", linetype = "dashed") +
    
    # Data Connection (The "Spider Web" line)
    geom_path(color = "#1f78b4", linewidth = 1.2, alpha = 0.8) +
    geom_point(color = "#1f78b4", size = pt.size) +
    
    # Scale Labels (-1, 0, 1) placed at the 12 o'clock position
    annotate("text", x = pos_3_oclock , y = c(0, 1, 2), label = c("-1", "0", "1"), 
             color = "purple", size = fontsize, fontface = "bold", vjust = -0.5) +
    
    # Radial Metric Labels
    geom_text(data = label_df, 
              aes(x = idx, y = 2.15, label = metric, angle = angle_final, hjust = hjust, color = label_color),
              ,show.legend = FALSE, size = fontsize) +
    scale_color_identity() +
    # Polar Transformation (start=0 puts first metric at top)
    coord_polar(start = 0) +
    
    # Scales and Limits
    scale_y_continuous(limits = c(-1, 3)) + # Limit of 3 creates space for labels, # The more negative the first number, the bigger the center hole.
    scale_x_continuous(limits = c(1, n_metrics + 1)) +
    
    # Styling
    labs(title = title, x = NULL, y = NULL) +
    theme_minimal() +
    theme(
      axis.text = element_blank(),
      panel.grid = element_blank(),
      plot.title = element_text(size = 14, face = "bold", hjust = 0.5, margin = margin(b=20)),
      plot.margin = margin(20, 20, 20, 20)
    )

  # 6. Save and Return
  if (!is.null(outFile)) {
    ggsave(filename = outFile, plot = p, width = 12, height = 12, units = "in", bg = "white")
  }
  
  return(p)
}

#================================================================

PlotRadar <- function(df, id="Sample1", title="Radar plot", pt.size=3, fontsize=5, outFile=NULL) {
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(stringr)

  # 1. Prepare Data
  plot_data <- data.frame(
    metric_raw = rownames(df),
    metric = gsub("maternal", "mat", gsub("paternal", "pat", rownames(df))),
    value = as.numeric(df[,1]),
    stringsAsFactors = FALSE
  )
  
  plot_data <- plot_data[str_order(plot_data$metric, numeric = TRUE), ]
  n_metrics <- nrow(plot_data)
  plot_data$value_scaled <- plot_data$value + 1
  
  # 2. Add Color Logic (Shared by dots and labels)
  plot_data <- plot_data %>%
    mutate(
      idx = row_number(),
      origin_group = case_when(
        grepl("maternal|mat", metric_raw, ignore.case = TRUE) ~ "maternal",
        grepl("paternal|pat", metric_raw, ignore.case = TRUE) ~ "paternal",
        TRUE ~ "other"
      )
    )

  # 3. Label Logic (Rotation and Justification)
  label_df <- plot_data %>%
    mutate(
      angle = 90 - 360 * (idx - 1) / n_metrics,
      hjust = ifelse(angle < -90 & angle > -270, 1, 0),
      angle_final = ifelse(angle < -90 & angle > -270, angle + 180, angle)
    )

  # 4. Path Closure (For the connecting line)
  plot_data_closed <- plot_data %>%
    bind_rows(., slice(., 1) %>% mutate(idx = n_metrics + 1))

  # 5. Spokes and Scale positions
  spoke_df <- data.frame(x = 1:n_metrics, y_start = 0, y_end = 2)
  pos_3_oclock <- (n_metrics / 4) + 1

  # 6. Build Plot
  p <- ggplot(plot_data_closed, aes(x = idx, y = value_scaled)) +
    # Background Grid Rings
    annotate("path", x = seq(1, n_metrics + 1, length.out = 200), y = 0, color = "grey85") + 
    annotate("path", x = seq(1, n_metrics + 1, length.out = 200), y = 1, color = "grey30", linewidth = 0.7) + 
    annotate("path", x = seq(1, n_metrics + 1, length.out = 200), y = 2, color = "grey85") + 
    
    # Spokes (Dashed lines)
    geom_segment(data = spoke_df, aes(x = x, xend = x, y = y_start, yend = y_end), 
                 color = "grey90", linetype = "dashed") +
    
    # The Connecting Line (Solid Grey to let colors pop)
    geom_path(color = "grey40", linewidth = 0.8, alpha = 0.8) +
    
    # DOTS and labels colored by origin using the same scheme as rainfall.
    geom_point(aes(color = origin_group), size = pt.size) +
    
    # Scale Labels at 3 o'clock
    annotate("text", x = pos_3_oclock, y = c(0, 1, 2), label = c("-1", "0", "1"), 
         color = .imprint_origin_colors()["reference"], size = fontsize, fontface = "bold", vjust = -0.7) +
    
    # METRIC LABELS (Colored blue/brown to match dots)
    geom_text(data = label_df, 
              aes(x = idx, y = 2.15, label = metric, angle = angle_final, 
                  hjust = hjust, color = origin_group),
              size = fontsize, show.legend = FALSE) +
    scale_color_manual(
      values = c(
        maternal = unname(.imprint_origin_colors()["maternal"]),
        paternal = unname(.imprint_origin_colors()["paternal"]),
        other = unname(.imprint_origin_colors()["reference"])
      ),
      breaks = c("maternal", "paternal", "other"),
      labels = c("maternal", "paternal", "other"),
      name = "Allelic origin"
    ) +
    
    coord_polar(start = 0) +
    scale_y_continuous(limits = c(-0.6, 3)) + 
    scale_x_continuous(limits = c(1, n_metrics + 1)) +
    
    labs(
      title = title,
      subtitle = paste0("Sample: ", id),
      x = "Imprinting locus",
      y = "IDI",
      caption = "Radial scale labels correspond to IDI values: -1, 0, 1"
    ) +
    theme_minimal() +
    theme(
      axis.text = element_blank(),
      panel.grid = element_blank(),
      plot.title = element_text(size = 12, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 10, hjust = 0.5),
      plot.caption = element_text(size = 8, color = "grey35"),
      legend.position = "bottom",
      plot.margin = margin(20, 20, 20, 20)
    )

  if (!is.null(outFile)) ggsave(outFile, p, width = 12, height = 12, bg = "white")
  
  return(p)
}

#================================================================

PlotRidgeline_cohort_chr_origin_<- function(beta, outFile = NULL, scale = 1.5, alpha = 0.7,probeset=probeset) {
  suppressMessages(suppressWarnings({
    library(ggplot2)
    library(ggridges)
    library(dplyr)
    library(tidyr)
    library(stringr)
  }))

  # 1. Load Annotation
  anno_path <- .resolve_extdata_file("probesets_hg19.rds")
  probesets <- readRDS(anno_path)
  # Using 'selected' probeset for distribution analysis
  anno <- probesets[[probeset]] %>% 
    select(NAME, CHR, ORIGIN) %>% 
    as.data.frame()
  rownames(anno) <- anno$NAME

  # 2. Align Data
  valid_probes <- intersect(rownames(beta), rownames(anno))
  beta_sub <- beta[valid_probes, , drop = FALSE]
  
  # 3. Pivot Long and Aggregate
  # We don't care about Sample Names anymore, so we pivot and keep values pooled
  used <- as.data.frame(beta_sub) %>%
    mutate(Probe = rownames(.),
           Chromosome = anno[valid_probes, "CHR"],
           ORIGIN = anno[valid_probes, "ORIGIN"]) %>%
    pivot_longer(cols = -c(Probe, Chromosome, ORIGIN), 
                 names_to = "SampleID", 
                 values_to = "value") %>%
    filter(!is.na(value))

  # 4. Factor Ordering for Chromosomes
  # This ensures chr1 is at the top and chr22 is at the bottom (or vice versa)
  used$Chromosome <- factor(used$Chromosome, 
                             levels = rev(str_sort(unique(used$Chromosome), numeric = TRUE)))
  used$ORIGIN <- factor(used$ORIGIN, levels = c("maternal", "paternal"))

  # 5. Generate Plot
  cat("\n Generating aggregated cohort ridgeline plot...\n")
  
  pg <- ggplot(used, aes(x = value, y = Chromosome, fill = ORIGIN)) +
    # Vertical reference lines at 0, 0.5, and 1
    geom_vline(xintercept = c(0, 0.5, 1), linetype = "dashed", color = "grey80") +
    
    # One ridge per chromosome, colored by Origin
    geom_density_ridges(alpha = alpha, scale = scale, color = "white") +
    
    # Split by Origin to see Maternal vs Paternal side-by-side
    facet_wrap(~ORIGIN) +
    
    scale_fill_manual(values = .imprint_origin_colors()[c("maternal", "paternal")]) +
    scale_x_continuous(limits = c(-0.05, 1.05), breaks = seq(0, 1, 0.25)) +
    
    theme_ridges(center_axis_labels = TRUE) +
    theme(
      legend.position = "none",
      strip.background = element_rect(fill = "grey20"),
      strip.text = element_text(color = "white", face = "bold")
    ) +
    labs(
      title = "Global Imprinting Beta Distributions",
      subtitle = "Aggregated across all samples",
      x = "Methylation (Î²)",
      y = "Chromosome"
    )

  # 6. Save
  if (!is.null(outFile)) {
    # Since we only have ~24 ridges per panel now, height is much smaller
    .imprint_save_plot(pg, outFile = outFile, width = 10, height = 8, units = "in", limitsize = TRUE)
  }

  return(pg)
}


#================================================================

BetaDistribution_FacetByChrom <- function(beta, outFile = NULL, alpha = 0.7, probeset="classifier2") {
  suppressMessages(suppressWarnings({
    library(ggplot2)
    library(dplyr)
    library(tidyr)
    library(stringr)
  }))

  # 1. Load Annotation
  anno_path <- .resolve_extdata_file("probesets_hg19.rds")
  probesets <- readRDS(anno_path)
  # Selecting the 'selected' probeset which contains the CHR and ORIGIN mapping
  anno <- probesets[[probeset]] %>% 
    select(NAME, CHR, ORIGIN) %>% 
    as.data.frame()
  rownames(anno) <- anno$NAME

  # 2. Align Data
  valid_probes <- intersect(rownames(beta), rownames(anno))
  beta_sub <- beta[valid_probes, , drop = FALSE]
  
  # 3. Pivot Long (Aggregating all samples into one distribution)
  used <- as.data.frame(beta_sub) %>%
    mutate(Probe = rownames(.),
           Chromosome = anno[valid_probes, "CHR"],
           ORIGIN = anno[valid_probes, "ORIGIN"]) %>%
    pivot_longer(cols = -c(Probe, Chromosome, ORIGIN), 
                 names_to = "SampleID", 
                 values_to = "value") %>%
    filter(!is.na(value))

  # 4. Factor Ordering
  # Ensure chromosomes follow 1, 2, 3... order
  used$Chromosome <- factor(used$Chromosome, 
                             levels = str_sort(unique(used$Chromosome), numeric = TRUE))
  # Ensure Origin labels are consistent
  used$ORIGIN <- factor(used$ORIGIN, levels = c("maternal", "paternal"))

  # 5. Generate Plot
  cat("\n Generating faceted distribution plot (Maternal/Paternal side-by-side)...\n")
  
  pg <- ggplot(used, aes(x = ORIGIN, y = value, fill = ORIGIN)) +
    # Reference line at 0.5 (the expected hemi-methylated midpoint)
    geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey70") +
    
    # Violin plots show the density of the cohort
    geom_violin(trim = TRUE, alpha = alpha, color = "black", size = 0.3) +
    
    # Add a narrow boxplot inside to show the median and IQR
    geom_boxplot(width = 0.2, color = "black", outlier.shape = NA, alpha = 0.5) +
    
    # FACET BY CHROMOSOME: Each chromosome gets its own box
    facet_wrap(~ Chromosome, ncol = 6) + 
    
    scale_fill_manual(values = .imprint_origin_colors()[c("maternal", "paternal")]) +
    scale_y_continuous(limits = c(0, 1), breaks = c(0, 0.5, 1)) +
    
    theme_bw() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
      strip.background = element_rect(fill = "grey90"),
      strip.text = element_text(face = "bold"),
      legend.position = "none",
      panel.grid.minor = element_blank()
    ) +
    labs(
      title = paste("Probeset:",probeset),
      subtitle = "Aggregated Cohort Beta Values",
      x = "Allelic Origin",
      y = "Methylation (Î²)"
    )

  # 6. Save
  if (!is.null(outFile)) {
    # Width is fixed for 6 columns; height grows with number of chromosomes
    n_chrom <- length(unique(used$Chromosome))
    dynamic_height <- 3 * ceiling(n_chrom / 6)
    width <- ifelse(n_chrom ==1, 3, n_chrom )
    .imprint_save_plot(pg, outFile = outFile, width = width, height = dynamic_height, units = "in", limitsize = TRUE)
  }

  return(pg)
}

#================================================================

#' Plot ICR-Level Variance and Median Drift
#'
#' @param plot_data Data frame returned by ICR variance calculations.
#' @param outFile Optional output file path.
#' @param project Project/cohort label used in the title.
#' @param style Plot style: `"beeswarm"` or `"boxplot"`.
#' @param min_cpg Minimum CpG count required per ICR.
#'
#' @return A ggplot object.
Plot_ICR_var_med <- function(plot_data, outFile=NULL, project="cohort", style="beeswarm", min_cpg=3){
  suppressMessages(suppressWarnings(library("dplyr")))
  suppressMessages(suppressWarnings(library("ggplot2")))
  cat("\nInfo: min_cpg per ICR=",min_cpg,"!")
    final_data <- plot_data %>%
    # 1. Filter
    filter(CpG_Count > min_cpg) %>%
    # 2. Group for calculation
    group_by(icr_name, SAMPLE_GROUP) %>%
    # 3. Add the group-level median as a new column
    summarise(Group_Median_Beta = median(Median_Beta, na.rm = TRUE), 
          Group_SD_Beta     = sd(Median_Beta, na.rm = TRUE),
          CpG_Count = mean(CpG_Count),
          .groups = "drop" )

    if(!is.null(outFile)){
      txtFile<- paste0(tools::file_path_sans_ext(basename(outFile)),"_aggregated_by_group.txt")
      write.table(final_data, txtFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
      cat("\n",basename(txtFile),"[saved]")
    }

  num_ICRs <- length(unique(plot_data$icr_name))
  if(num_ICRs >100){
    cat("\nInfo: only use top 100 most drifting ICRs!")
    top_drift_icrs <- plot_data %>%
      filter(CpG_Count > min_cpg)  %>%
      group_by(icr_name) %>%
      summarise(var_of_medians = var(Median_Beta, na.rm = TRUE)) %>%
      slice_max(v, n = 100) %>% pull(icr_name)
    plot_data <- final_report %>% filter(icr_name %in% top_drift_icrs$icr_name)
    num_ICRs <- 100
  }
  plot_data <- plot_data %>%
    filter(CpG_Count > min_cpg)  %>%
    mutate(Drift_Distance = abs(Median_Beta - 0.5))

  if(style=="beeswarm"){
     suppressMessages(suppressWarnings(library("ggbeeswarm")))
     pg <- ggplot(plot_data, aes(x = reorder(icr_name, Drift_Distance, FUN = median), y = Median_Beta)) +
    geom_quasirandom(cex = 1, alpha = 0.5, pch=20, aes(color=ImpVar_Score)) + 
        stat_summary(fun = median, geom = "errorbar", aes(ymin = after_stat(y), ymax = after_stat(y)), 
                    width = 0.75, linewidth = 0.8, color="grey30") 
  }else{
    pg <- ggplot(plot_data, aes(x = reorder(icr_name, Median_Beta, FUN = median), y = Median_Beta)) +
    geom_boxplot(outlier.shape = NA, fill = "skyblue", alpha = 0.5) +
    geom_jitter(aes(color = ImpVar_Score), width = 0.2, alpha = 0.7) 
  }
  # 2. Build the Plot
  pg <- pg +
    geom_hline(yintercept = 0.5, linetype = "dashed", color = "blue") +
    facet_wrap(~SAMPLE_GROUP) +
    coord_flip() + # Flip for easier reading of chr_start_end names
    scale_color_viridis_c(option = "magma") +
    labs(title = paste0(basename(project), ": ", num_ICRs, " ICRs"),
        subtitle = "Points colored by Within-Region Variance (ImpVar_Score)",
        x = "ICR Coordinate",
        y = "Median Beta Value") +
    theme_minimal()

    # 3. Dynamic Scaling
    n_icrs <- length(unique(plot_data$icr_name))
    n_groups <- length(unique(plot_data$SAMPLE_GROUP))
    img_height <- (n_icrs * 0.1*n_groups) + 2
    img_width <- ifelse(n_groups == 1, 12, n_groups * 4)
     # 4. Save and Report
    if(!is.null(outFile)){
      .imprint_save_plot(pg, outFile = outFile, width = img_width, height = img_height, units = "in", limitsize = FALSE)
    }

    return(pg)

}


# --- Example Usage ---
# results <- calculate_impvar(my_beta_values, my_annotations, target_icrs)
#================================================================
if(F){
  library(ggplot2)
   icr.bed <- "/research/rgs01/home/clusterHome/hjin/projects/ImprintomeR/ICR/Joshi_mmc6_simple_merged_d2k.bed"
   betaFile <- "/research/rgs01/home/clusterHome/hjin/projects/ImprintomeR/imprintomeR_dev/datasets/GSE52576_CHM_450K/GSE52576_CHM_beta.txt"
   metaFile <- "/research/rgs01/home/clusterHome/hjin/projects/ImprintomeR/datasets/GSE52576/GSE52576_meta.txt"
   outFile <- "GSE52576_sig.Joshi_Median_Drift.txt"
  final_report <- Calculate_impvar(betaFile, metaFile, icr.bed, assay="EPICv1",genome="hg19",outFile=NULL)
  pg1 <- ggplot(final_report, aes(x = icr_name, y = ImpVar_Score, fill = SAMPLE_GROUP)) +
    geom_boxplot() +
    theme_minimal() +
    labs(title = "Epigenetic Stochasticity (ImpVar) across ICRs",
        y = "Within-Region Variance",
        x = "ICR")  +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1))

   outFile<- paste0("GSE52576_sig.Joshi_impvar.pdf")
   ggsave(file=outFile,pg1,width=12,height=5,units="in", limitsize = TRUE)
   
# We filter for a subset (e.g., top 30 most variable ICRs) to keep the plot readable
top_drift_icrs <- final_report %>%
  group_by(icr_name) %>%
  summarise(var_of_medians = var(Median_Beta, na.rm = TRUE)) 

plot_data <- final_report %>% filter(icr_name %in% top_drift_icrs$icr_name)

pg0 <- ggplot(plot_data, aes(x = reorder(icr_name, Median_Beta, FUN = median), y = Median_Beta)) +
  geom_boxplot(outlier.shape = NA, fill = "skyblue", alpha = 0.5) +
  geom_jitter(aes(color = ImpVar_Score), width = 0.2, alpha = 0.7) +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "red") +
  facet_wrap(~SAMPLE_GROUP) +
  coord_flip() + # Flip for easier reading of chr_start_end names
  scale_color_viridis_c(option = "magma") +
  labs(title = "ICRs Median Methylation Drift",
       subtitle = "Points colored by Within-Region Variance (ImpVar_Score)",
       x = "ICR Coordinate",
       y = "Median Beta Value") +
  theme_minimal()

  n_icrs <- length(unique(plot_data$icr_name))
  n_groups <- length(unique(plot_data$SAMPLE_GROUP))
  img_height <- (n_icrs * 0.4) + 1
  img_width <- (n_groups * 2)

   outFile<- paste0("GSE52576_sig.Joshi_impvar_ICR_drift_faceted2.pdf")
   ggsave(file=outFile,pg0,width=img_width,height=img_height,units="in", limitsize = FALSE)
   


   final_report$CHR <- sub("_.*", "", final_report$icr_name)
  pg2 <-  ggplot(final_report, aes(x = icr_name, y = Median)) +
  # Background shaded area for expected range (0.35 - 0.65)
  annotate("rect", xmin = -Inf, xmax = Inf, ymin = 0.35, ymax = 0.65, 
           fill = "green", alpha = 0.1) +
  geom_jitter(aes(size = ImpVar_Score, color = ImpVar_Score), alpha = 0.6) +
  facet_wrap(~CHR, scales = "free_x") +
  scale_color_gradient(low = "blue", high = "red") +
  theme_minimal() +
  theme(axis.text.x = element_blank(), # Names are too long for facets
        panel.grid.major.x = element_blank()) +
  labs(title = "Methylation Drift Across Chromosomes",
       size = "Within-Region Noise",
       y = "Median Methylation")

   outFile<- paste0("GSE52576_sig.Joshi_impvar_drift_track.pdf")
   ggsave(file=outFile,pg2,width=12,height=5,units="in", limitsize = TRUE)

pg3 <- ggplot(final_report, aes(x = Median, y = ImpVar_Score)) +
  # Add a density contour to see where most samples lie
  geom_density_2d(color = "gray80") +
  geom_point(aes(color = CpG_Count), alpha = 0.5) +
  # Highlight the theoretical "Perfect Imprint" line
  geom_vline(xintercept = 0.5, linetype = "dashed", color = "red") +
  scale_color_viridis_c() +
  labs(title = "ICR Stochastic Drift Analysis",
       x = "Median Methylation (Target: 0.5)",
       y = "Within-Region Variance (Noise)") +
  theme_minimal()

   outFile<- paste0("GSE52576_sig.Joshi_impvar_drift2.pdf")
   ggsave(file=outFile,pg3,width=12,height=5,units="in", limitsize = TRUE)

}

#================================================================


#' Validate Imprinting Deviation against Tumor Purity
#' @param purity Numeric vector (0 to 1) representing global tumor purity
#' @param obs_dev Numeric vector (0 to 0.5) representing observed deviation from 0.5
#' @param sample_ids Character vector of sample names
#' @return A dataframe with expected values and consistency metrics

plot_imp_consistency <- function(df) {
  ggplot(df, aes(x = Purity, y = Observed_Dev)) +
    # The "Ideal" line (Slope = 0.5)
    geom_abline(intercept = 0, slope = 0.5, linetype = "dashed", color = "red") +
    geom_point(aes(color = Status, size = Fit_Score)) +
    geom_text(aes(label = SampleID), vjust = -1) +
    xlim(0, 1) + ylim(0, 0.5) +
    labs(
      title = "Imprinting Cross-Validation: Purity vs. Deviation",
      subtitle = "Red dashed line represents 'Perfect LOI' model",
      x = "Global Tumor Purity",
      y = "Observed Imprinting Deviation (|Beta - 0.5|)"
    ) +
    theme_minimal()
}
# Interpretation of Results:
# 1. On the Line: The imprinting loss is "clonal"Ã¢â‚¬â€it occurred in the ancestor of all tumor cells.
# 2. Far Below the Line: The sample has low deviation despite high purity. This indicates "Subclonal LOI" or "Stochastic Drift", where only some tumor cells have lost the imprint.
# 3. Above the Line: This is mathematically impossible in a perfect model (you can't be more than 100% deviated). It usually suggests that the Global Purity estimate for that sample was too low and should be re-evaluated.
# plot_imp_consistency(fit_data)

#================================================================
#================================================================


#' Calculate Global Biological Age
#' @param beta_matrix A matrix where rows are CpG IDs and columns are Sample Names
#' @return A data frame with HorvathAge and other clock results

#' Multi-Panel Beeswarm Plot by Category/Origin
#'
#' @param beta Numeric beta matrix with probes as rows and samples as columns.
#' @param meta Sample metadata containing `SAMPLE_NAME` and grouping columns.
#' @param SAMPLEID Metadata column used as panel/sample label.
#' @param outFile Optional output file path.
#' @param alpha Point alpha.
#' @param probesets Optional annotation object.
#' @param useNA Logical; keep NA category values.
#' @param width,height Optional image dimensions for saving.
#' @param group Annotation column used to define categories.
#'
#' @return A patchwork/ggplot object.
BetaBeePlot_orgin2 <- function(beta, meta, SAMPLEID = "Sample_Name", outFile = NULL, alpha = 0.5,probesets=NULL, useNA=FALSE, width=NULL, height=NULL, group="ORIGIN") {
  # https://r-charts.com/distribution/ggbeeswarm/
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
  suppressMessages(suppressWarnings(library("reshape2")))
  if(!is.null(probeset)){
    probesets <- readRDS("inst/extdata/probesets_hg19.rds")
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
      probes.all <- readRDS(.resolve_extdata_file("anno.uniq_harmonized.liftover.rds"))
    }
    chr <- paste0("CHR_", toupper(version))
    mapinfo <- paste0("MAPINFO_", toupper(version))
    anno <- probes.all[probes.all$NAME %in% rownames(beta), c(chr, mapinfo, "UCSC_REFGENE_NAME")]
    colnames(anno) <- c("CHR", "MAPINFO", "GENE")
    anno$CATEGORY <- "NA"
  }
  common_probes <- intersect(rownames(anno), rownames(beta))
  beta <- beta[common_probes, ]

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
  beta$Probe=rownames(beta)
  beta$CATEGORY= anno[common_probes,"CATEGORY"]

  suppressMessages({
    used <- reshape2::melt(beta, id.vars = c("Probe", "CATEGORY"),variable.name = "ID",value.name = "value")
  })
  if(! useNA){
     used <- used[used$CATEGORY %in% c("paternal","maternal"),]
  }

library(patchwork)
suppressMessages(suppressWarnings(library(dplyr)))

# 1. Create a list of plots (one for each unique ID)
plot_list <- lapply(unique(used$ID), function(current_id) {
  
  # Filter data for just this ID
  df_sub <- used %>% filter(ID == current_id)
  
  # Generate the individual "panel"
  p <- ggplot(df_sub, aes(x = CATEGORY, y = value, color = CATEGORY)) +
    geom_hline(yintercept = 0.5, linetype = "dashed", color = .imprint_origin_colors()["reference"]) +
    geom_quasirandom(cex = dotSize, alpha = alpha, width = 0.3) +
    stat_summary(fun = median, geom = "errorbar", 
                 aes(ymin = after_stat(y), ymax = after_stat(y)), 
                 width = 0.5, linewidth = 0.7, color="grey30") + 
    # Use the ID as the title for this specific panel
    labs(title = current_id, y = "Methylation (Î²)", x = NULL) +
    scale_color_manual(values = .imprint_origin_colors()[c("maternal", "paternal")], drop = FALSE) +
    theme_classic(base_size = 10) +
    theme(
      legend.position = "none",
      axis.text.x = element_text(angle = 90, hjust = 1),
      plot.title = element_text(size = 9, face = "bold", hjust = 0.5),
      panel.border = element_rect(color = "grey20", fill = NA, linewidth = 0.5)
    )

  return(p)
})

# 2. Combine them using patchwork
# 'wrap_plots' handles a list of plots automatically
nc <- ifelse(ncol(beta) <10, ncol(beta), 10)
nr <- ceiling(ncol(beta)/nc)
pg  <- wrap_plots(plot_list) + 
  plot_layout(ncol = nc) + # Adjust columns based on your cohort size
  plot_annotation(
    title = 'Beeswarm Violin',
    subtitle = paste0( 'probeset:', probeset ),
    theme = theme(plot.title = element_text(size = 12, hjust = 0.5))
  )

# 3. Display or Save

  if (!is.null(outFile)) {
      imgWidth <- (nc * 2) + 1
      imgHeight <- (nr * 3.5) + 1
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = F)
    cat("\n\t", basename(outFile), "[saved]")
  }
  return(pg)
}

#' Beeswarm Plot by Chromosome vs Others for Each Sample
#'
#' Creates one panel per sample showing methylation distribution split into two
#' groups (target chromosome and others), colored by category/origin.
#'
#' @param dat Data frame/matrix with sample columns plus grouping columns.
#' @param meta Metadata data frame containing `SAMPLE_NAME` and optional `ID2`.
#' @param group.by Column in `dat` used for faceting (default: `"chr"`).
#' @param color.by Column in `dat` used for point color (default: `"CATEGORY"`).
#' @param outFile Output PDF path.
#' @param verbose Logical; print sample-level progress.
#'
#' @return `NULL`, writing plots to `outFile` as side effect.
Beeplot_chr_vs_other <- function(dat, meta, group.by = "chr", color.by = "CATEGORY", outFile = NULL, verbose = FALSE) {
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
  imgHeight <- 6
  imgWidth <- 4
  samples <- intersect(colnames(dat), meta$Sample_Name)
  pdf(outFile, width = imgWidth, height = imgHeight)
  for (sample in samples) {
    if (verbose) {
      cat("\n\t", sample)
    }
    sample_data <- data.frame(value = dat[, sample], GROUP = dat[, group.by], CATEGORY = dat[, color.by])
    pg <- ggplot(sample_data, aes(x = 1, y = value, color = CATEGORY), alpha = 1) +
      geom_quasirandom(cex = 1) +
      facet_wrap(~GROUP, nrow = 1) + theme_classic(base_size = 10) +
      labs(y = "methylation level", x = "GROUP") + ylim(0, 1) +
      geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey40", linewidth = 0.5) +
      geom_hline(yintercept = c(0.3, 0.7), linetype = "dotted", color = "grey60", linewidth = 0.5) +
      theme(
        axis.text.x = element_blank(), axis.ticks.x = element_blank(),
        panel.border = element_rect(color = "grey20", fill = NA, linewidth = 0.5)
      )
    if ("ID2" %in% colnames(meta)) {
      sTitle <- meta[meta$Sample_Name == sample, "ID2"]
      if (sTitle != sample) {
        pg <- pg + ggtitle(label = sample, subtitle = sTitle)
      } else {
        pg <- pg + ggtitle(label = sample)
      }
    } else {
      pg <- pg + ggtitle(label = sample)
    }
    print(pg)
  }
  garbage <- dev.off()
  cat("\n\t", basename(outFile), "[saved]")
}


#' Generate Chromosome-vs-Others Beeswarm PDFs
#'
#' For each chromosome in `chrs`, splits probes into target chromosome vs others
#' and delegates plotting to `Beeplot_chr_vs_other()`.
#'
#' @param input List containing `beta` and `meta` elements.
#' @param chrs Comma-separated chromosome string (e.g. `"chr1,chr11"`).
#' @param prefix Output prefix used to build per-chromosome PDF names.
#' @param probeset Probeset name in `inst/extdata/probesets_hg19.rds`.
#'
#' @return `NULL`, writing plots to files as side effects.
Beeplot_chr_vs_other_single <- function(input, chrs = "chr1,chr11", prefix = NULL, probeset = "classifier2") {
  probeset_name <- probeset
  probesets <- readRDS("inst/extdata/probesets_hg19.rds")
  probeset <- probesets[[probeset_name]]
  if ("ORIGIN" %in% colnames(probeset)) {
    anno <- probeset[, c("CHR", "MAPINFO", "Closest_TSS_gene_name", "ORIGIN")]
    rownames(anno) <- probeset$NAME
    colnames(anno)[3:4] <- c("GENE", "CATEGORY")
  } else {
    cat("\nError: ORIGIN column is missing in your probeset.\n")
    q("no")
  }
  beta <- input[["beta"]]
  meta <- input[["meta"]]
  chrs <- unlist(strsplit(chrs, ","))
  for (chr in chrs) {
    cat("\n\t", chr)
    common_probes <- intersect(probeset$NAME, rownames(beta))
    probeset <- probeset[probeset$NAME %in% common_probes, ]
    beta <- beta[common_probes, ]
    probes_chr <- probeset$NAME[probeset$CHR %in% c(chr, gsub("chr", "", chr))]
    probes_chr_others <- probeset$NAME[!probeset$CHR %in% c(chr, gsub("chr", "", chr))]
    beta_chr <- beta[probes_chr, ]
    beta_chr_others <- beta[probes_chr_others, ]
    melt_df <- rbind(cbind(beta_chr, chr = chr), cbind(beta_chr_others, chr = "others"))
    melt_df$CATEGORY <- anno[rownames(melt_df), "CATEGORY"]
    Beeplot_chr_vs_other(
      melt_df,
      meta,
      group.by = "chr",
      color.by = "CATEGORY",
      outFile = paste0(prefix, "_beeplot_", chr, ".pdf")
    )
  }
}



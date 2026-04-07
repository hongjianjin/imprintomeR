# Auto-refactored from utilities2.R
# Module: plotting

PlotCorHeatmap <- function(betaFile, metaFile, SAMPLEID="SAMPLE_NAME", prefix=NULL){
  library(pheatmap)
  if(class(betaFile) =='data.frame' & class(metaFile) =='data.frame'){ # data.frame as input
    meta <- metaFile
    beta <- betaFile
  }else{ # filename as input
    input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
    meta <- input[["meta"]]
    beta <- input[["beta"]]
  }

  validIds <- intersect(meta$SAMPLE_NAME, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$SAMPLE_NAME %in% validIds]
  if (length(validIds) ==1) {
    beta=data.frame(beta[, validIds])
    rownames(beta) <- rownames(beta)
    colnames(beta) <- validIds
    meta <- meta[validIds, ]
  }else  if (length(validIds) > 1) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$SAMPLE_NAME. \n")
    return(NULL)
  } 
  colnames(beta) <- newIDs 
  cor_matrix <- cor(beta)

 
 
  plotWidth<- plotHeight<- ifelse(ncol(cor_matrix)<10, 10, 10+ (ncol(cor_matrix)-10)*0.8 ) 
  color_palette <- colorRampPalette(c("blue", "white", "red"))(100)
 # Define breaks from -1 to 1
   breaks_list <- seq(-1, 1, length.out = 101)
  # Generate heatmap
  outFile1 <- paste0(prefix, "_cor.heatmap_detail.pdf")  
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
  outFile2 <- paste0(prefix, "_cor.heatmap_simple.pdf")            
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
  outFile3 <- paste0(prefix, "_cor.heatmap_auto.simple.pdf") 
  hm <- pheatmap(cor_matrix,
          color = color_palette,
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

ComputePCA  <- function(df, meta, scale=T, topn = 3000,varMethod="mad",groupColumn = "SAMPLE_GROUP"){
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
  if (!all(c("SAMPLE_NAME","SAMPLE_GROUP","COLOR") %in% colnames(meta))) {
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
    rownames(meta) <- meta$SAMPLE_NAME
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
  dat <- df[, keptSamples]
  used <-  Select_Top_Features(dat, method = tolower(varMethod), topn = topn) 
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

DimPlot  <- function(DimReduc,  reduction = "PCA", ShapeColumn=NULL, IdColumn='SAMPLE_NAME', groupColumn='SAMPLE_GROUP', 
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

Meth_PCA_Adv <- function(dat,meta=NULL, ShapeColumn=NULL,IdColumn='SAMPLE_NAME', groupColumn='SAMPLE_GROUP', 
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

Meth_TSNE_Adv <- function(dat,meta=NULL, ShapeColumn=NULL,IdColumn='SAMPLE_NAME', groupColumn='SAMPLE_GROUP', ColorColumn="COLOR", 
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
  pg <- DimPlot(tSNEobj, reduction = "tSNE", ShapeColumn=ShapeColumn,IdColumn='SAMPLE_NAME', groupColumn='SAMPLE_GROUP',
         ColorColumn=ColorColumn,label=label, title="tSNE",palette=palette,outFile=pdfFile) 
  return(pg)
}

##################################################################

BetaVlnPlot <- function(beta, meta, SAMPLEID = "SAMPLE_NAME", outFile = NULL, alpha = 1) {
  suppressMessages(suppressWarnings(library(ggplot2)))
  options(ggplot2.verbose = FALSE)
  TargetIDs <- rownames(beta)
  validIds <- intersect(meta$SAMPLE_NAME, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$SAMPLE_NAME %in% validIds]
  if (length(validIds) > 0) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$SAMPLE_NAME. \n")
    return(NULL)
  }
  colnames(beta) <- newIDs
  suppressMessages({
    used <- reshape2::melt(t(as.matrix(beta)))
  })
  colnames(used)[1] <- "ID"
  used$value <- as.numeric(used$value) #* 100
  meta <- meta[order(meta$SAMPLE_GROUP), ]
  rownames(meta) <- as.character(meta$SAMPLEID)
  orderedIDs <- meta$SAMPLEID

  GROUP1 <- meta$SAMPLE_GROUP[match(as.character(used$ID), meta$SAMPLEID)]
  used$GROUP <- factor(GROUP1, levels = unique(meta$SAMPLE_GROUP))
  uniqCols <- standardColors()[1:length(unique(meta$SAMPLE_GROUP))]
  uniqComb <- data.frame(GROUP = unique(meta$SAMPLE_GROUP), COLOR = uniqCols)

  cat("\n generate violin plot ...\n")
  pg <- ggplot(used, aes(x = ID, y = value), alpha = alpha) +
    geom_violin(aes(x = ID, y = value, fill = GROUP), trim = FALSE) +
    theme_classic(base_size = 10) +
    labs(y = "methylation level", x = "ID") +
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
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = F)
    } else {
      imgWidth <- 10 + ncol(beta) / 10
      ggsave(file = outFile, pg, width = imgWidth, height = imgHeight, units = "in", limitsize = T)
    }
    cat("\n\t", basename(outFile), "[saved]")
  }
  options(ggplot2.verbose = TRUE)
  return(pg)
}


##################################################################

BetaBeePlot <- function(beta, meta, SAMPLEID = "SAMPLE_NAME", outFile = NULL, alpha = 1, orderByGroup=FALSE, ylab="methylation level", xlab="ID", legend=TRUE) {
  # https://r-charts.com/distribution/ggbeeswarm/
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
  suppressMessages(suppressWarnings(library("grid")))
  options(ggplot2.verbose = FALSE)
  dotSize <- max(0.3, 1 - log10(nrow(beta)+1) / 5)
  TargetIDs <- rownames(beta)
  validIds <- intersect(meta$SAMPLE_NAME, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$SAMPLE_NAME %in% validIds]
  if (length(validIds) ==1) {
    beta=data.frame(beta[, validIds])
    rownames(beta) <- rownames(beta)
    colnames(beta) <- validIds
    meta <- meta[validIds, ]
  }else  if (length(validIds) > 1) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$SAMPLE_NAME. \n")
    return(NULL)
  }
  colnames(beta) <- newIDs
  suppressMessages({
    used <- reshape2::melt(as.matrix(beta))
  })
  used$value <- as.numeric(as.character(used$value))
  colnames(used)[2] <- "ID"
  used$value <- as.numeric(used$value) #* 100

  if(orderByGroup){
      meta <- meta[order(meta$SAMPLE_GROUP), ] # order GROUP
  }
  orderedIDs <- meta$SAMPLEID # order SMAPLEID by GROUP
  rownames(meta) <- as.character(meta$SAMPLEID)

  GROUP1 <- meta$SAMPLE_GROUP[match(as.character(used$ID), meta$SAMPLEID)]
  used$GROUP <- factor(GROUP1, levels = unique(meta$SAMPLE_GROUP))
  uniqCols <- standardColors()[1:length(unique(meta$SAMPLE_GROUP))]
  uniqComb <- data.frame(GROUP = unique(meta$SAMPLE_GROUP), COLOR = uniqCols)
  cat("\n generate dotplot ...\n")
  pg <- ggplot(used, aes(x = ID, y = value, color = GROUP), alpha = alpha) +
    geom_quasirandom(cex = dotSize) +
    theme_classic(base_size = 10) +
    labs(y = ylab, x = xlab) +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) +
    scale_color_manual(
      name = "GROUP",
      labels = uniqComb$GROUP,
      values = uniqComb$COLOR
    ) +
    scale_x_discrete(limits = orderedIDs) #  specify order on the X axis
  pg1 <- pg + theme(legend.position = "none")
  if(legend){
    pg2 <- cowplot::get_legend(pg + theme(legend.position = "right") + guides(color = guide_legend(ncol = 1)))
    imgHeight <- 5 + max(nchar(meta$SAMPLEID)) / 20
    #legendWidth <- ifelse(max(nchar(meta$SAMPLE_GROUP))<30, 1, 2)  # control the width of legend
    plots <- patchwork::wrap_plots(pg1, pg2, ncol = 1, widths = 10)  
  }else{
    plots <- pg1
    imgHeight <- 5 
  }

  if (!is.null(outFile)) {
    if (ncol(beta) > 20) {
      imgWidth <- 5 + ncol(beta) / 5 + nrow(beta) / 400
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

BetaBeePlot_SNP <- function(beta, meta, SAMPLEID = "SAMPLE_NAME", outFile = NULL, alpha = 1, ctrlgrp="germline",low_cutoff=0.3,  high_cutoff=0.7) {
  # https://r-charts.com/distribution/ggbeeswarm/
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
    if(sum(grepl(ctrlgrp, meta$SAMPLE_GROUP))==0){
     # no control group found, color dot by SAMPLE_GROUP instead of AA,AB,BB
     plot1 <- BetaBeePlot(beta, meta, SAMPLEID = SAMPLEID, outFile = outFile, alpha = alpha)
     return (plot1)
  }
  options(ggplot2.verbose = FALSE)
  dotSize <- max(0.3, 1 - log10(nrow(beta)+1) / 5)
  TargetIDs <- rownames(beta)
  validIds <- intersect(meta$SAMPLE_NAME, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$SAMPLE_NAME %in% validIds]
  if (length(validIds) ==1) {
    beta=data.frame(beta[, validIds])
    rownames(beta) <- rownames(beta)
    colnames(beta) <- validIds
    meta <- meta[validIds, ]
  }else  if (length(validIds) > 1) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$SAMPLE_NAME. \n")
    return(NULL)
  }
  colnames(beta) <- newIDs

  ctrls <- meta[grep(ctrlgrp, meta$SAMPLE_GROUP),"SAMPLEID"]
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
  meta <- meta[order(meta$SAMPLE_GROUP), ] # order GROUP
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

BetaBeePlot_single_chr <- function(beta, meta, SAMPLEID = "SAMPLE_NAME", outFile = NULL, alpha = 0.5,chr="chr11", probeset='chr11p15') {
  # to be done
  # https://r-charts.com/distribution/ggbeeswarm/
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
  suppressMessages(suppressWarnings(library("reshape2")))
  if(!is.null(probeset)){
    probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
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
    probes.all <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/anno.uniq_harmonized.liftover.rds")
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
  validIds <- intersect(meta$SAMPLE_NAME, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$SAMPLE_NAME %in% validIds]
  if (length(validIds) ==1) {
    beta=data.frame(beta[, validIds])
    rownames(beta) <- rownames(beta)
    colnames(beta) <- validIds
    meta <- meta[validIds, ]
  }else  if (length(validIds) > 1) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$SAMPLE_NAME. \n")
    return(NULL)
  } 
  colnames(beta) <- newIDs 
  beta$Probe=rownames(beta)
  beta$CATEGORY= anno[common_probes,"CATEGORY"]   
  suppressMessages({
    used <- reshape2::melt(beta, id.vars = c("Probe", "CATEGORY"),variable.name = "ID",value.name = "value")
  })
  used <- used[used$CATEGORY %in% c("paternal","maternal"),]
  meta <- meta[order(meta$SAMPLE_GROUP), ] # order GROUP
  orderedIDs <- meta$SAMPLEID # order SMAPLEID by GROUP
  rownames(meta) <- as.character(meta$SAMPLEID)
  used$value <- as.numeric(as.character(used$value))
  if(nrow(used)<5){
    stop("Not enough probes found/ matched (<5).")
  }
  cat("\n generate dotplot ...\n")
  pg <- ggplot(used, aes(x = ID, y = value, color = CATEGORY)) +
    geom_quasirandom(cex = dotSize,alpha = alpha) +
    theme_classic(base_size = 10) +
    labs(y = "methylation level", x = "ID", subtitle=paste0(probeset,":", chr) ) +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) +
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

BetaBeePlot_orgin <- function(beta, meta, SAMPLEID = "SAMPLE_NAME", outFile = NULL, alpha = 0.5,probesets=NULL, useNA=FALSE, width=NULL, height=NULL, group="ORIGIN") {
  # https://r-charts.com/distribution/ggbeeswarm/
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
  suppressMessages(suppressWarnings(library("reshape2")))
  if(!is.null(probeset)){
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
  common_probes <- intersect(rownames(anno), rownames(beta))
  beta <- beta[common_probes, ]

  options(ggplot2.verbose = FALSE)
  dotSize <- max(0.3, 1 - log10(nrow(beta)+1) / 5)
  TargetIDs <- rownames(beta)
  validIds <- intersect(meta$SAMPLE_NAME, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$SAMPLE_NAME %in% validIds]
  if (length(validIds) ==1) {
    beta=data.frame(beta[, validIds])
    rownames(beta) <- rownames(beta)
    colnames(beta) <- validIds
    meta <- meta[validIds, ]
  }else  if (length(validIds) > 1) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$SAMPLE_NAME. \n")
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
 
  #meta <- meta[order(meta$SAMPLE_GROUP), ] # order GROUP
  #orderedIDs <- meta$SAMPLEID # order SMAPLEID by GROUP
  #rownames(meta) <- as.character(meta$SAMPLEID)
  used$value <- as.numeric(as.character(used$value))
  if(nrow(meta)==1){
      cat("\n generate dotplot [single sample]...\n")
      

        pg_sep <- ggplot(used, aes(x = 1, y = value, color = CATEGORY)) +
          geom_quasirandom(cex = dotSize,alpha = alpha, width = 0.3) +
          stat_summary(fun = median, geom = "errorbar", aes(ymin = after_stat(y), ymax = after_stat(y)), 
          width = 0.5, linewidth = 0.7, color="grey30") + 
          facet_wrap(~ CATEGORY, nrow = 1)+
          theme_classic(base_size = 10) +
          theme(axis.text.x = element_blank(),axis.ticks.x = element_blank(),
          panel.border = element_rect(color = "grey20", fill = NA, linewidth = 0.5)) +
          labs(y = "methylation level", x = "GROUP", title=newIDs) +
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
        geom_quasirandom(cex = dotSize,alpha = alpha) +
        theme_classic(base_size = 10) +
        facet_wrap(~CATEGORY, scales = "free_x") +
        labs(y = "methylation level", x = "ID") +
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

BetaBeeswarm_chr <- function(beta, meta, SAMPLEID = "SAMPLE_NAME", outFile = NULL, probesets=NULL, pdfFolder='pdf'){
  # Load required libraries
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
  library(reshape2)
  #================================================================
  # prepare chromosome
  beta <- as.data.frame(beta)
  if(!is.null(probesets)){
    probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
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
    probes.all <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/anno.uniq_harmonized.liftover.rds")
    chr <- paste0("CHR_", toupper(version))
    mapinfo <- paste0("MAPINFO_", toupper(version))
    anno <- probes.all[probes.all$NAME %in% rownames(beta), c(chr, mapinfo, "UCSC_REFGENE_NAME")]
    colnames(anno) <- c("CHR", "MAPINFO", "GENE")
  }
  common_probes <- intersect(rownames(anno), rownames(beta))
  beta <- beta[common_probes, ]
  #================================================================
  # prepare plot title
  validIds <- intersect(meta$SAMPLE_NAME, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$SAMPLE_NAME %in% validIds]
  if (length(validIds) ==1) {
    beta=data.frame(beta[, validIds])
    rownames(beta) <- rownames(beta)
    colnames(beta) <- validIds
    meta <- meta[validIds, ]
  }else if (length(validIds) > 1) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$SAMPLE_NAME. \n")
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

BetaBeeswarm_chr_color <- function(beta, meta, SAMPLEID = "SAMPLE_NAME", outFile = NULL, probesets=NULL,pdfFolder=FALSE){
  # Load required libraries
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
  suppressMessages(suppressWarnings(library(reshape2)))

  #================================================================
  # prepare chromosome
  if(!is.null(probeset)){
    probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
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
      probes.all <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/anno.uniq_harmonized.liftover.rds")
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
  validIds <- intersect(meta$SAMPLE_NAME, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$SAMPLE_NAME %in% validIds]
  if (length(validIds) ==1) {
    beta=data.frame(beta[, validIds])
    rownames(beta) <- rownames(beta)
    colnames(beta) <- validIds
    meta <- meta[validIds, ]
  }else if (length(validIds) > 1) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$SAMPLE_NAME. \n")
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

BetaHeatmap <- function(beta, meta, SAMPLEID = "SAMPLE_NAME", annoColumn = "SAMPLE_GROUP", clusterRows = TRUE, clusterColumns = TRUE, 
   outFile = NULL, imgSizeFactor=0.5) {
  suppressMessages(library(circlize))
  suppressMessages(library(ComplexHeatmap))
  suppressMessages(library(edgeR))
  suppressMessages(library(RColorBrewer))
  if( SAMPLEID != "SAMPLE_NAME"){
     cat("\nINFO: use alternative label.",SAMPLEID ,"\n")
  }
  TargetIDs <- rownames(beta)
  validIds <- intersect(meta$SAMPLE_NAME, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  if (length(validIds) > 0) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$SAMPLE_NAME. \n")
    return(NULL)
  }
  colnames(beta) <- meta$SAMPLEID

  meta <- meta[order(meta$SAMPLE_GROUP), ] # order GROUP
  beta <- beta[, as.character(meta$SAMPLEID)] # order SMAPLEID by GROUP
  rownames(meta) <- as.character(meta$SAMPLEID)

  if (!"COLOR" %in% colnames(meta)) {
    groupNum <- length(unique(meta$SAMPLE_GROUP))
    usedColors <- standardColors()[1:groupNum]
    meta$COLOR <- usedColors[as.integer(as.factor(meta$SAMPLE_GROUP))]
  }

  pheno <- intersect(annoColumn, colnames(meta))
  annotation <- data.frame(meta[, pheno])
  colnames(annotation) <- pheno
  rownames(annotation) <- meta$SAMPLEID
  used <- na.omit(beta) # remove NA 7/13/2022
  used <- used[rowSums(abs(used)) > 0, ] # remove rows with all 0s 7/13/2022, 5/25/2023
  anno_colors <- list()
  for (i in 1:ncol(annotation)) {
    if (colnames(annotation)[i] != "SAMPLE_GROUP") { # convert to factor
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
  if ("SAMPLE_GROUP" %in% pheno) { # keep GROUP order in legend
    top_ha <- HeatmapAnnotation(
      df = annotation,
      col = anno_colors,
      annotation_name_side = "right",
      annotation_legend_param = list(SAMPLE_GROUP = list(title = "GROUP", at = unique(annotation[, 1])))
    )
  } else {
    top_ha <- HeatmapAnnotation(
      df = annotation,
      col = anno_colors,
      annotation_name_side = "right"
    )
  }
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

BetaCircularHeatmap <- function(beta, meta, probes.all = NULL,probeset=NULL, version = "HG19", SAMPLEID = "SAMPLE_NAME", sectionColumn = "SAMPLE_GROUP", sectionLabels = NULL, outFile = NULL, nchars = 5) {
  # values of SAMPLEID column, sectionColumn must be present in meta column names
  #
  library(ComplexHeatmap)
  # https://jokergoo.github.io/circlize_book/book/circos-heatmap.html
  library(circlize)
  library("colorRamp2")
  library(grid)
  library(gridBase)

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
  circlize_plot <- function(beta_list, beta_anno, sectionLabels = NULL, colors = col_meth, track_height = 0.1) {
    if (is.null(sectionLabels)) {
      sectionLabels <- names(beta_list)
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

    pos <- circos.heatmap.get.x(seq(row(dat1)))
    circos.labels(pos$sector[idx], x = pos$x[idx], labels = geneSymbols, side = "outside", cex = 0.8) #
    print(sectionLabels)
    print(head(pos))
    for (i in seq(length(beta_list))) {
      cat("\nINFO: process section #", x, sectionLabels[x], "\n")
      dat <- beta_list[[i]]
      # dat <- apply(dat, 2, as.numeric)
      circos.heatmap(dat, cluster = FALSE, col = colors, split = probe_info$CHR, track.height = track_height)
      circos.track(track.index = get.current.track.index(), panel.fun = function(x, y) {
        xlim <- get.cell.meta.data("xlim")
        ylim <- get.cell.meta.data("ylim")
        if (CELL_META$sector.numeric.index == n) { # the last sector
          n <- ncol(dat)
          offset <- max(1, 8 - i * 3)
          circos.text(max(xlim) + convert_x(offset, "mm"),
            mean(ylim), sectionLabels[i],
            cex = 0.8, adj = c(0, 0.5), col = "blue", facing = "bending.inside"
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
    probesets <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds")
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
      probes.all <- readRDS("/home/hjin/projects/ImprintomeR/package/inst/extdata/anno.uniq_harmonized.liftover.rds")
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
    beta_list[[x]] <- beta[rownames(beta_anno), rownames(meta)[meta[, sectionColumn] %in% grpLabel]]
  }
  print(length(beta_list))
  names(beta_list) <- substr(gsub("[[:space:]]", "_", trimws(grpLabels)), 1, nchars) # trim each element to nchars

  # generate circular heatmap
  circos.clear()
  circle_size <- unit(1, "snpc")
  if (is.null(outFile)) {
    timeStamp <- substr(strtrim(gsub("[-: ]", "", Sys.time()), 16), 5, 12) # "11301304"
    outFile <- paste0("circular_heatmap_", timeStamp, ".pdf")
  }
  pdf(outFile, width = 10, height = 8)
  pushViewport(viewport(
    x = 0, y = 0.5, width = circle_size, height = circle_size,
    just = c("left", "center")
  ))
  par(omi = gridOMI(), new = FALSE)
  circlize_plot(beta_list, beta_anno, colors = col_meth, track_height = 0.1)
  upViewport()
  draw(lgd_meth, x = circle_size, just = "left")
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

VizNineSquaresChr11 <- function(datFile, metaFile, outFile=NA,title="chr11.p15 classifier",ggside="density", splitside="group"){
tmp <- VizNineSquares(datFile, metaFile, 
  ShapeColumn="chr11p15", IdColumn='SAMPLE_NAME', groupColumn='SAMPLE_GROUP', ColorColumn="COLOR",
  X="X", Y="Y",  xlab="IC1_mean", ylab="IC2_mean",
  xlims=c(0,1) ,ylims=c(0,1), hlines=c(0.3,0.7), vlines=c(0.3,0.7),  
  outFile=outFile, label=F, title=title,palette="Default",alpha=0.6,dotSize=NULL, ggside="density", splitside="group")

}

VizNineSquares  <- function(datFile, metaFile, 
  ShapeColumn="imprintome_status", IdColumn='SAMPLE_NAME', groupColumn='SAMPLE_GROUP', ColorColumn="COLOR", 
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
#  01/20/2026,15:29:49 
##################################################################
#================================================================

PlotPolar <- function(data, outFile=NULL,colorColumn="SAMPLE_GROUP", title="ImprintomeR:Polar",palette="default", alpha=0.5) {
#' Plot Imprintome Polar Coordinates
#' @param data A dataframe containing 'maternal_score', 'paternal_score', and 'sample_id'
#' @return A ggplot object    
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
    geom_vline(xintercept = boundary_lines, 
               color = "#2ecc71", # A professional "Bio-Green"
               linetype = "solid", 
               linewidth = 0.8, 
               alpha = 0.6) +       
    geom_hline(yintercept = 0.2, color = "grey60", linewidth = 0.7, linetype = "solid")+
    geom_point(aes(fill = .data[[colorColumn]]),color= "grey30",shape=21,size=dotSize, alpha = alpha) +
    coord_polar(theta = "x", start =0,clip = "off") +  # move 0 degree to 
    scale_x_continuous(
      limits = c(0, 360),
      breaks = degree_breaks,
      labels = mechanism_labels,
      expand = c(0, 0)
    ) +
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
        plotWidth <- 10 # 5 + log10(ncol(data)+1) * 6
        plotHeight <- 10 # 5 + log10(nrow(data)+1) * 7
        ggsave(file=outFile,pg,width=plotWidth,height=plotHeight,units="in", limitsize = TRUE)
    }
    return(pg)
}

#==============================================================

MirrorDensity <- function(betaFile,  metaFile, SAMPLEID="SAMPLE_NAME",
                                  probeset = probeset_options,
                                  outFile = NULL ) {
    library(ggplot2)
    suppressMessages(suppressWarnings(library(dplyr)))  
    library(tidyr)
    input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
    meta <- input[["meta"]]
    beta <- input[["beta"]]
    tmp  <- SubsetBeta_By_Probeset(beta, probeset = probeset, prefix = NULL)
    
    probesets <- tmp[["probesets"]]
    beta <- tmp[["beta"]]
    beta <- na.omit(beta) 

    validIds <- intersect(meta$SAMPLE_NAME, colnames(beta))
    if (length(validIds) ==0) {
      cat("\nERROR: beta column does not match meta$SAMPLE_NAME. \n")
      return(NULL)
    } 
    meta <- meta[meta$SAMPLE_NAME %in% validIds, , drop = FALSE]
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
        names_to = "SAMPLE_NAME", 
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
      coord_flip() + facet_wrap(~SAMPLE_NAME) +
      # Formatting
      scale_fill_manual(values = c("maternal" = "#E41A1C", "paternal" = "#377EB8")) +
      theme_minimal() +
      labs(
        title = "Methylation Shift",
        subtitle= paste0("probeset:", probeset),
        x = "Beta Value", 
        y = "Density (Paternal < 0 > Maternal)"
      )

  
    if(!is.null(outFile)){
      imgSize <- ifelse(nrow(beta) >20, 12, 6)
      ggsave(file=outFile,pg,width=imgSize,height=imgSize,units="in", limitsize = TRUE)
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
    mutate(Delta = beta - 0.5)

  pg <- ggplot(plot_data, aes(x = MAPINFO, y = Delta, color = ORIGIN)) +
    # Reference Line at 0 (Normal Imprinting)
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50", alpha = 0.5) +
    # The Probes
    geom_point(alpha = 0.6, size = 0.5) +
    # Color Scheme (Maternal vs Paternal)
    scale_color_manual(values = c("maternal" = "#E41A1C", "paternal" = "#377EB8")) +
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
      title = title, #paste("Imprinting Rainfall Plot:", sampleID),
      subtitle = "Clusters away from 0 indicate imprinting alterations",
      y = "Delta Methylation (Beta - 0.5)",
      x = "Genomic Position"
    ) +
    ylim(-0.55, 0.55)
  if(!is.null(outFile)){
        ggsave(file=outFile,pg,width=12,height=6,units="in", limitsize = TRUE)
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
    metric = gsub("maternal", "mat", gsub("paternal", "pat", rownames(df))),
    value = as.numeric(df[,1])
  )
  
  plot_data <- plot_data[str_order(plot_data$metric, numeric = TRUE), ]
  n_metrics <- nrow(plot_data)
  plot_data$value_scaled <- plot_data$value + 1
  
  # 2. Add Color Logic (Shared by dots and labels)
  plot_data <- plot_data %>%
    mutate(
      idx = row_number(),
      point_color = case_when(
        value > 0.4  ~ "brown",
        value < -0.4  ~ "blue",
        TRUE       ~ "grey30"
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
    
    # DOTS (Colored blue/brown based on value)
    geom_point(aes(color = point_color), size = pt.size, show.legend = FALSE) +
    
    # Scale Labels at 3 o'clock
    annotate("text", x = pos_3_oclock, y = c(0, 1, 2), label = c("-1", "0", "1"), 
             color = "purple", size = fontsize, fontface = "bold", vjust = -0.7) +
    
    # METRIC LABELS (Colored blue/brown to match dots)
    geom_text(data = label_df, 
              aes(x = idx, y = 2.15, label = metric, angle = angle_final, 
                  hjust = hjust, color = point_color),
              size = fontsize, show.legend = FALSE) +
    
    # Use Identity to interpret "blue" as Blue
    scale_color_identity() +
    
    coord_polar(start = 0) +
    scale_y_continuous(limits = c(-0.6, 3)) + 
    scale_x_continuous(limits = c(1, n_metrics + 1)) +
    
    labs(title = title, x = NULL, y = NULL) +
    theme_minimal() +
    theme(
      axis.text = element_blank(),
      panel.grid = element_blank(),
      plot.title = element_text(size = 12, face = "bold", hjust = 0.5),
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
  anno_path <- "/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds"
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
    
    scale_fill_manual(values = c("maternal" = "#E69F00", "paternal" = "#56B4E9")) +
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
      x = "Methylation Level (Beta)",
      y = "Chromosome"
    )

  # 6. Save
  if (!is.null(outFile)) {
    # Since we only have ~24 ridges per panel now, height is much smaller
    ggsave(file = outFile, pg, width = 10, height = 8, units = "in")
    cat("\n\t", basename(outFile), "[saved]")
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
  anno_path <- "/home/hjin/projects/ImprintomeR/package/inst/extdata/probesets_hg19.rds"
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
    
    scale_fill_manual(values = c("maternal" = "#E69F00", "paternal" = "#56B4E9")) +
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
      y = "Methylation Level (Beta)"
    )

  # 6. Save
  if (!is.null(outFile)) {
    # Width is fixed for 6 columns; height grows with number of chromosomes
    n_chrom <- length(unique(used$Chromosome))
    dynamic_height <- 3 * ceiling(n_chrom / 6)
    width <- ifelse(n_chrom ==1, 3, n_chrom )
    ggsave(file = outFile, pg, width = width, height = dynamic_height, units = "in")
    cat("\n\t", basename(outFile), "[saved]")
  }

  return(pg)
}

#================================================================

Plot_ICR_var_med <- function(plot_data, outFile, project="cohort", style="beeswarm", min_cpg=3){
  suppressMessages(suppressWarnings(library("dplyr")))
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

    txtFile<- paste0(tools::file_path_sans_ext(basename(outFile)),"_aggregated_by_group.txt")
    write.table(final_data, txtFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
    cat("\n",basename(txtFile),"[saved]")

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
    ggsave(file=outFile,pg,width=img_width,height=img_height,units="in", limitsize = FALSE)
    cat(paste0('\nINFO:',basename(outFile),' [saved]'))

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
# 1. On the Line: The imprinting loss is "clonal"â€”it occurred in the ancestor of all tumor cells.
# 2. Far Below the Line: The sample has low deviation despite high purity. This indicates "Subclonal LOI" or "Stochastic Drift", where only some tumor cells have lost the imprint.
# 3. Above the Line: This is mathematically impossible in a perfect model (you can't be more than 100% deviated). It usually suggests that the Global Purity estimate for that sample was too low and should be re-evaluated.
# plot_imp_consistency(fit_data)

#================================================================
#================================================================


#' Calculate Global Biological Age
#' @param beta_matrix A matrix where rows are CpG IDs and columns are Sample Names
#' @return A data frame with HorvathAge and other clock results

BetaBeePlot_orgin2 <- function(beta, meta, SAMPLEID = "SAMPLE_NAME", outFile = NULL, alpha = 0.5,probesets=NULL, useNA=FALSE, width=NULL, height=NULL, group="ORIGIN") {
  # https://r-charts.com/distribution/ggbeeswarm/
  suppressMessages(suppressWarnings(library(ggplot2)))
  suppressMessages(suppressWarnings(library("ggbeeswarm")))
  suppressMessages(suppressWarnings(library("reshape2")))
  if(!is.null(probeset)){
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
  common_probes <- intersect(rownames(anno), rownames(beta))
  beta <- beta[common_probes, ]

  options(ggplot2.verbose = FALSE)
  dotSize <- max(0.3, 1 - log10(nrow(beta)+1) / 5)
  TargetIDs <- rownames(beta)
  validIds <- intersect(meta$SAMPLE_NAME, colnames(beta))
  meta$SAMPLEID <- meta[, SAMPLEID]
  newIDs <- meta$SAMPLEID[meta$SAMPLE_NAME %in% validIds]
  if (length(validIds) ==1) {
    beta=data.frame(beta[, validIds])
    rownames(beta) <- rownames(beta)
    colnames(beta) <- validIds
    meta <- meta[validIds, ]
  }else  if (length(validIds) > 1) {
    meta <- meta[validIds, ]
    beta <- beta[, validIds]
  } else {
    cat("\nERROR: beta column does not match meta$SAMPLE_NAME. \n")
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
    geom_quasirandom(cex = dotSize, alpha = alpha, width = 0.3) +
    stat_summary(fun = median, geom = "errorbar", 
                 aes(ymin = after_stat(y), ymax = after_stat(y)), 
                 width = 0.5, linewidth = 0.7, color="grey30") + 
    # Use the ID as the title for this specific panel
    labs(title = current_id, y = "Methylation", x = NULL) +
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


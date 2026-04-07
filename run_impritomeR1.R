#!/usr/bin/env Rscript
# date: 01/20/2026
# author: Hongjian Jin @ St Jude Children's Research Hospital
library(optparse)
option_list <- list(
    make_option(c("-i", "--input"), type="character",default=NA,
    help="character.  input format [default %default]
                    when running -s 22 , -s 28, use RGset.rds instead
                    when running -s 22 , -s 24, use snpBeta.txt instead 
                    other runs , use beta.txt or beta.rds ")
    ,make_option(c("-m", "--metaData"), type="character",default=NA,
    help="character. meta file [default %default] ")
    ,make_option(c("-a", "--assay"), type="character",default="EPIC",
    help="character. HM450K,EPIC,EPICV2 are supported [default %default] ")    
    ,make_option(c("-o", "--output"), type="character",default=NA,
    help="character. outdir/prefix [default %default] ")
    ,make_option(c("-N", "--topn"), type="integer",default=1000,
    help="integer.  top N most variable features for PCA /tSNE [default %default] ") 
    ,make_option(c("-c", "--chr"), type="character",default="chr5",
    help="integer. check single chromosome [default %default] ")    
    ,make_option(c("-r", "--ICRs"), type="character",default=NULL,
    help="integer. ICRs in bed format.   [default %default] 
                or pre-defined datasets as follows:
                NanoImprint, Joshi, Court, Rosenski")     
    ,make_option(c("-p", "--probeset"), type="character",default=NULL,
    help="character. only use probes present in probeset [default %default] 
                    Jima: WGBS
                    Joshi:Illumina Infinium HumanMethylation450
                    NanoImprint: from Pacbio data
                    chr11p15: 
                    all: Jima+Joshi+NanoImprint+chr11p15
                    selected: present in 2+ datasets (Jima,Joshi,NanoImprint,chr11p15)
                    classifer2     ")
    ,make_option(c("-s", "--steps"), type="character",default="2",
    help="character.  steps to run [default %default] 
                0 - subset beta matrix by probeset
                1 - PCA & tSNE
                2 - calculate IDS, Angle and PlotPolar 
                3 - perform global survey at chromosome level and PlotPolar for single sample
                31 - perform global survey at chromosome level and PlotPolar for cohort
                5 - Beeplot_chr_vs_other_single & BetaBeePlot_single_chr
                51 - PlotRidgeline_chr_origin for cohort
                6 - PlotRainFall 
                7 - PlotRadar
                8 - ICR level variance
                9 - MirrorDensity and BetaBeePlot_orgin
                10 - generate heatmap after aggregating probes by gene(mean) 

                ")    
                
)
parser <- OptionParser(usage="%prog -i <input.txt> -m <meta.txt> -o <outPrefix>",
                description = "Perform UPD analysis based on imprintomeR package",
                option_list = option_list,
                epilogue =paste( "Examples:",
                " i=QC.Raw/CAB_7205_beta.txt",
                " m=CAB.7205_sampleInfo.txt",
                " run_impritomeR1.R -i $i -m $m -o imprintomeR/CAB_7025 -p classifier2 -s 0", 
                " run_impritomeR1.R -i $i -m $m -o imprintomeR/CAB_7025 -p NanoImprint", 
                " run_impritomeR1.R -i $i -m $m -o imprintomeR/CAB_7025 -p chr11p15", 
                " run_impritomeR1.R -i $i -m $m -o imprintomeR/CAB_7025 -p classifier2 -s 5 -c chr5",                 
                " run_impritomeR1.R -i $i -m $m -o imprintomeR/CAB_7025 -p classifier2 -s 51 ", 
                " r=/research/rgs01/home/clusterHome/hjin/projects/ImprintomeR/ICR/regions14_hg19_sort.bed",
                " run_impritomeR1.R -i $i -m $m -o CAB_7025 -r $r -s 8",
                " run_impritomeR1.R -i $b -m $m -o Clay2019_Court_beewarm -r Court -s 8",
                " run_impritomeR1.R -i $b -m $m -o Clay2019_Rosenski_beewarm -r Rosenski -s 8",
                "\n ", sep="\n"))
args<-NA
result<-tryCatch({
        args <- parse_args(parser, positional_arguments = TRUE)  # TRUE = c(0, Inf), FALSE,1,  c(1,2)
        }, warning=function(w){
                message(w)
        }, error=function(e){
                message(e)
    })
opt <- args$options
if (any(is.na(args))|| any(is.na(opt)) ) {
    print_help(parser)
    quit("no")
}
################################################
.get_script_dir <- function() {
    cmd_args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", cmd_args, value = TRUE)
    if (length(file_arg) > 0) {
        return(dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE)))
    }
    this_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
    if (!is.null(this_file) && nzchar(this_file)) {
        return(dirname(normalizePath(this_file, winslash = "/", mustWork = TRUE)))
    }
    normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

.load_imprintomer_modules <- function(base_dir) {
    module_files <- c(
        "module_utilities.R",
        "module_io.R",
        "module_probeset.R",
        "module_aggregation.R",
        "module_scoring.R",
        "module_plotting.R"
    )
    for (mf in module_files) {
        fpath <- file.path(base_dir, "R", mf)
        if (!file.exists(fpath)) {
            stop(paste0("Required module not found: ", fpath))
        }
        source(fpath)
    }
}

.script_dir <- .get_script_dir()
.load_imprintomer_modules(.script_dir)
betaFile <- normalizePath(opt$input) 
metaFile <- normalizePath(opt$metaData)
icrFile <- opt$ICRs
if(!is.null(icrFile)){
    ICR_DIR <- "/research/rgs01/home/clusterHome/hjin/projects/ImprintomeR/ICR/"
    clean_input <- toupper(basename(icrFile))
    icrFile <- dplyr::case_when(
        clean_input %in% c("NANOIMPRINT") ~ paste0(ICR_DIR, "regions14_hg19_sort.bed"),
        clean_input %in% c("JOSHI") ~ paste0(ICR_DIR, "Joshi_mmc6_simple_merged_d2k.bed"),
        clean_input %in% c("COURT") ~ paste0(ICR_DIR, "Court_WGBS.ICR.hg19_simple.bed"),
        clean_input %in% c("ROSENSKI") ~ paste0(ICR_DIR, "Rosenski_Atlas_hg19_n81.bed"),
        TRUE ~ icrFile
    )
    icrFile <- normalizePath(icrFile)
}


test <- function(assay=c("450K","EPICv1","EPICv2")){
  if(!is.null(assay)){
    assay <- standardize_array(assay)
    assay <-  match.arg(assay)
  }
  cat("\nAssay:",assay, "\n")
}

prefix<- opt$output
if (! file.exists(metaFile)){
    stop(paste0("meta file not found:",metaFile))
}
if (! file.exists(betaFile)){
    stop(paste0("beta file not found:",betaFile))
}

outDir<- dirname(prefix)
if(outDir !="."){
dir.create(outDir, showWarnings = FALSE, recursive=TRUE)
}
outDir<-normalizePath(outDir)
prefix <- paste0(outDir,"/", basename(prefix))
probeset <- opt$probeset
steps <- as.integer(unlist(strsplit(opt$steps, ",")))

ncores <- opt$ncores # 10
topn <- opt$topn # 1000 number of features for PCA
assay <- opt$assay
threshhold  <- opt$threshhold

chr_string <- opt$chr
################################################
suppressMessages(suppressWarnings(library(minfi)))
suppressMessages(suppressWarnings(library(ggplot2)))

cat("\n[loading files ...]\n")

#input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
#beta<- input[["beta"]]
#meta<- input[["meta"]]    

assay <- toupper(opt$assay)
#================================================================
if( 0 %in% steps){
    input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
    beta<- input[["beta"]]
    meta<- input[["meta"]]   
    if(is.null(probeset)){
        cat(paste0('\nINFO: subset by meta'))
        library(data.table)
        outFile <- paste0(prefix,"_beta.txt")
        # 1. Convert to data.table and move rownames to a column named "TargetID"
        setDT(beta, keep.rownames = "TargetID")
        fwrite(beta, file=outFile,sep="\t",append=FALSE,quote = FALSE, na="NA")
        cat("\n[",basename(outFile),"[saved]")
    }else{
         cat(paste0('\nINFO: subset by probeset'))
         subset <-  SubsetBeta_By_Probeset(beta, probeset=probeset, prefix=prefix)
    }
   
}

if( 1 %in% steps){
    input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
    beta<- input[["beta"]]
    meta<- input[["meta"]]   
    cat("\nstep1. PCA\n")
    res1 <- Meth_PCA_Adv(beta,meta, ShapeColumn="SHAPE",IdColumn='SAMPLE_NAME', groupColumn='SAMPLE_GROUP', 
            ColorColumn="COLOR", scale=F,  topn = topn, outPrefix=prefix, label=FALSE, palette="Default")
}

if( 2 %in% steps){
    cat("\nstep2. polar logic based analyiss  \n")
    idsFile <- paste0(prefix,"_",probeset,"_IDS_result.txt")
    res <- AnalyzeImprintStatus (betaFile, metaFile, probeset = probeset)
    res <-  DetectMosaicism(res, roi_ref_mean = 0.06, roi_ref_sd = 0.03)
    write.table(res, idsFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
    cat("\n",basename(idsFile),"[saved]")

    pdfFile2 <-  paste0(prefix,"_",probeset,"_polar_plot_color.by.mechanism.pdf")
    xx <- PlotPolar(res,outFile=pdfFile2,colorColumn="Mechanism",title=paste("imprintomeR:",probeset)) #"SAMPLE_GROUP")
    cat("\n",basename(pdfFile2),"[saved]")
    pdfFile3 <-  paste0(prefix,"_",probeset,"_polar_plot_color.by.group.pdf")
    xx <- PlotPolar(res,outFile=pdfFile3,colorColumn="SAMPLE_GROUP",title=paste("imprintomeR:",probeset)) #"SAMPLE_GROUP")
    cat("\n",basename(pdfFile3),"[saved]")    
}
if( 3 %in% steps){
        cat("\nstep3. global survey at chromosome & single sample\n")
    input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
    beta<- input[["beta"]]
    meta<- input[["meta"]] 
    if(probeset == "classifier3"){
        newDir<-file.path(getwd(), "survey3")
    }else if(probeset == "signature_hc"){
        newDir<-file.path(getwd(), "survey_hc")
    }else {
         newDir<-file.path(getwd(), "survey")
    }
   
    dir.create(newDir, showWarnings = FALSE)
    prefix0 <- paste0(newDir, "/",basename(prefix))
    for (id in meta$SAMPLE_NAME ){ 
        if("ID2" %in% colnames(meta)){
            id_new <- meta$ID2[match(id, meta$SAMPLE_NAME)]
        }else{
            id_new <- id
        }
        res <- Survey_Global_Imprinting(beta, sampleID=id,probeset=probeset)
        outFile <- paste0(prefix0,"_",id_new,"_survey_IDS.txt")
        write.table(res, outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
        cat("\n",basename(outFile),"[saved]")
        pdfFile2 <-  paste0(prefix0,"_",id_new,"_polar_survey_color.by.Chromosome.png")
        xx <- PlotPolar(res,outFile=pdfFile2,colorColumn="Chromosome",title=paste(probeset,":",id_new ),alpha=0.7) #"SAMPLE_GROUP")
        cat("\n",basename(pdfFile2),"[saved]")  
    }

    
}
if( 31 %in% steps){
     cat("\nstep31. global survey at chromosome & cohort level\n")
    res <- Survey_Global_Imprinting_Batch(betaFile,metaFile,probeset=probeset,subset=chr_string,min_probes = 5,ids_cutoff = 0.2)
    outFile <- paste0(prefix,"_",probeset,"_",chr_string,"_survey_IDS.txt")
    write.table(res, outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
    cat("\n",basename(outFile),"[saved]")

    pdfFile2 <-  paste0(prefix,"_",probeset,"_",chr_string,"_polar_plot_color.by.Chromosome.png")
    xx <- PlotPolar(res,outFile=pdfFile2,colorColumn="Chromosome",title=paste("imprintomeR:",probeset,chr_string)) #"SAMPLE_GROUP")
    cat("\n",basename(pdfFile2),"[saved]")
    pdfFile3 <-  paste0(prefix,"_",probeset,"_",chr_string,"_polar_plot_color.by.group.png")
    xx <- PlotPolar(res,outFile=pdfFile3,colorColumn="SAMPLE_GROUP",title=paste("imprintomeR:",probeset,chr_string)) #"SAMPLE_GROUP")
    cat("\n",basename(pdfFile3),"[saved]")   
}

 
if( 5 %in% steps){
    cat("\nstep5. Beeplot_chr_vs_other_single\n")     
    input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
    beta<- input[["beta"]]
    meta<- input[["meta"]] 
    outFile <- paste0(prefix,"_",chr_string,"_", probeset,"_single_chr.pdf")
    SAMPLEID <- ifelse("ID2" %in% colnames( meta), "ID2", "SAMPLE_NAME")
    BetaBeePlot_single_chr(beta, meta, SAMPLEID = SAMPLEID, outFile = outFile, alpha = 0.5,chr=chr_string, probeset=probeset) 
    Beeplot_chr_vs_other_single(input, chrs=chr_string, prefix=paste0(prefix,"_",chr_string,"_", probeset),probeset=probeset)
}
#================================================================


if( 51 %in% steps){
    cat("\nstep51. PlotRidgeline_chr_origin for cohort\n")     
    input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
    beta<- input[["beta"]]
    meta<- input[["meta"]] 
    #outFile <- paste0(prefix,"_",chr_string,"_", probeset,"_densityBridge_splitby_chr_origin_cohort.png")
    #PlotRidgeline_cohort_chr_origin_(beta,  outFile = outFile, scale = 1.2, alpha = 0.8, probeset=probeset)
    outFile <- paste0(prefix,"_",chr_string,"_", probeset,"_vln_splitby_chr_origin_cohort.png")
    BetaDistribution_FacetByChrom (beta, outFile = outFile, alpha = 0.7,probeset=probeset)
}


#================================================================


if( 6 %in% steps){
        cat("\nstep6. rainfall plot\n")
    input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
    beta<- input[["beta"]]
    meta<- input[["meta"]] 
    if(probeset == "classifier3"){
        newDir<-file.path(getwd(), "rainfall3")
    }else {
         newDir<-file.path(getwd(), "rainfall")
    }
   
    dir.create(newDir, showWarnings = FALSE)
    prefix0 <- paste0(newDir, "/",basename(prefix))
    for (id in meta$SAMPLE_NAME ){ 
        if("ID2" %in% colnames(meta)){
            id_new <- meta$ID2[match(id, meta$SAMPLE_NAME)]
        }else{
            id_new <- id
        }
        pdfFile6 <-  paste0(prefix0,"_",id_new,"_rainfall_color.by.chr.png")
        xx <- PlotRainfall(beta, id, probeset=probeset,title=paste("Imprinting Rainfall Plot:",id_new) ,outFile=pdfFile6)
        cat("\n",basename(pdfFile6),"[saved]")  
        
    }

    
}
if( 7 %in% steps){
    cat("\nstep7. radar plot\n")
    input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
    beta<- input[["beta"]]
    meta<- input[["meta"]] 
    newDir<-file.path(getwd(), "radar")
    dir.create(newDir, showWarnings = FALSE)
    
   #  probeset <- "classifier2" ; prefix <- "GSE64244"
    dir.create(newDir, showWarnings = FALSE)
    prefix0 <- paste0(newDir, "/",basename(prefix))
    used <- AggregateByLocus(beta, probeset=probeset)
    for (id in meta$SAMPLE_NAME ){ 
        if("ID2" %in% colnames(meta)){
            id_new <- meta$ID2[match(id, meta$SAMPLE_NAME)]
        }else{
            id_new <- id
        }
        df1 <- used[, id, drop = FALSE]
        df1 <- (df1-0.5)*2
        pdfFile <-  paste0(prefix0,"_",id_new,"_radar.png")
        xx <- PlotRadar(df1, id=id_new, title=paste("Radar Plot:",id_new) , outFile=pdfFile)
        cat("\n",basename(pdfFile),"[saved]")  
        #break
    }

}        
if( 8 %in% steps){
    cat("\nstep8. ICR var analysis at cohort level \n")
    if(!is.null(icrFile)){
         cat("\nInfo: ICR set, ", basename(icrFile))
    }
   
    txtFile <- paste0(prefix,"_Var_Med_Drift.txt")
    if(file.exists(txtFile)){
        final_report <- read.table(txtFile, sep="\t",header=TRUE,fill=TRUE,stringsAsFactors = FALSE, as.is=TRUE,row.names=NULL ,check.names=FALSE ,comment.char = "")
        cat("\n[dim:",nrow(final_report)," rows x",ncol(final_report),"cols]")
    }else{
         final_report <- Calculate_impvar(betaFile, metaFile, icrFile,probeset=probeset, assay="EPICv1",genome="hg19",outFile=txtFile)
    }
   
    pdfFile <- paste0(prefix,"_Var_Med_Drift.pdf")
    Plot_ICR_var_med(final_report, pdfFile, project=basename(prefix))
}    
#================================================================

if(9 %in% steps){
  cat("\nstep9. generate mirror density with facet) .\n")
    outFile <- paste0(prefix,"_",probeset,"_MirrorDensity.pdf")
    input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
    meta <- input[["meta"]]  # LoadMeta(metaFile) 
    SAMPLEID <- ifelse("ID2" %in% colnames( meta), "ID2", "SAMPLE_NAME")
    res <- MirrorDensity (betaFile,  metaFile,SAMPLEID=SAMPLEID, probeset = probeset, outFile = outFile )
    cat("\n",basename(outFile),"[saved]") 

    beta<- input[["beta"]]
    subset <-  SubsetBeta_By_Probeset(beta, probeset=probeset, prefix=NULL)
    beta_subset <- subset[["beta"]]
    outFile <- paste0(prefix,"_",probeset,"_beeswarm_origin.pdf")
    BetaBeePlot_orgin2(beta_subset, meta, SAMPLEID = SAMPLEID, outFile = outFile, alpha = 0.8, probesets=probeset)
}
#================================================================
if(10 %in% steps){
  cat("\nstep10. generate heatmap after aggregating probes by gene(mean) .\n")
   input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
   beta<- input[["beta"]]
   meta<- input[["meta"]] 
  res9 <- AggregateByLocus(beta, probeset=probeset)
  outFile <- paste0(prefix,"_",probeset,"_aggregatedByLocus_beta.txt")
  write.table(cbind(gene=rownames(res9),res9), outFile, sep="\t", quote=FALSE, row.names=F, col.names=TRUE)
  #res10 <- CalcAvgByGrp(res9, meta)
  #outFile <- paste0(prefix,"_aggregatedByLocus_aveByGrp_beta.txt")
  #write.table(cbind(gene=rownames(res10),res10), outFile, sep="\t", quote=FALSE, row.names=F, col.names=TRUE)
  cat("\n[",basename(outFile),"[saved]")
  outFile1 <- paste0(prefix,"_",probeset,"_aggregated_heatmap_clusterRows.jpg")
  BetaHeatmap(res9, meta, SAMPLEID='SAMPLE_NAME',annoColumn=c("SAMPLE_GROUP","Imprintome"), clusterRows=TRUE, clusterColumns=TRUE, outFile=outFile1, imgSizeFactor=1 )
  outFile1 <- paste0(prefix,"_",probeset,"_aggregated_heatmap1_sortedRows.jpg")
  BetaHeatmap(res9, meta, SAMPLEID='SAMPLE_NAME',annoColumn=c("SAMPLE_GROUP","Imprintome"), clusterRows=FALSE, clusterColumns=TRUE, outFile=outFile1, imgSizeFactor=1 )  
  if("ID2" %in% colnames(meta)){
        outFile2 <- paste0(prefix,"_",probeset,"_aggregated_heatmap2.jpg")
        BetaHeatmap(res9, meta, SAMPLEID='ID2',annoColumn=c("SAMPLE_GROUP","Imprintome"), clusterRows=TRUE, clusterColumns=TRUE, outFile=outFile2, imgSizeFactor=1 )
  }  
}
#================================================================


cat("\n\nCheers!\n\n")
garbage<- gc()
q("no")

##################################################################
# History 
##################################################################
# 01/20/2026,Initial version
# 02/05/2026, add PlotRadar 




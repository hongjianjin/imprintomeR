# Auto-refactored from utilities2.R
# Module: io

CheckSheetName <-function(xlsxFile, sheetName){
    # check if a sheetName does exist in xlsxFile
    if (! file.exists(xlsxFile)) {
        cat(paste0("\nFile not found. [",basename(xlsxFile),"]\n"))
        foundSheet <- FALSE
       # stop("Exit...")
    }else{
        if (sheetName %in% getSheetNames(xlsxFile)) {
            foundSheet <- TRUE
        }else {
            foundSheet <- FALSE
        }
    }
    foundSheet
}
#-----------------------------------------------------
######################################################

SaveTable <- function(dat, sheetName = NULL, file = NULL, append = FALSE, colNames = T, rowNames = T, autoColWidth = TRUE) {
  if (any(length(dat)==0)){
     cat("\n\tError: Empty input for [SaveTable].")
     return(1)
  }
  if (!append) {
    wb1 <- createWorkbook()
    if (file.exists(file)) {
      unlink(file, force = TRUE)
      cat("\n\t[deleted existing workbook]")
    }
  } else {
    if (file.exists(file)) {
      wb1 <- loadWorkbook(file = file)
      cat("\n\t[loaded existing workbook]")
    } else {
      wb1 <- createWorkbook()
    }
  }
  options("openxlsx.borderColour" = "#4F80BD")
  options("openxlsx.borderStyle" = "thin")
  sheetName <- ifelse(is.null(sheetName), "sheet1", strtrim(sheetName, 30))
  if (file.exists(file)) {
    if (CheckSheetName(file, sheetName) == TRUE) {
      # sheet <- grep(sheetName, getSheetNames(file))
      removeWorksheet(wb1, sheet = sheetName)
      cat("[overwritten existing sheet]")
    }
  }
  cat("\n")
  addWorksheet(wb1, sheetName = sheetName, gridLines = FALSE)
    headerStyle <- createStyle(
      fontSize = 10, fontColour = "#FFFFFF", halign = "center",
      fgFill = "#4F81BD",borderColour = "black", borderStyle ="thin"
    )

  writeData(wb1, sheetName,
    x = as.data.frame(dat),
    colNames = colNames, rowNames = rowNames,     #tableStyle = "TableStyleLight9"
    headerStyle = headerStyle,
    borders = "rows",
    borderColour = openxlsx_getOp("borderColour", "#4F81BD"),
    borderStyle = openxlsx_getOp("borderStyle", "thin")
  )
  if (autoColWidth) {
    if (rowNames) {
      maxNcol <- ncol(dat) + 1
    } else {
      maxNcol <- ncol(dat)
    }
    setColWidths(wb1, sheetName, cols = 1:maxNcol, widths = "auto")
  }
  modifyBaseFont(wb1, fontSize = 10, fontName = "Arial Narrow")
  saveWorkbook(wb1, file, overwrite = TRUE)
  # cat("\t",basename(file),"[saved]\n")
}

#-----------------------------------------------------

LoadTable<-function(xlsxFile = xlsxFile, sheet=1, skipEmptyRows = FALSE, colNames = TRUE, rowNames=FALSE, startRow = 1){
    if (! grepl(".xls", basename(xlsxFile), ignore.case=T)){
        cat("\nYour input is not xlsx format.\n")
        df <- read.table(xlsxFile, sep="\t",header=colNames,fill=TRUE,stringsAsFactors = FALSE, quote="",row.names=NULL ,check.names=F)
    }else{
        suppressMessages(library("openxlsx"))
        df <- read.xlsx(xlsxFile, sheet = sheet, skipEmptyRows = skipEmptyRows, colNames = colNames, rowNames=rowNames,startRow = startRow)
    }
    return(df)
}

######################################################

CheckSentrixID <- function(ids) {
  # probably not useful, if no QC step is implemented.
  res1 <- grepl("^[0-9]{12}_R[0-9]{2}C[0-9]{2}$", ids)
  res2 <- grepl("^[0-9]{10}_R[0-9]{2}C[0-9]{2}$", ids)
  if (sum(res1) == length(ids)) {
    cat("\n[CheckSentrixID] INFO: sentrix_ID from st jude runs.")
  } else if (sum(res2) == length(ids)) {
    cat("\n[CheckSentrixID] INFO: sentrix_ID from TCGA runs.")
  }
  res <- res2 | res1
  if (sum(!res) > 0) {
    cat("\n[CheckSentrixID] WARN: found ", sum(!res), " invalid Sentrix_ID(s).")
    cat("\n", paste("\t", ids[!res], "\n"), "\n")
  } else {
    cat("\n[CheckSentrixID] INFO: all samples pass Sentrix_ID check!\n")
  }
  res
}

##################################################################

CheckProbeIDs <- function(ids) {
  grepl("cg[0-9]{8}", ids)
}
# =====================================================

CheckHeader <- function(file_path) {
  first_line <- readLines(file_path, n = 1)
  has_header <- !grepl("^cg[0-9]{8}", first_line) # if line#1 doesn't start with probeId, probeIdListFile has header line
  return(has_header)
}
# =====================================================

ParseBedFile <- function(bedFile) {
   # add chr; sort coordinates
   # save updated bed file
   # return a vector 
  beds <- read.table(bedFile, sep = "\t", header = F, fill = TRUE, stringsAsFactors = FALSE, quote = "", row.names = NULL, check.names = F)
  if (ncol(beds) < 3) {
    stop(paste0("Invalid bed file foramt: ncol<3"))
  }
  beds <- beds[ order(beds[,1],beds[,2],beds[,3]), ]
  beds[, 1] <- paste0("chr",gsub("chr","", beds[, 1]))
  filename<-tools::file_path_sans_ext(bedFile)
  outFile <- paste0(filename,"_sort.bed")
  write.table(beds, outFile, sep="\t", quote=FALSE, row.names=FALSE, col.names=F)
  cat("\n[",basename(outFile),"[saved]")
  input_bed <- paste(beds[, 1], ":", beds[, 2], "-", beds[, 3], sep = "")
  return(input_bed)
}
#================================================================
#================================================================

ParseBedFile2 <- function(bedFile) {
   # add chr; sort coordinates
   # save updated bed file
   # return a vector 
  input <- read.table(bedFile, sep = "\t", header = F, fill = TRUE, stringsAsFactors = FALSE, quote = "", row.names = NULL, check.names = F)
  if (ncol(input) < 3) {
    stop(paste0("Invalid bed file foramt: ncol<3"))
  }
  input <- input[!duplicated(input),] # remove duplicated 
  input <- input[ order(input[,1],input[,2],input[,3]), ]
  input[, 1] <- paste0("chr",gsub("chr","", input[, 1]))
  colnames(input)[1:3] <- c("chr","start","end")
  beds <- input[,1:3]
  kept <- !is.na(beds[,2]) & !is.na(beds[,3])
  beds <- beds[kept,]
  input <- input[kept,]
  regions <- paste0(beds[, 1], ":", beds[, 2], "-", beds[, 3])
  rownames(beds) <- regions
  anno <- NULL
  if(ncol(input) > 3){
   anno <- data.frame(input[,4:ncol(input)])
   colnames(anno) <- colnames(input)[4:ncol(input)]
   rownames(anno) <- regions 
  }
  return(list(bed=beds, anno=anno))
}

Bed2Granges <- function(bedFile) {
  suppressMessages(suppressWarnings(library(rtracklayer)))
  import(bedFile, format = "BED")
}


# ================================================================

idx_matching_column <- function(df, columns, ignore.case = T) {
  # Define the target column names you're looking for
  target_columns <- columns
  # Find the indices of the matching column names
  if (ignore.case) {
    matched_index <- which(toupper(colnames(df)) %in% toupper(target_columns)  )  
  } else {
    matched_index <- which(colnames(df) %in% target_columns )
  }
  if(length(matched_index)>0){
    return(matched_index) # Return the first matched index
  }else{
    return(NULL)
  }
  
}
##################################################################

LoadMeta <- function(input) {
  if (is.data.frame(input)) {
    meta <- input
  } else if (is.character(input) && file.exists(input)) {
    meta <- read.table(input, sep = "\t", header = TRUE, fill = TRUE, stringsAsFactors = FALSE, quote = "", check.names = F,comment.char = "")
  } else {
    stop("[LoadMeta] meta is neither a valid data frame nor a valid filename.")
  }

  cat("\n\t[meta dim:", nrow(meta), "x", ncol(meta), "]")
  colnames(meta) <- toupper(colnames(meta))
  meta  <- meta[, unique(colnames(meta))] # remove non-unique columns
  if ("ID" %in% colnames(meta) & !"SAMPLE_NAME" %in% colnames(meta)) {
    colnames(meta) <- gsub("^ID$", "SAMPLE_NAME", colnames(meta))
  }
  if ("GROUP" %in% colnames(meta) & !"SAMPLE_GROUP" %in% colnames(meta)) {
    colnames(meta) <- gsub("^GROUP$", "SAMPLE_GROUP", colnames(meta))
  }
  idx <- idx_matching_column(meta, c("SAMPLE_NAME", "SAMPLE_GROUP"))
  if (length( idx)!=2 ) {
    cat("\n INFO:idx_matching_column=",length( idx))
    stop("[LoadMeta] Invalid meta file. SAMPLE_NAME, SAMPLE_GROUP are required.\n")
  }

  if (any(duplicated(meta$SAMPLE_NAME))) {
    cat("\nWARN: remove samples with non-unique meta$SAMPLE_NAME. ")
    meta <- meta[!duplicated(meta$SAMPLE_NAME), ]
  }
  colnames(meta) <- toupper(colnames(meta))
  rownames(meta) <- meta$SAMPLE_NAME
  return(meta)
}

##################################################################

LoadBeta <- function(input) {
  suppressMessages(suppressWarnings(library(data.table)))
  if (is.data.frame(input)) {
    beta <- input
  } else if (is.character(input) && file.exists(input)) {
    if (grepl(".rds$", input, ignore.case = T)) {
      beta <- readRDS(input)
    } else {
      beta <- fread(input, sep = "\t", header = TRUE, fill = TRUE, quote = "", check.names = F, data.table = FALSE)
      beta <- beta[!duplicated(beta[, 1]), ] #
    }
  } else {
    stop("[LoadBeta] input is neither a valid data frame nor a valid filename.")
  }
  cat("\n\t[beta dim:", nrow(beta), "x", ncol(beta), "]")
  idx_id <- idx_matching_column(beta, c("TargetID", "NAME"))
  if (is.null(idx_id)) {
    stop("[LoadBeta] Invalid input. TargetID or NAME column is required.\n")
  }
  TargetIDs <- beta[, idx_id[1]]
  idx <- grep(".Ave_Beta", colnames(beta), ignore.case = T)
  if (sum(idx) > 0) {
    beta <- beta[, idx]
    colnames(beta) <- gsub(".Ave_Beta", "", colnames(beta), ignore.case = T)
  }
  rownames(beta) <- TargetIDs
  return(beta)
}

##################################################################
probeset_chrs <- c("chr1","chr6","chr7","chr14","chr15","chr19","chr11","chr20")#
probeset_options <- c("classifier2","classifier3","selected","chr11p15","signature_hc",probeset_chrs )

##################################################################

LoadMetaBeta <- function(metaFile, betaFile, probeset = NULL) {
  # if not all sampleIDs in meta and beta, subset or only keep matched ones.
  meta <- LoadMeta(metaFile)
  beta <- LoadBeta(betaFile)
  validIds <- intersect(meta$SAMPLE_NAME, colnames(beta))    
  if(length(validIds)>0){
    meta1 <- meta[validIds, ]
    if(length(validIds)==1){
       beta1=data.frame(beta[, validIds])
       rownames(beta1) <- rownames(beta)
       colnames(beta1) <- validIds
    }else{
      beta1 <- beta[, validIds]
    }
    
    result <- SubsetBeta_By_Probeset(beta1, probeset=probeset)
    beta2 <- result[["beta"]]
    cat("\n\t[meta dim:", nrow(meta1), "x", ncol(meta1), "]")
    cat("\n\t[beta dim:", nrow(beta2), "x", ncol(beta2), "]")
    return(list(meta = meta1, beta = beta2, probesets = result[["probesets"]]))    
  }else{
    cat("\n ERROR: beta column does not match meta$SAMPLE_NAME.\n")
    print(head(meta$SAMPLE_NAME,n=5))
    print(head(colnames(beta),n=5))
    q("no")
  }

}

#================================================================


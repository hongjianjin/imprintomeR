# Auto-refactored from utilities2.R
# Module: io

.resolve_extdata_file <- function(filename) {
  # Check local file first (allows tests to override package files)
  local_path <- file.path("inst", "extdata", filename)
  if (file.exists(local_path)) {
    return(local_path)
  }

  # Fall back to installed package file
  pkg_path <- system.file("extdata", filename, package = "imprintomeR")
  if (nzchar(pkg_path) && file.exists(pkg_path)) {
    return(pkg_path)
  }

  stop("Required extdata file not found: ", filename)
}

#' Check Whether an Excel Sheet Exists
#'
#' @param xlsxFile Path to an `.xlsx` workbook.
#' @param sheetName Sheet name to test.
#'
#' @return Logical; `TRUE` if the sheet exists, otherwise `FALSE`.
#' @export
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

#' Save a Table to an Excel Workbook
#'
#' Writes a data frame-like object to an `.xlsx` sheet using `openxlsx`.
#'
#' @param dat Data frame or matrix to write.
#' @param sheetName Optional worksheet name. Defaults to `"sheet1"`.
#' @param file Output workbook path.
#' @param append Logical; append/update existing workbook when `TRUE`.
#' @param colNames Logical; write column names.
#' @param rowNames Logical; write row names.
#' @param autoColWidth Logical; auto-fit column widths.
#'
#' @return Invisible side-effect function; writes workbook to disk.
#' @export
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

#' Load a Table from XLSX or Tab-Delimited Text
#'
#' @param xlsxFile Input file path (`.xlsx` or text table).
#' @param sheet Sheet index/name for Excel input.
#' @param skipEmptyRows Passed to `openxlsx::read.xlsx`.
#' @param colNames Logical; table has column names.
#' @param rowNames Logical; treat first column as row names for Excel mode.
#' @param startRow First row to read for Excel mode.
#'
#' @return A data frame.
#' @export
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

#' Validate Illumina Sentrix IDs
#'
#' @param ids Character vector of Sentrix IDs.
#'
#' @return Logical vector indicating valid IDs.
#' @export
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

#' Check Probe ID Format
#'
#' @param ids Character vector of probe IDs.
#'
#' @return Logical vector; `TRUE` for IDs matching `cg########`.
#' @export
CheckProbeIDs <- function(ids) {
  grepl("cg[0-9]{8}", ids)
}
# =====================================================

#' Detect Presence of Header in Probe List File
#'
#' @param file_path Input text file path.
#'
#' @return Logical; `TRUE` when a header line is detected.
#' @export
CheckHeader <- function(file_path) {
  first_line <- readLines(file_path, n = 1)
  has_header <- !grepl("^cg[0-9]{8}", first_line) # if line#1 doesn't start with probeId, probeIdListFile has header line
  return(has_header)
}
# =====================================================

#' Parse, Sort, and Normalize BED File
#'
#' Ensures `chr` prefix, sorts by genomic coordinates, writes a sorted BED copy,
#' and returns BED regions as `chr:start-end` strings.
#'
#' @param bedFile Path to BED file.
#'
#' @return Character vector of BED regions.
#' @export
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

#' Parse BED File with Optional Annotation Columns
#'
#' Parses BED-like input, normalizes coordinates, drops duplicate/invalid rows,
#' and returns both BED coordinates and optional trailing annotation columns.
#'
#' @param bedFile Path to BED file.
#'
#' @return A list with `bed` (3-column data frame) and `anno` (optional data frame).
#' @export
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

#' Import BED as Genomic Ranges
#'
#' @param bedFile Path to BED file.
#'
#' @return A `GRanges` object.
#' @export
Bed2Granges <- function(bedFile) {
  suppressMessages(suppressWarnings(library(rtracklayer)))
  import(bedFile, format = "BED")
}


# ================================================================

#' Find Matching Column Index/Indices
#'
#' @param df Data frame to query.
#' @param columns Character vector of candidate column names.
#' @param ignore.case Logical; case-insensitive matching when `TRUE`.
#'
#' @return Integer vector of matching indices or `NULL` if none matched.
#' @export
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

#' Load and Standardize Metadata Table
#'
#' Accepts either a metadata data frame or path to a tab-delimited metadata file.
#' Validates required columns (case-insensitive) and normalizes them to canonical form.
#'
#' @details
#' **Required columns (case-insensitive input; normalized to canonical form):**
#' - `Sample_Name` - Unique sample identifier (normalized from ID, SAMPLE_NAME, sample_name, etc.)
#' - `Sample_Group` - Sample grouping/stratification (normalized from GROUP, SAMPLE_GROUP, sample_group, etc.)
#'
#' **Column normalization behavior:**
#' User may provide columns in any case (e.g., `sample_name`, `SAMPLE_NAME`, `Sample_Name`).
#' LoadMeta() automatically normalizes to the canonical mixed-case form: `Sample_Name` and `Sample_Group`.
#' Preserves case of other columns.
#'
#' @param input Data frame or file path (tab-delimited with header).
#'
#' @return Standardized metadata data frame with `Sample_Name` row names. Columns are normalized to canonical form.
#' @export
LoadMeta <- function(input) {
  if (is.data.frame(input)) {
    meta <- input
  } else if (is.character(input) && file.exists(input)) {
    meta <- read.table(input, sep = "\t", header = TRUE, fill = TRUE, stringsAsFactors = FALSE, quote = "", check.names = F,comment.char = "")
  } else {
    stop("[LoadMeta] meta is neither a valid data frame nor a valid filename.")
  }

  cat("\n\t[meta dim:", nrow(meta), "x", ncol(meta), "]")
  
  # Normalize column names: case-insensitive matching, then map to canonical form
  col_lower <- tolower(colnames(meta))
  new_colnames <- colnames(meta)  # start with original case
  
  # Normalize required columns (case-insensitive match, then rename to canonical form)
  for (i in seq_along(col_lower)) {
    if (col_lower[i] == "sample_name" || col_lower[i] == "id") {
      new_colnames[i] <- "Sample_Name"
    } else if (col_lower[i] == "sample_group" || col_lower[i] == "group") {
      new_colnames[i] <- "Sample_Group"
    } else if (col_lower[i] == "basename") {
      new_colnames[i] <- "Basename"
    }
  }
  colnames(meta) <- new_colnames
  
  # Remove duplicate columns
  meta <- meta[, unique(colnames(meta))]
  
  # Validate that required columns exist
  required_cols <- c("Sample_Name", "Sample_Group")
  missing_cols <- setdiff(required_cols, colnames(meta))
  if (length(missing_cols) > 0) {
    stop("[LoadMeta] Invalid meta file. Required columns missing: ",
         paste(missing_cols, collapse = ", "),
         "\n(Accepted in any case: Sample_Name/ID, Sample_Group/GROUP)")
  }

  # Remove duplicates by Sample_Name
  if (any(duplicated(meta$Sample_Name))) {
    cat("\nWARN: remove samples with non-unique meta$Sample_Name. ")
    meta <- meta[!duplicated(meta$Sample_Name), ]
  }
  
  # Set Sample_Name as row names
  rownames(meta) <- meta$Sample_Name
  return(meta)
}

##################################################################

#' Load and Standardize Beta Matrix
#'
#' Accepts beta input as data frame, `.rds`, or tab-delimited text. Normalizes
#' row IDs and handles optional `.Ave_Beta` sample suffixes.
#'
#' @param input Data frame or file path.
#'
#' @return Beta matrix/data frame with probe IDs as row names.
#' @export
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

.resolve_beta_input <- function(beta_input) {
  if (methods::is(beta_input, "ImprintomeSet")) {
    return(methods::slot(beta_input, "beta"))
  }
  beta_input
}


.resolve_beta_meta_inputs <- function(beta_input, meta_input = NULL, require_meta = TRUE) {
  if (methods::is(beta_input, "ImprintomeSet")) {
    obj <- beta_input
    beta_input <- methods::slot(obj, "beta")
    if (is.null(meta_input)) {
      meta_input <- methods::slot(obj, "meta")
    }
  }

  if (require_meta && is.null(meta_input)) {
    stop("meta input is required unless beta input is an ImprintomeSet.")
  }

  list(beta = beta_input, meta = meta_input)
}

##################################################################

#' Load Matched Metadata and Beta Matrix
#'
#' Loads metadata and beta tables, keeps only intersecting samples, and
#' optionally subsets probes by named probeset.
#'
#' @param metaFile Metadata data frame or file path.
#' @param betaFile Beta matrix/data frame or file path.
#' @param probeset Optional probeset name passed to `SubsetBeta_By_Probeset`.
#'
#' @return A list with `meta`, `beta`, and `probesets`.
#' @export
LoadMetaBeta <- function(metaFile, betaFile = NULL, probeset = NULL) {
  # if not all sampleIDs in meta and beta, subset or only keep matched ones.
  if (methods::is(metaFile, "ImprintomeSet")) {
    if (!is.null(betaFile)) {
      stop("When metaFile is an ImprintomeSet, betaFile must be NULL.")
    }
    beta <- LoadBeta(methods::slot(metaFile, "beta"))
    meta <- LoadMeta(methods::slot(metaFile, "meta"))
  } else {
    meta <- LoadMeta(metaFile)
    beta <- LoadBeta(betaFile)
  }
  validIds <- intersect(meta$Sample_Name, colnames(beta))    
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
    cat("\n ERROR: beta column does not match meta$Sample_Name.\n")
    print(head(meta$Sample_Name,n=5))
    print(head(colnames(beta),n=5))
    q("no")
  }

}

#================================================================


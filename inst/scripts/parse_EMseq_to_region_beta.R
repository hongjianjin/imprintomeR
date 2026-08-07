#!/usr/bin/env Rscript
#' Parse EM-seq CpG bedGraph files into imprintomeR region beta tables
#'
#' This standalone script converts one or more Bismark/EM-seq CpG bedGraph
#' files to count-weighted region beta values over a BED-like region set.
#' Expected columns are chromosome, start, end, methylation percentage,
#' methylated count, and unmethylated count. Track/browser/header lines are
#' ignored. Files are processed independently and then combined by sample.
#' The final table is compatible with LoadWGBSRegionBeta() and
#' run_imprintomeR.R -B.

suppressPackageStartupMessages({
  library(optparse)
})

option_list <- list(
  make_option(c("-i", "--input"), type = "character", default = NA,
    help = "Comma-separated EM-seq CpG bedGraph files or glob patterns. Positional files are also accepted."),
  make_option(c("-r", "--regions"), type = "character", default = NA,
    help = "Region BED file. Default: package Rosenski_refined_iDMRs_<genome>.bed."),
  make_option(c("--genome"), type = "character", default = "hg38",
    help = "Genome build for default regions: hg19 or hg38 [default: %default]"),
  make_option(c("-o", "--outdir"), type = "character", default = ".",
    help = "Output directory [default: %default]"),
  make_option(c("-p", "--prefix"), type = "character", default = "EMseq_Rosenski_region",
    help = "Output prefix [default: %default]"),
  make_option(c("--sample-map"), type = "character", default = NA,
    help = "Optional TSV with columns file and Sample_Name. File can match basename or full path."),
  make_option(c("--min-site-coverage"), type = "double", default = 1,
    help = "Minimum per-site coverage before region aggregation [default: %default]"),
  make_option(c("--min-region-coverage"), type = "double", default = 1,
    help = "Minimum combined region coverage required to report beta [default: %default]"),
  make_option(c("--bedtools"), type = "character", default = "bedtools",
    help = "bedtools executable [default: %default]"),
  make_option(c("-j", "--jobs"), type = "integer", default = 1,
    help = "Number of files to process in parallel on Unix/Linux [default: %default]"),
  make_option(c("--keep-temp"), action = "store_true", default = FALSE,
    help = "Keep the temporary standardized region BED [default: %default]"),
  make_option(c("-v", "--verbose"), action = "store_true", default = FALSE,
    help = "Print progress messages")
)

parser <- OptionParser(
  usage = "%prog --input '*_CpG.bedGraph' --genome hg38 --outdir out --prefix PREFIX [options]",
  description = paste(
    "Convert EM-seq/Bismark CpG bedGraph files to count-weighted region beta",
    "tables compatible with LoadWGBSRegionBeta() and run_imprintomeR.R -B."
  ),
  option_list = option_list,
  epilogue = paste(
    "Examples:\n",
    "  Rscript parse_EMseq_to_region_beta.R --input '*_CpG.bedGraph' --genome hg38 -o emseq_beta -p EMseq_Rosenski --jobs 8 -v\n",
    "  Rscript parse_EMseq_to_region_beta.R --input 'batch1/*.bedGraph,batch2/*.bedGraph.gz' --regions Rosenski_refined_iDMRs_hg38.bed -o emseq_beta -p EMseq_hg38\n",
    "  Rscript run_imprintomeR.R -B emseq_beta/EMseq_Rosenski_beta.tsv -m meta.tsv -o imprintome --probeset Rosenski_region --genome hg38\n",
    sep = ""
  )
)

parsed <- parse_args(parser, positional_arguments = TRUE)
args <- parsed$options
positional_files <- parsed$args

log_msg <- function(..., level = "INFO") {
  if (isTRUE(args$verbose) || level %in% c("WARN", "ERROR")) {
    cat("[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] ", level, ": ",
        paste0(..., collapse = ""), "\n", sep = "")
  }
}

resolve_regions <- function(region_path, genome) {
  if (!is.na(region_path) && file.exists(region_path)) {
    return(normalizePath(region_path, mustWork = TRUE))
  }
  genome <- tolower(genome)
  if (!genome %in% c("hg19", "hg38")) {
    stop("--genome must be hg19 or hg38 when --regions is not supplied.")
  }
  file_name <- paste0("Rosenski_refined_iDMRs_", genome, ".bed")
  pkg_path <- system.file("extdata", file_name, package = "imprintomeR")
  if (nzchar(pkg_path) && file.exists(pkg_path)) {
    return(normalizePath(pkg_path, mustWork = TRUE))
  }
  source_path <- file.path("inst", "extdata", file_name)
  if (file.exists(source_path)) {
    return(normalizePath(source_path, mustWork = TRUE))
  }
  stop("Could not find ", file_name, ". Provide --regions explicitly.")
}

expand_inputs <- function(x, positional = character()) {
  pieces <- character()
  if (!is.na(x) && nzchar(x)) {
    pieces <- unlist(strsplit(x, ",", fixed = TRUE), use.names = FALSE)
  }
  pieces <- c(pieces, positional)
  pieces <- trimws(pieces)
  pieces <- pieces[nzchar(pieces)]
  expanded <- unlist(lapply(pieces, function(z) {
    hit <- Sys.glob(z)
    if (length(hit) > 0L) hit else z
  }), use.names = FALSE)
  expanded <- unique(expanded)
  expanded[file.exists(expanded)]
}

infer_sample_name <- function(path) {
  x <- basename(path)
  x <- sub("\\.gz$", "", x, ignore.case = TRUE)
  x <- sub("\\.bgz$", "", x, ignore.case = TRUE)
  x <- sub("\\.(txt|tsv|csv)$", "", x, ignore.case = TRUE)
  x <- sub("\\.(cov|coverage|CX_report|cytosine_report)$", "", x, ignore.case = TRUE)
  x <- sub("\\.beta\\.bed$", "", x, ignore.case = TRUE)
  x <- sub("\\.(bedGraph|bedgraph|bed)$", "", x, ignore.case = TRUE)
  x <- sub("[._-]CpG$", "", x, ignore.case = TRUE)
  x <- gsub("[._-]+$", "", x)
  x
}

load_sample_map <- function(path, files) {
  inferred <- data.frame(
    file = files,
    basename = basename(files),
    Sample_Name = vapply(files, infer_sample_name, character(1)),
    stringsAsFactors = FALSE
  )
  if (is.na(path)) {
    return(inferred)
  }
  smap <- read.delim(path, sep = "\t", quote = "", check.names = FALSE, stringsAsFactors = FALSE)
  required <- c("file", "Sample_Name")
  missing <- setdiff(required, colnames(smap))
  if (length(missing) > 0L) {
    stop("--sample-map is missing required column(s): ", paste(missing, collapse = ", "))
  }
  for (i in seq_len(nrow(inferred))) {
    idx <- which(smap$file %in% c(inferred$file[i], inferred$basename[i]))
    if (length(idx) > 0L) {
      inferred$Sample_Name[i] <- smap$Sample_Name[idx[1]]
    }
  }
  inferred
}

read_regions <- function(path) {
  first <- readLines(path, n = 1L, warn = FALSE)
  if (length(first) == 0L) stop("Region BED is empty: ", path)
  parts <- strsplit(first, "\t")[[1]]
  has_header <- length(parts) >= 3L && tolower(parts[2]) %in% c("start", "chromstart")
  regions <- read.delim(path, sep = "\t", header = has_header, quote = "", check.names = FALSE, stringsAsFactors = FALSE)
  if (!has_header) {
    if (ncol(regions) < 3L) stop("No-header region BED must have at least 3 columns.")
    colnames(regions)[1:3] <- c("CHR", "start", "end")
    if (ncol(regions) >= 4L) colnames(regions)[4] <- "Closest_TSS_gene_name"
  }
  lower <- tolower(colnames(regions))
  chr_col <- match("chr", lower)
  if (is.na(chr_col)) chr_col <- match("chrom", lower)
  start_col <- match("start", lower)
  end_col <- match("end", lower)
  if (any(is.na(c(chr_col, start_col, end_col)))) {
    stop("Region BED must contain chr/start/end columns or be a no-header BED3+ file.")
  }
  names(regions)[chr_col] <- "CHR"
  names(regions)[start_col] <- "start"
  names(regions)[end_col] <- "end"
  if (!"Closest_TSS_gene_name" %in% names(regions)) {
    regions$Closest_TSS_gene_name <- paste0(regions$CHR, ":", regions$start, "-", regions$end)
  }
  if (!"ORIGIN" %in% names(regions)) regions$ORIGIN <- NA_character_
  if (!"NAME" %in% names(regions)) regions$NAME <- paste0(regions$CHR, ":", regions$start, "-", regions$end)
  if (!"ICR_name" %in% names(regions)) regions$ICR_name <- regions$Closest_TSS_gene_name
  regions$CHR <- as.character(regions$CHR)
  regions$start <- as.integer(regions$start)
  regions$end <- as.integer(regions$end)
  regions[, c("CHR", "start", "end", "Closest_TSS_gene_name", "ORIGIN", "NAME", "ICR_name")]
}

normalization_awk <- function() {
  min_cov <- format(args[["min-site-coverage"]], scientific = FALSE)
  paste(
    'BEGIN { FS = OFS = "\t" }',
    '($1 ~ /^#/ || tolower($1) == "track" || tolower($1) == "browser" || tolower($1) == "chr" || tolower($1) == "chrom") { next }',
    'NF < 6 { next }',
    sprintf('{ meth = $5 + 0; unmeth = $6 + 0; cov = meth + unmeth; start = $2 + 0; end = $3 + 0; if (end > start && cov >= %s) print $1, start, end, meth, cov }', min_cov)
  )
}

run_one_file <- function(file, sample_name, regions_bed, out_file) {
  reader <- if (grepl("\\.gz$|\\.bgz$", file, ignore.case = TRUE)) {
    paste("gzip -cd", shQuote(normalizePath(file, mustWork = TRUE)))
  } else {
    paste("cat", shQuote(normalizePath(file, mustWork = TRUE)))
  }
  norm_awk <- normalization_awk()
  aggregate_awk <- paste(
    'BEGIN { FS = OFS = "\t"; nreg = 7;',
    'print "CHR","start","end","Closest_TSS_gene_name","ORIGIN","NAME","ICR_name","N_methylated","N_total","beta","n_sites" }',
    '{ b = NF - nreg + 1;',
    'key = $(b + 5); chr[key] = $b; st[key] = $(b + 1); en[key] = $(b + 2);',
    'gene[key] = $(b + 3); origin[key] = $(b + 4); icr[key] = $(b + 6);',
    'meth[key] += $4; cov[key] += $5; sites[key]++ }',
    'END { for (k in cov) { beta = (cov[k] > 0 ? meth[k] / cov[k] : "NA");',
    'print chr[k], st[k], en[k], gene[k], origin[k], k, icr[k], meth[k], cov[k], beta, sites[k] } }'
  )
  cmd <- paste(
    reader,
    "| awk", shQuote(norm_awk),
    "|", shQuote(args$bedtools), "intersect -a stdin -b", shQuote(regions_bed), "-wa -wb",
    "| awk", shQuote(aggregate_awk),
    ">", shQuote(out_file)
  )
  log_msg("Aggregating ", basename(file), " -> ", basename(out_file))
  status <- system2("bash", c("-lc", shQuote(cmd)))
  if (!identical(status, 0L)) {
    stop("awk/bedtools command failed for file: ", file)
  }
  dat <- read.delim(out_file, sep = "\t", quote = "", check.names = FALSE, stringsAsFactors = FALSE)
  if (nrow(dat) == 0L) {
    warning("No methylation calls overlapped regions for file: ", file, call. = FALSE)
  }
  dat$Sample_Name <- sample_name
  dat$file <- file
  dat[, c("Sample_Name", "file", setdiff(colnames(dat), c("Sample_Name", "file")))]
}

main <- function() {
  input_files <- expand_inputs(args$input, positional_files)
  if (length(input_files) == 0L) {
    print_help(parser)
    stop("No input files found. Provide --input or positional files.")
  }
  dir.create(args$outdir, recursive = TRUE, showWarnings = FALSE)
  regions_path <- resolve_regions(args$regions, args$genome)
  regions <- read_regions(regions_path)
  regions_bed <- file.path(args$outdir, paste0(args$prefix, "_regions.standardized.bed"))
  write.table(regions, regions_bed, sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)

  sample_map <- load_sample_map(args$`sample-map`, input_files)
  sample_map_file <- file.path(args$outdir, paste0(args$prefix, "_sample_map.tsv"))
  write.table(sample_map, sample_map_file, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)

  log_msg("Input files: ", length(input_files))
  log_msg("Unique samples: ", length(unique(sample_map$Sample_Name)))
  log_msg("Format: EM-seq CpG bedGraph (meth/unmeth counts in columns 5/6)")
  log_msg("Regions: ", nrow(regions), " from ", regions_path)

  jobs <- as.integer(args$jobs)
  if (is.na(jobs) || jobs < 1L) stop("--jobs must be a positive integer.")
  jobs <- min(jobs, length(input_files))
  if (jobs > 1L && .Platform$OS.type == "windows") {
    warning("--jobs > 1 is only enabled on Unix/Linux; processing serially on Windows.", call. = FALSE)
    jobs <- 1L
  }
  log_msg("Parallel file-processing jobs: ", jobs)

  process_index <- function(i) {
    safe_file_id <- sprintf("%03d_%s", i, gsub("[^A-Za-z0-9_.-]", "_", basename(input_files[i])))
    counts_file <- file.path(args$outdir, paste0(args$prefix, "_", safe_file_id, "_region_counts.tsv"))
    run_one_file(
      file = input_files[i],
      sample_name = sample_map$Sample_Name[i],
      regions_bed = regions_bed,
      out_file = counts_file
    )
  }

  per_file <- if (jobs > 1L) {
    parallel::mclapply(seq_along(input_files), process_index, mc.cores = jobs)
  } else {
    lapply(seq_along(input_files), process_index)
  }
  failed <- which(vapply(per_file, inherits, logical(1), what = "try-error"))
  if (length(failed) > 0L) {
    stop("Parallel processing failed for file(s): ", paste(input_files[failed], collapse = ", "))
  }

  file_counts <- do.call(rbind, per_file)
  file_counts_file <- file.path(args$outdir, paste0(args$prefix, "_file_region_counts.tsv"))
  write.table(file_counts, file_counts_file, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
  if (nrow(file_counts) == 0L) {
    stop("No overlapping methylation calls found in any input file.")
  }

  file_counts$N_methylated <- as.numeric(file_counts$N_methylated)
  file_counts$N_total <- as.numeric(file_counts$N_total)
  file_counts$n_sites <- as.integer(file_counts$n_sites)
  sample_counts <- aggregate(
    cbind(N_methylated, N_total, n_sites) ~ Sample_Name + NAME,
    data = file_counts,
    FUN = sum,
    na.rm = TRUE
  )
  sample_counts <- merge(
    expand.grid(Sample_Name = unique(sample_map$Sample_Name), NAME = regions$NAME, stringsAsFactors = FALSE),
    sample_counts,
    by = c("Sample_Name", "NAME"),
    all.x = TRUE
  )
  sample_counts$N_methylated[is.na(sample_counts$N_methylated)] <- 0
  sample_counts$N_total[is.na(sample_counts$N_total)] <- 0
  sample_counts$n_sites[is.na(sample_counts$n_sites)] <- 0
  sample_counts$beta <- ifelse(
    sample_counts$N_total >= args$`min-region-coverage`,
    sample_counts$N_methylated / sample_counts$N_total,
    NA_real_
  )
  sample_counts <- merge(
    regions[, c("CHR", "start", "end", "Closest_TSS_gene_name", "ORIGIN", "NAME", "ICR_name")],
    sample_counts,
    by = "NAME",
    all.y = TRUE
  )
  sample_counts <- sample_counts[order(match(sample_counts$NAME, regions$NAME), sample_counts$Sample_Name), ]
  sample_counts_file <- file.path(args$outdir, paste0(args$prefix, "_sample_region_counts.tsv"))
  write.table(sample_counts, sample_counts_file, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)

  samples <- unique(sample_map$Sample_Name)
  beta_table <- regions[, c("CHR", "start", "end")]
  colnames(beta_table) <- c("chr", "start", "end")
  for (s in samples) {
    sub <- sample_counts[sample_counts$Sample_Name == s, c("NAME", "beta")]
    beta_table[[s]] <- sub$beta[match(regions$NAME, sub$NAME)]
  }
  beta_file <- file.path(args$outdir, paste0(args$prefix, "_beta.tsv"))
  write.table(beta_table, beta_file, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)

  if (!isTRUE(args$`keep-temp`)) unlink(regions_bed)

  cat("Saved sample map: ", sample_map_file, "\n", sep = "")
  cat("Saved per-file region counts: ", file_counts_file, "\n", sep = "")
  cat("Saved combined sample-region counts: ", sample_counts_file, "\n", sep = "")
  cat("Saved imprintomeR beta table: ", beta_file, "\n", sep = "")
}

tryCatch(
  main(),
  error = function(e) {
    log_msg(conditionMessage(e), level = "ERROR")
    quit("no", status = 1)
  }
)
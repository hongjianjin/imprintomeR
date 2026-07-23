#!/usr/bin/env Rscript
#' Parse ONT/modkit bedMethyl files into imprintomeR region beta tables
#'
#' This script converts phased or non-phased ONT bedMethyl files to region-level beta values
#' over Rosenski refined iDMRs. It streams each bedMethyl file through bedtools,
#' keeps only 5mC rows (`modified_base == "m"`), aggregates modified and valid
#' coverage counts per region, combines files by sample, and writes an
#' imprintomeR-compatible beta table.

suppressPackageStartupMessages({
  library(optparse)
})

option_list <- list(
  make_option(c("-b", "--bedmethyl"), type = "character", default = NA,
    help = "Comma-separated bedMethyl files or glob patterns. Positional files are also accepted."),
  make_option(c("-r", "--regions"), type = "character", default = NA,
    help = "Region BED file. Default: package Rosenski_refined_iDMRs_hg38.bed."),
  make_option(c("-o", "--outdir"), type = "character", default = ".",
    help = "Output directory [default: %default]"),
  make_option(c("-p", "--prefix"), type = "character", default = "ONT_Rosenski_region",
    help = "Output prefix [default: %default]"),
  make_option(c("--sample-map"), type = "character", default = NA,
    help = "Optional TSV with columns file and Sample_Name. File can match basename or full path."),
  make_option(c("--mod-code"), type = "character", default = "m",
    help = "Modified base code to keep. Use m for 5mC [default: %default]"),
  make_option(c("--min-site-coverage"), type = "double", default = 1,
    help = "Minimum bedMethyl per-site valid coverage, using column 10 [default: %default]"),
  make_option(c("--min-region-coverage"), type = "double", default = 1,
    help = "Minimum combined region coverage required to report beta [default: %default]"),
  make_option(c("--bedtools"), type = "character", default = "bedtools",
    help = "bedtools executable [default: %default]"),
  make_option(c("-j", "--jobs"), type = "integer", default = 1,
    help = "Number of bedMethyl files to process in parallel on Unix/Linux [default: %default]"),
  make_option(c("--keep-temp"), action = "store_true", default = FALSE,
    help = "Keep temporary no-header region BED [default: %default]"),
  make_option(c("-v", "--verbose"), action = "store_true", default = FALSE,
    help = "Print progress messages")
)

parser <- OptionParser(
  usage = "%prog --bedmethyl '*.bedmethyl.gz' --outdir out --prefix PREFIX [options]",
  description = paste(
    "Convert phased or non-phased ONT/modkit bedMethyl files to region-level beta tables",
    "compatible with LoadWGBSRegionBeta() and run_imprintomeR.R -B."
  ),
  option_list = option_list,
  epilogue = paste(
    "Examples:\n",
    "  Rscript parse_ONT_bedMethyl.R --bedmethyl './*/*.bedmethyl.gz' -o ont_beta -p NABEC_ONT --jobs 8\n",
    "  Rscript parse_ONT_bedMethyl.R --bedmethyl sample.HP1.bedmethyl.gz,sample.HP2.bedmethyl.gz -p sample\n",
    "  Rscript run_imprintomeR.R -B ont_beta/NABEC_ONT_beta.tsv -m meta.tsv -o imprintome --probeset Rosenski_region --genome hg38\n",
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

resolve_regions <- function(region_path) {
  if (!is.na(region_path) && file.exists(region_path)) {
    return(normalizePath(region_path, mustWork = TRUE))
  }

  pkg_path <- system.file("extdata", "Rosenski_refined_iDMRs_hg38.bed", package = "imprintomeR")
  if (nzchar(pkg_path) && file.exists(pkg_path)) {
    return(normalizePath(pkg_path, mustWork = TRUE))
  }

  source_path <- file.path("inst", "extdata", "Rosenski_refined_iDMRs_hg38.bed")
  if (file.exists(source_path)) {
    return(normalizePath(source_path, mustWork = TRUE))
  }

  stop("Could not find Rosenski_refined_iDMRs_hg38.bed. Provide --regions explicitly.")
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
  parent <- basename(dirname(normalizePath(path, mustWork = FALSE)))
  x <- basename(path)
  x <- sub("\\.gz$", "", x, ignore.case = TRUE)
  x <- sub("\\.(bedmethyl|bedMethyl|bed)$", "", x, ignore.case = TRUE)
  x <- sub("([._-](mods|wf_mods))[._-]?[12]$", "\\1", x, ignore.case = TRUE)
  x <- gsub("([._-](HP|HAP|hap|phase|PHASE)[._-]?[12])($|[._-])", "_", x, ignore.case = TRUE)
  x <- gsub("([._-](HP|HAP|hap|phase|PHASE)[._-]?[12])$", "", x, ignore.case = TRUE)
  x <- gsub("([._-](paternal|maternal|PAT|MAT|pat|mat))$", "", x, ignore.case = TRUE)
  x <- sub("([._-](mods|wf_mods))$", "", x, ignore.case = TRUE)
  x <- gsub("[._-]+$", "", x)
  if (tolower(x) %in% c("mods", "wf_mods", "mod", "bedmethyl", "")) {
    x <- parent
  }
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

run_one_file <- function(file, sample_name, regions_no_header, out_file) {
  reader <- if (grepl("\\.gz$", file, ignore.case = TRUE)) {
    paste("gzip -cd", shQuote(normalizePath(file, mustWork = TRUE)))
  } else {
    paste("cat", shQuote(normalizePath(file, mustWork = TRUE)))
  }

  filter_awk <- sprintf(
    'BEGIN { FS = OFS = "\t" } $4 == "%s" && ($10 + 0) >= %s && ($12 + 0) >= 0 { print }',
    args$`mod-code`,
    format(args$`min-site-coverage`, scientific = FALSE)
  )

  aggregate_awk <- paste(
    'BEGIN { FS = OFS = "\t"; nreg = 13;',
    'print "CHR","start","end","Closest_TSS_gene_name","ORIGIN","NAME","ICR_name","N_mod","N_valid_cov","beta","n_sites" }',
    '{ b = NF - nreg + 1;',
    'key = $(b + 5); chr[key] = $b; st[key] = $(b + 1); en[key] = $(b + 2);',
    'gene[key] = $(b + 3); origin[key] = $(b + 4); icr[key] = $(b + 8);',
    'mod[key] += $12; cov[key] += $10; sites[key]++ }',
    'END { for (k in cov) { beta = (cov[k] > 0 ? mod[k] / cov[k] : "NA");',
    'print chr[k], st[k], en[k], gene[k], origin[k], k, icr[k], mod[k], cov[k], beta, sites[k] } }'
  )

  cmd <- paste(
    reader,
    "| awk", shQuote(filter_awk),
    "|", shQuote(args$bedtools), "intersect -a stdin -b", shQuote(regions_no_header), "-wa -wb",
    "| awk", shQuote(aggregate_awk),
    ">", shQuote(out_file)
  )

  log_msg("Intersecting ", basename(file), " -> ", basename(out_file))
  status <- system2("bash", c("-lc", shQuote(cmd)))
  if (!identical(status, 0L)) {
    stop("bedtools/awk command failed for file: ", file)
  }

  dat <- read.delim(out_file, sep = "\t", quote = "", check.names = FALSE, stringsAsFactors = FALSE)
  if (nrow(dat) == 0L) {
    warning("No 5mC rows overlapped regions for file: ", file, call. = FALSE)
  }
  dat$Sample_Name <- sample_name
  dat$file <- file
  dat[, c("Sample_Name", "file", setdiff(colnames(dat), c("Sample_Name", "file")))]
}

main <- function() {
  bedmethyl_files <- expand_inputs(args$bedmethyl, positional_files)
  if (length(bedmethyl_files) == 0L) {
    print_help(parser)
    stop("No bedMethyl files found. Provide --bedmethyl or positional files.")
  }

  dir.create(args$outdir, recursive = TRUE, showWarnings = FALSE)
  regions_path <- resolve_regions(args$regions)
  regions <- read.delim(regions_path, sep = "\t", quote = "", check.names = FALSE, stringsAsFactors = FALSE)
  required_region_cols <- c("CHR", "start", "end", "Closest_TSS_gene_name", "ORIGIN", "NAME", "ICR_name")
  missing_region_cols <- setdiff(required_region_cols, colnames(regions))
  if (length(missing_region_cols) > 0L) {
    stop("Region BED missing required column(s): ", paste(missing_region_cols, collapse = ", "))
  }

  regions_no_header <- file.path(args$outdir, paste0(args$prefix, "_regions.noheader.bed"))
  write.table(regions, regions_no_header, sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)

  sample_map <- load_sample_map(args$`sample-map`, bedmethyl_files)
  sample_map_file <- file.path(args$outdir, paste0(args$prefix, "_sample_map.tsv"))
  write.table(sample_map, sample_map_file, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)

  log_msg("Input bedMethyl files: ", length(bedmethyl_files))
  log_msg("Unique samples after phase grouping: ", length(unique(sample_map$Sample_Name)))
  log_msg("Regions: ", nrow(regions), " from ", regions_path)

  jobs <- as.integer(args$jobs)
  if (is.na(jobs) || jobs < 1L) {
    stop("--jobs must be a positive integer.")
  }
  jobs <- min(jobs, length(bedmethyl_files))
  if (jobs > 1L && .Platform$OS.type == "windows") {
    warning("--jobs > 1 is only enabled on Unix/Linux; processing serially on Windows.", call. = FALSE)
    jobs <- 1L
  }
  log_msg("Parallel file-processing jobs: ", jobs)

  process_index <- function(i) {
    safe_file_id <- sprintf("%03d_%s", i, gsub("[^A-Za-z0-9_.-]", "_", basename(bedmethyl_files[i])))
    counts_file <- file.path(args$outdir, paste0(args$prefix, "_", safe_file_id, "_region_counts.tsv"))
    run_one_file(
      file = bedmethyl_files[i],
      sample_name = sample_map$Sample_Name[i],
      regions_no_header = regions_no_header,
      out_file = counts_file
    )
  }

  per_file <- if (jobs > 1L) {
    parallel::mclapply(seq_along(bedmethyl_files), process_index, mc.cores = jobs)
  } else {
    lapply(seq_along(bedmethyl_files), process_index)
  }
  failed <- which(vapply(per_file, inherits, logical(1), what = "try-error"))
  if (length(failed) > 0L) {
    stop("Parallel processing failed for file(s): ", paste(bedmethyl_files[failed], collapse = ", "))
  }

  file_counts <- do.call(rbind, per_file)
  file_counts_file <- file.path(args$outdir, paste0(args$prefix, "_file_region_counts.tsv"))
  write.table(file_counts, file_counts_file, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)

  if (nrow(file_counts) == 0L) {
    stop("No overlapping 5mC records found in any bedMethyl file.")
  }

  file_counts$N_mod <- as.numeric(file_counts$N_mod)
  file_counts$N_valid_cov <- as.numeric(file_counts$N_valid_cov)
  file_counts$n_sites <- as.integer(file_counts$n_sites)

  sample_counts <- aggregate(
    cbind(N_mod, N_valid_cov, n_sites) ~ Sample_Name + NAME,
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
  sample_counts$N_mod[is.na(sample_counts$N_mod)] <- 0
  sample_counts$N_valid_cov[is.na(sample_counts$N_valid_cov)] <- 0
  sample_counts$n_sites[is.na(sample_counts$n_sites)] <- 0
  sample_counts$beta <- ifelse(
    sample_counts$N_valid_cov >= args$`min-region-coverage`,
    sample_counts$N_mod / sample_counts$N_valid_cov,
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

  if (!isTRUE(args$`keep-temp`)) {
    unlink(regions_no_header)
  }

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

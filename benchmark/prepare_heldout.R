#!/usr/bin/env Rscript
# Convert the downloaded GEO files of the held-out cohorts (protocol amendment 1) into the
# beta.txt / meta.txt inputs of run_threshold_selection.R, and record SHA-256 checksums of the
# downloaded and derived files. No scores are computed here.
#
# Usage: Rscript prepare_heldout.R --download DIR --out DIR
#   DIR (download) holds, as distributed by GEO:
#     GSE297935_normalized_matrix.txt.gz, GSE95486_series_matrix.txt.gz, GSE55491_series_matrix.txt.gz
#   DIR (out) receives <dataset>/beta.txt, <dataset>/meta.txt and checksums.tsv.

arg_value <- function(flag) { a <- commandArgs(TRUE); i <- match(flag, a); if (is.na(i)) stop(flag, " is required"); a[i + 1L] }
dl <- arg_value("--download")
out <- arg_value("--out")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
sha <- function(f) digest::digest(file = f, algo = "sha256")

# GEO series matrix: sample titles and accessions from the header, beta table after the header.
read_series_matrix <- function(path) {
  lines <- readLines(gzfile(path))
  field <- function(tag) { l <- lines[startsWith(lines, tag)][1]; gsub('"', "", strsplit(l, "\t")[[1]][-1]) }
  meta <- data.frame(Sample_Name = field("!Sample_geo_accession"), Sample_Group = field("!Sample_title"), stringsAsFactors = FALSE)
  start <- which(lines == "!series_matrix_table_begin") + 1L
  end <- which(lines == "!series_matrix_table_end") - 1L
  tab <- utils::read.delim(text = lines[start:end], check.names = FALSE, stringsAsFactors = FALSE, quote = '"')
  colnames(tab)[1] <- "TargetID"
  list(beta = tab, meta = meta)
}

write_cohort <- function(name, beta, meta) {
  d <- file.path(out, name)
  dir.create(d, showWarnings = FALSE)
  utils::write.table(beta, file.path(d, "beta.txt"), sep = "\t", quote = FALSE, row.names = FALSE)
  utils::write.table(meta, file.path(d, "meta.txt"), sep = "\t", quote = FALSE, row.names = FALSE)
  cat(name, ":", nrow(beta), "probes x", ncol(beta) - 1L, "samples;", paste(names(table(meta$Sample_Group)), table(meta$Sample_Group), sep = "=", collapse = ", "), "\n")
}

# GSE297935: newly deposited samples only (Control25-Control40 = C25-C40; BWS_patient7-64 = P7-P64).
# Reused columns (GSM3927*, GSM4635*, GSM5855* incl. development cohort GSE195873, GSM7017*) are dropped.
f297 <- file.path(dl, "GSE297935_normalized_matrix.txt.gz")
m <- utils::read.delim(gzfile(f297), check.names = FALSE, stringsAsFactors = FALSE)
keep <- grep("^(C(2[5-9]|3[0-9]|40)|P[0-9]+)$", colnames(m), value = TRUE)
b297 <- data.frame(TargetID = m[[1]], m[, keep], check.names = FALSE)
write_cohort("GSE297935", b297, data.frame(Sample_Name = keep, Sample_Group = ifelse(startsWith(keep, "C"), "Control", "BWS")))

# GSE95486 and GSE55491: series matrices; Sample_Group is the GEO sample title.
for (acc in c("GSE95486", "GSE55491")) {
  x <- read_series_matrix(file.path(dl, paste0(acc, "_series_matrix.txt.gz")))
  write_cohort(acc, x$beta, x$meta)
}

files <- c(f297, file.path(dl, c("GSE95486_series_matrix.txt.gz", "GSE55491_series_matrix.txt.gz")),
           file.path(out, rep(c("GSE297935", "GSE95486", "GSE55491"), each = 2), c("beta.txt", "meta.txt")))
utils::write.table(data.frame(file = basename(dirname(files)), name = basename(files), sha256 = vapply(files, sha, character(1)),
                              bytes = file.size(files)),
                   file.path(out, "checksums.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
cat("Checksums written to", file.path(out, "checksums.tsv"), "\n")

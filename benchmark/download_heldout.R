#!/usr/bin/env Rscript
# Download the GEO files of the held-out benchmark cohorts (protocol amendment 1) and verify
# their size and SHA-256 checksum against heldout_checksums.tsv. Then convert them with
# prepare_heldout.R and score them with run_threshold_selection.R (threshold_selection_protocol.md).
#
# Usage: Rscript benchmark/download_heldout.R --download DIR
#   About 450 MB in all: GSE297935_normalized_matrix.txt.gz (338 MB, GEO supplementary file),
#   GSE95486_series_matrix.txt.gz (50 MB) and GSE55491_series_matrix.txt.gz (61 MB).
#   Files already in DIR with the expected checksum are not downloaded again.
#   Needs the digest package (install.packages("digest")).
#
# Next: Rscript benchmark/prepare_heldout.R --download DIR --out heldout

args <- commandArgs(TRUE)
i <- match("--download", args)
if (is.na(i) || is.na(args[i + 1L])) stop("Usage: Rscript benchmark/download_heldout.R --download DIR")
dl <- args[i + 1L]
if (!requireNamespace("digest", quietly = TRUE)) stop("Please install the digest package: install.packages(\"digest\")")
dir.create(dl, recursive = TRUE, showWarnings = FALSE)

here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
ck <- utils::read.delim(file.path(here, "heldout_checksums.tsv"), stringsAsFactors = FALSE)
ck <- ck[ck$file == "heldout_download", ]

geo_url <- function(name) {
  acc <- sub("_.*$", "", name)
  stub <- sub("[0-9]{1,3}$", "nnn", acc)
  sub_dir <- if (grepl("_series_matrix\\.txt\\.gz$", name)) "matrix" else "suppl"
  sprintf("https://ftp.ncbi.nlm.nih.gov/geo/series/%s/%s/%s/%s", stub, acc, sub_dir, name)
}
sha <- function(f) digest::digest(file = f, algo = "sha256")

old_timeout <- getOption("timeout")
options(timeout = max(3600, old_timeout))
on.exit(options(timeout = old_timeout), add = TRUE)

ok <- logical(nrow(ck))
for (k in seq_len(nrow(ck))) {
  f <- file.path(dl, ck$name[k])
  if (!(file.exists(f) && file.size(f) == ck$bytes[k] && sha(f) == ck$sha256[k])) {
    cat("Downloading", ck$name[k], sprintf("(%.0f MB)", ck$bytes[k] / 1e6), "from", geo_url(ck$name[k]), "\n")
    utils::download.file(geo_url(ck$name[k]), f, mode = "wb", quiet = TRUE)
  }
  ok[k] <- file.size(f) == ck$bytes[k] && sha(f) == ck$sha256[k]
  cat(sprintf("%-40s %s\n", ck$name[k], if (ok[k]) "size and SHA-256 match" else "MISMATCH"))
}
if (!all(ok)) stop("Checksum mismatch: the GEO file differs from the one used for the benchmark.")
cat("All held-out files verified. Next: Rscript benchmark/prepare_heldout.R --download", dl, "--out heldout\n")

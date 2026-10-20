# Build the hg38 `chr11p15_region` panel. In hg19, `chr11p15_region` is the eight
# 11p15.5 rows of `Rosenski_region`; the hg38 panel takes the corresponding rows of
# hg38 `Rosenski_region`, which lists the same 72 DMRs in the same order.
p19 <- readRDS("inst/extdata/probesets_hg19.rds")
panels_hg38 <- readRDS("inst/extdata/probesets_hg38.rds")
c19 <- p19[["chr11p15_region"]]
r19 <- p19[["Rosenski_region"]]
r38 <- panels_hg38[["Rosenski_region"]]

stopifnot(
  nrow(c19) == 8L,
  identical(colnames(c19), colnames(r19)),
  identical(colnames(r19), colnames(r38)),
  nrow(r19) == nrow(r38),
  identical(r19$ICR_name, r38$ICR_name)
)

# Locate each hg19 chr11p15_region row in hg19 Rosenski_region.
key <- function(d) paste(d$CHR, d$start, d$end)
idx <- match(key(c19), key(r19))
stopifnot(!anyNA(idx), !anyDuplicated(idx))
same_row <- vapply(seq_along(idx), function(i) {
  isTRUE(all.equal(as.list(c19[i, ]), as.list(r19[idx[i], ]), check.attributes = FALSE))
}, logical(1))
stopifnot(all(same_row))

c38 <- r38[idx, , drop = FALSE]
rownames(c38) <- NULL

# Build-independent columns must match; coordinates must be hg38 with unchanged widths.
coord_cols <- c("start", "end", "NAME", "MAPINFO", "region", "Genome_Build")
for (cn in setdiff(colnames(c19), coord_cols)) {
  stopifnot(identical(as.character(c38[[cn]]), as.character(c19[[cn]])))
}
stopifnot(
  all(c38$Genome_Build == "hg38"),
  all(c38$CHR == "chr11"),
  all((c38$end - c38$start) == (c19$end - c19$start))
)

# Independent check: lift each hg19 boundary through the UCSC hg19ToHg38 chain.
chain_file <- "tmp_ICR_sources/hg19ToHg38.over.chain"
if (file.exists(chain_file)) {
  lines <- readLines(chain_file)
  header_idx <- grep("^chain ", lines)
  block_end <- c(header_idx[-1] - 1L, length(lines))
  blocks <- list()
  for (k in seq_along(header_idx)) {
    h <- strsplit(lines[header_idx[k]], " ", fixed = TRUE)[[1]]
    if (h[3] != "chr11" || h[8] != "chr11" || h[5] != "+" || h[10] != "+") next
    body <- lines[(header_idx[k] + 1L):block_end[k]]
    fields <- strsplit(body[nzchar(body)], "\t", fixed = TRUE)
    size <- as.numeric(vapply(fields, `[`, "", 1L))
    dt <- c(as.numeric(vapply(fields[-length(fields)], `[`, "", 2L)), 0)
    dq <- c(as.numeric(vapply(fields[-length(fields)], `[`, "", 3L)), 0)
    blocks[[length(blocks) + 1L]] <- data.frame(
      t_start = as.numeric(h[6]) + c(0, cumsum(size + dt)[-length(size)]),
      q_start = as.numeric(h[11]) + c(0, cumsum(size + dq)[-length(size)]),
      size = size
    )
  }
  blocks <- do.call(rbind, blocks)
  lift <- function(pos) {
    w <- which(pos >= blocks$t_start & pos < blocks$t_start + blocks$size)
    if (length(w) != 1L) return(NA_real_)
    blocks$q_start[w] + pos - blocks$t_start[w]
  }
  # Interval boundaries are used as stored (start and end positions).
  lifted_start <- vapply(c19$start, lift, numeric(1))
  lifted_end <- vapply(c19$end, lift, numeric(1))
  stopifnot(identical(lifted_start, as.numeric(c38$start)), identical(lifted_end, as.numeric(c38$end)))
  cat("Chain check: all", nrow(c19), "hg19 intervals lift exactly to the hg38 intervals\n")
} else {
  cat("Chain file not found; skipped the liftover cross-check\n")
}

# Append after Rosenski_region, mirroring the hg19 panel order.
before <- panels_hg38
panels_hg38[["chr11p15_region"]] <- c38

tmp <- tempfile(fileext = ".rds")
saveRDS(panels_hg38, tmp, version = 3)
for (k in 1:10) {
  if (isTRUE(suppressWarnings(file.copy(tmp, "inst/extdata/probesets_hg38.rds", overwrite = TRUE)))) break
  if (k == 10) stop("Could not write inst/extdata/probesets_hg38.rds")
  Sys.sleep(1)
}

check <- readRDS("inst/extdata/probesets_hg38.rds")
stopifnot(
  identical(check[["chr11p15_region"]], c38),
  identical(check[setdiff(names(check), "chr11p15_region")], before[setdiff(names(before), "chr11p15_region")])
)
cat("hg38 panels:", names(check), "\n")
print(check[["chr11p15_region"]][, c("CHR", "start", "end", "ICR_name", "ICR_type", "ORIGIN", "Genome_Build")], row.names = FALSE)

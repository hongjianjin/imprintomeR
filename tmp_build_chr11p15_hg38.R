# Build the hg38 `chr11p15` panel from hg19 `chr11p15` by stable Illumina probe NAME.
# hg38 CHR/MAPINFO come from anno.uniq_harmonized.liftover.rds; the remaining columns
# are copied by NAME. Distance_closest_TSS is copied from hg19: the hg19 -> hg38
# offset across 11p15.5 varies by at most 2 bp (checked below), so hg38 distances
# can differ from the copied values by up to 2 bp.
chr11p15_hg19 <- readRDS("inst/extdata/probesets_hg19.rds")[["chr11p15"]]
panels_hg38 <- readRDS("inst/extdata/probesets_hg38.rds")
anno <- readRDS("inst/extdata/anno.uniq_harmonized.liftover.rds")
regions_hg38 <- panels_hg38[["chr11p15_region"]]

stopifnot(
  nrow(chr11p15_hg19) == 82L,
  !anyDuplicated(chr11p15_hg19$NAME),
  !anyDuplicated(anno$NAME),
  !is.null(regions_hg38)
)

idx <- match(chr11p15_hg19$NAME, anno$NAME)
stopifnot(!anyNA(idx))
a <- anno[idx, ]

# The harmonized annotation must agree with the hg19 panel before its hg38 fields are
# used. CHR_HG19 is stored without the "chr" prefix for some probes.
with_chr <- function(x) ifelse(grepl("^chr", x), x, paste0("chr", x))
stopifnot(
  all(with_chr(a$CHR_HG19) == chr11p15_hg19$CHR),
  all(a$MAPINFO_HG19 == chr11p15_hg19$MAPINFO),
  !anyNA(a$CHR_HG38), !anyNA(a$MAPINFO_HG38),
  all(a$MAPINFO_HG38 > 0)
)

# Five probes carry CHR_HG38 = "19" in the harmonized annotation although their
# hg38 positions follow the 11p15.5 offset. Correct the chromosome only where the
# UCSC hg19ToHg38 chain maps the hg19 position to chr11 at exactly MAPINFO_HG38.
bad_chr <- which(with_chr(a$CHR_HG38) != chr11p15_hg19$CHR)
if (length(bad_chr)) {
  chain_file <- "tmp_ICR_sources/hg19ToHg38.over.chain"
  if (!file.exists(chain_file)) stop("Chain file needed to verify the CHR_HG38 corrections: ", chain_file)
  lines <- readLines(chain_file)
  header_idx <- grep("^chain ", lines)
  block_end <- c(header_idx[-1] - 1L, length(lines))
  blocks <- list()
  for (k in seq_along(header_idx)) {
    h <- strsplit(lines[header_idx[k]], " ", fixed = TRUE)[[1]]
    if (h[3] != "chr11" || h[5] != "+" || h[10] != "+") next
    body <- lines[(header_idx[k] + 1L):block_end[k]]
    fields <- strsplit(body[nzchar(body)], "\t", fixed = TRUE)
    size <- as.numeric(vapply(fields, `[`, "", 1L))
    dt <- c(as.numeric(vapply(fields[-length(fields)], `[`, "", 2L)), 0)
    dq <- c(as.numeric(vapply(fields[-length(fields)], `[`, "", 3L)), 0)
    blocks[[length(blocks) + 1L]] <- data.frame(
      q_chr = h[8],
      t_start = as.numeric(h[6]) + c(0, cumsum(size + dt)[-length(size)]),
      q_start = as.numeric(h[11]) + c(0, cumsum(size + dq)[-length(size)]),
      size = size
    )
  }
  blocks <- do.call(rbind, blocks)
  # MAPINFO is 1-based; chain coordinates are 0-based.
  lift <- function(pos1) {
    w <- which(pos1 - 1 >= blocks$t_start & pos1 - 1 < blocks$t_start + blocks$size)
    if (length(w) != 1L) return(c(chr = NA, pos = NA))
    c(chr = blocks$q_chr[w], pos = format(blocks$q_start[w] + (pos1 - 1) - blocks$t_start[w] + 1, scientific = FALSE))
  }
  lifted <- t(vapply(a$MAPINFO_HG19[bad_chr], lift, c(chr = "", pos = "")))
  corrections <- data.frame(
    NAME = a$NAME[bad_chr],
    hg19 = paste0(chr11p15_hg19$CHR[bad_chr], ":", a$MAPINFO_HG19[bad_chr]),
    anno_hg38 = paste0(a$CHR_HG38[bad_chr], ":", a$MAPINFO_HG38[bad_chr]),
    chain_hg38 = paste0(lifted[, "chr"], ":", lifted[, "pos"])
  )
  print(corrections, row.names = FALSE)
  stopifnot(all(lifted[, "chr"] == "chr11"), all(as.numeric(lifted[, "pos"]) == a$MAPINFO_HG38[bad_chr]))
  a$CHR_HG38[bad_chr] <- "chr11"
  cat("Corrected CHR_HG38 to chr11 for", length(bad_chr), "probes (chain-verified)\n")
}
stopifnot(all(with_chr(a$CHR_HG38) == "chr11"))
a$CHR_HG38 <- with_chr(a$CHR_HG38)

# hg38 has a 2 bp indel inside 11p15.5, so the offset is -21230 or -21232.
offset <- a$MAPINFO_HG38 - a$MAPINFO_HG19
cat("hg19 -> hg38 offsets:\n")
print(table(offset))
stopifnot(diff(range(offset)) <= 2)

panel <- chr11p15_hg19
panel$CHR <- a$CHR_HG38
panel$MAPINFO <- a$MAPINFO_HG38
rownames(panel) <- panel$NAME

# Consistency with hg38 chr11p15_region: each probe lies in the interval of its ICR.
in_icr <- vapply(seq_len(nrow(panel)), function(i) {
  w <- which(regions_hg38$ICR_name == panel$ICR_name[i])
  any(panel$MAPINFO[i] >= regions_hg38$start[w] & panel$MAPINFO[i] <= regions_hg38$end[w])
}, logical(1))
if (!all(in_icr)) print(panel[!in_icr, c("NAME", "MAPINFO", "ICR_name")])
stopifnot(all(in_icr))

# Order the hg38 panels as in hg19: probe-level panels, then the region panels.
panel_order <- c("Jima", "Joshi", "Court", "Rosenski", "selected", "NanoImprint",
                 "chr11p15", "Rosenski_region", "chr11p15_region")
before <- panels_hg38
panels_hg38[["chr11p15"]] <- panel
stopifnot(setequal(names(panels_hg38), panel_order))
panels_hg38 <- panels_hg38[panel_order]

tmp <- tempfile(fileext = ".rds")
saveRDS(panels_hg38, tmp, version = 3)
for (k in 1:10) {
  if (isTRUE(suppressWarnings(file.copy(tmp, "inst/extdata/probesets_hg38.rds", overwrite = TRUE)))) break
  if (k == 10) stop("Could not write inst/extdata/probesets_hg38.rds")
  Sys.sleep(1)
}

check <- readRDS("inst/extdata/probesets_hg38.rds")
c38 <- check[["chr11p15"]]
build_cols <- c("CHR", "MAPINFO")
stopifnot(
  nrow(c38) == 82L,
  identical(colnames(c38), colnames(chr11p15_hg19)),
  identical(c38$NAME, chr11p15_hg19$NAME),
  all(vapply(setdiff(colnames(c38), build_cols), function(cn) identical(c38[[cn]], chr11p15_hg19[[cn]]), logical(1))),
  identical(names(check), panel_order),
  identical(check[names(before)], before[names(before)])
)
cat("hg38 panels:", names(check), "\n")
print(table(c38$ICR_name, c38$ORIGIN))
cat("MAPINFO range hg38:", range(c38$MAPINFO), "\n")

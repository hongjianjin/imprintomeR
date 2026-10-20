panels_hg19 <- readRDS("inst/extdata/probesets_hg19.rds")
panel <- panels_hg19[["NanoImprint"]]
source_panel <- readRDS("inst/extdata/probesets_hg38.rds")[["NanoImprint"]]

stopifnot(
  nrow(panel) == 325L,
  !anyDuplicated(panel$NAME),
  !anyDuplicated(source_panel$NAME),
  setequal(panel$NAME, source_panel$NAME)
)

# ORIGIN, ICR_name, and region_T2T are transferred by stable Illumina probe NAME;
# hg19 coordinates are kept.
source_idx <- match(panel$NAME, source_panel$NAME)
panel$ORIGIN <- source_panel$ORIGIN[source_idx]
panel$ICR_name <- source_panel$ICR_name[source_idx]
panel$region_T2T <- source_panel$region_T2T[source_idx]
stopifnot(!anyNA(panel$ORIGIN), !anyNA(panel$ICR_name), !anyNA(panel$region_T2T))

# The NanoImprint authors provide no hg19 regions. Map each hg38 ROI from
# regions_hg38.bed to hg19 by inverting the aligned blocks of the UCSC
# hg19ToHg38 chain (hg19 = target, hg38 = query).
read_chain_blocks <- function(file, query_chrs) {
  lines <- readLines(file)
  header_idx <- grep("^chain ", lines)
  block_end <- c(header_idx[-1] - 1L, length(lines))
  blocks <- list()
  for (k in seq_along(header_idx)) {
    h <- strsplit(lines[header_idx[k]], " ", fixed = TRUE)[[1]]
    if (!h[8] %in% query_chrs || h[5] != "+" || h[10] != "+") next
    body <- lines[(header_idx[k] + 1L):block_end[k]]
    body <- body[nzchar(body)]
    fields <- strsplit(body, "\t", fixed = TRUE)
    size <- as.numeric(vapply(fields, `[`, "", 1L))
    dt <- c(as.numeric(vapply(fields[-length(fields)], `[`, "", 2L)), 0)
    dq <- c(as.numeric(vapply(fields[-length(fields)], `[`, "", 3L)), 0)
    t_start <- as.numeric(h[6]) + c(0, cumsum(size + dt)[-length(size)])
    q_start <- as.numeric(h[11]) + c(0, cumsum(size + dq)[-length(size)])
    blocks[[length(blocks) + 1L]] <- data.frame(
      chain_id = h[13], t_chr = h[3], q_chr = h[8],
      t_start = t_start, q_start = q_start, size = size
    )
  }
  do.call(rbind, blocks)
}

# Map one 0-based hg38 base to hg19; NA unless exactly one aligned block covers it.
map_hg38_to_hg19 <- function(chr, pos, blocks) {
  w <- which(blocks$q_chr == chr & pos >= blocks$q_start & pos < blocks$q_start + blocks$size)
  if (length(w) != 1L) return(c(chain_id = NA, chr = NA, pos = NA))
  c(chain_id = blocks$chain_id[w], chr = blocks$t_chr[w],
    pos = format(blocks$t_start[w] + pos - blocks$q_start[w], scientific = FALSE))
}

regions_hg38 <- read.table("tmp_ICR_sources/NanoImprint_2024/regions_hg38.bed", sep = "\t",
                           col.names = c("CHR", "start", "end"))
stopifnot(nrow(regions_hg38) == 15L)
regions_hg38$region_hg38 <- paste0(regions_hg38$CHR, ":", regions_hg38$start, "-", regions_hg38$end)
blocks <- read_chain_blocks("tmp_ICR_sources/hg19ToHg38.over.chain", unique(regions_hg38$CHR))

# BED intervals are half-open: lift the first base (start) and the last base (end - 1).
lifted <- do.call(rbind, lapply(seq_len(nrow(regions_hg38)), function(i) {
  s <- map_hg38_to_hg19(regions_hg38$CHR[i], regions_hg38$start[i], blocks)
  e <- map_hg38_to_hg19(regions_hg38$CHR[i], regions_hg38$end[i] - 1, blocks)
  data.frame(
    region_hg38 = regions_hg38$region_hg38[i],
    hg38_bp = regions_hg38$end[i] - regions_hg38$start[i],
    same_chain = identical(s[["chain_id"]], e[["chain_id"]]) && !is.na(s[["chain_id"]]),
    CHR = s[["chr"]],
    start = as.numeric(s[["pos"]]),
    end = as.numeric(e[["pos"]]) + 1
  )
}))
lifted$hg19_bp <- lifted$end - lifted$start
lifted$region <- paste0(lifted$CHR, ":", format(lifted$start, scientific = FALSE, trim = TRUE),
                        "-", format(lifted$end, scientific = FALSE, trim = TRUE))
print(lifted, row.names = FALSE)
stopifnot(
  all(lifted$same_chain),
  all(lifted$CHR == regions_hg38$CHR),
  all(lifted$hg19_bp > 0)
)

hg19_region <- setNames(lifted$region, lifted$region_hg38)
panel$region <- unname(hg19_region[source_panel$region[source_idx]])
stopifnot(!anyNA(panel$region))

# Every probe's own hg19 position must fall inside its lifted hg19 ROI.
lifted_idx <- match(panel$region, lifted$region)
inside <- panel$CHR == lifted$CHR[lifted_idx] &
  panel$MAPINFO >= lifted$start[lifted_idx] &
  panel$MAPINFO <= lifted$end[lifted_idx]
if (!all(inside)) print(panel[!inside, c("NAME", "CHR", "MAPINFO", "ICR_name", "region")])
stopifnot(all(inside))

panels_hg19[["NanoImprint"]] <- panel
saveRDS(panels_hg19, "inst/extdata/probesets_hg19.rds", version = 3)

check <- readRDS("inst/extdata/probesets_hg19.rds")[["NanoImprint"]]
stopifnot(
  nrow(check) == 325L,
  identical(as.integer(table(check$ORIGIN)), c(228L, 97L)),
  identical(table(check$ICR_name), table(source_panel$ICR_name)),
  all(grepl("^chr[0-9XY]+:[0-9]+-[0-9]+$", check$region))
)
cat("Origin counts:\n")
print(table(check$ORIGIN, useNA = "ifany"))
cat("Probes per ICR_name:\n")
print(table(check$ICR_name))

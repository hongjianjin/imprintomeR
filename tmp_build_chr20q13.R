# Build the chr20q13 (GNAS) locus panels in both genome builds, mirroring chr11p15:
#   chr20q13         probe-level panel: every 450K/EPIC probe inside the five GNAS DMR intervals
#                    of Rosenski_region (hg19), with the annotation of the curated Rosenski panel
#                    (ORIGIN, ICR_name, DMR_type from Monk et al. 2018, INFINIUM_DESIGN_TYPE).
#   chr20q13_region  region-level panel: the five GNAS rows of Rosenski_region.
# The hg38 panel has the same probes as hg19 (matched by NAME) with hg38 coordinates.
# Unlike chr11p15, the panel mixes gametic and secondary DMRs: GNAS-NESP (paternal) and
# GNAS A/B (maternal) are secondary, GNAS-AS1 and GNAS-XL (maternal) are gametic.
anno <- readRDS("inst/extdata/anno.uniq_harmonized.liftover.rds")
panels <- list(hg19 = readRDS("inst/extdata/probesets_hg19.rds"), hg38 = readRDS("inst/extdata/probesets_hg38.rds"))
gnas_icrs <- c("GNAS-NESP:TSS-DMR", "GNAS-AS1:TSS-DMR", "GNAS-XL:Ex1-DMR", "GNAS A/B:TSS-DMR")
columns <- c("NAME", "CHR", "MAPINFO", "Closest_TSS_gene_name", "region", "Arm", "GROUP", "ORIGIN",
             "ICR_name", "DMR_type", "DMR_type_source", "INFINIUM_DESIGN_TYPE")

# Region panels: the GNAS rows of Rosenski_region in each build.
region <- lapply(panels, function(p) {
  r <- p$Rosenski_region[p$Rosenski_region$ICR_name %in% gnas_icrs, , drop = FALSE]
  stopifnot(nrow(r) == 5L, all(r$CHR == "chr20"))
  rownames(r) <- NULL
  r
})
stopifnot(identical(region$hg19$ICR_name, region$hg38$ICR_name), identical(region$hg19$ORIGIN, region$hg38$ORIGIN))

# hg19 probe rule: 450K or EPIC (v1) probes inside the hg19 GNAS intervals.
on_v1 <- grepl("450K|EPICV10b5", anno$ASSAY)
in_interval <- function(chr, pos, r) {
  any_hit <- rep(FALSE, length(pos))
  for (i in seq_len(nrow(r))) any_hit <- any_hit | (!is.na(pos) & chr == "20" & pos >= r$start[i] & pos <= r$end[i])
  any_hit
}
rule_hg19 <- anno$NAME[on_v1 & in_interval(sub("^chr", "", anno$CHR_HG19), anno$MAPINFO_HG19, region$hg19)]

build <- function(p, probes) {
  x <- p$Rosenski[p$Rosenski$NAME %in% probes & p$Rosenski$ICR_name %in% gnas_icrs, , drop = FALSE]
  stopifnot(nrow(x) == length(probes), !anyNA(x$ORIGIN), all(x$DMR_type %in% c("gametic", "secondary")))
  x$Arm <- "20q"
  x$GROUP <- sub(":.*$", "", x$ICR_name)
  x <- x[order(x$MAPINFO), columns]
  rownames(x) <- NULL
  x
}
chr20q13 <- list(hg19 = build(panels$hg19, rule_hg19))
chr20q13$hg38 <- build(panels$hg38, chr20q13$hg19$NAME)
chr20q13$hg38 <- chr20q13$hg38[match(chr20q13$hg19$NAME, chr20q13$hg38$NAME), ]
rownames(chr20q13$hg38) <- NULL

# Four probes carry CHR_HG38 = "21" in the harmonized annotation (and hence in the hg38
# Rosenski panel) although their hg38 positions lie in the GNAS locus. Correct the
# chromosome only where the UCSC hg19ToHg38 chain maps the hg19 position to chr20 at
# exactly the annotated hg38 MAPINFO (same check as tmp_build_chr11p15_hg38.R).
bad_chr <- which(chr20q13$hg38$CHR != "chr20")
if (length(bad_chr)) {
  chain_file <- "tmp_ICR_sources/hg19ToHg38.over.chain"
  if (!file.exists(chain_file)) stop("Chain file needed to verify the CHR_HG38 corrections: ", chain_file)
  lines <- readLines(chain_file)
  header_idx <- grep("^chain ", lines)
  block_end <- c(header_idx[-1] - 1L, length(lines))
  blocks <- list()
  for (k in seq_along(header_idx)) {
    h <- strsplit(lines[header_idx[k]], " ", fixed = TRUE)[[1]]
    if (h[3] != "chr20" || h[5] != "+" || h[10] != "+") next
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
  hg19_pos <- chr20q13$hg19$MAPINFO[bad_chr]
  lifted <- t(vapply(hg19_pos, lift, c(chr = "", pos = "")))
  print(data.frame(NAME = chr20q13$hg38$NAME[bad_chr], hg19 = paste0("chr20:", hg19_pos),
                   anno_hg38 = paste0(chr20q13$hg38$CHR[bad_chr], ":", chr20q13$hg38$MAPINFO[bad_chr]),
                   chain_hg38 = paste0(lifted[, "chr"], ":", lifted[, "pos"])), row.names = FALSE)
  stopifnot(all(lifted[, "chr"] == "chr20"), all(as.numeric(lifted[, "pos"]) == chr20q13$hg38$MAPINFO[bad_chr]))
  chr20q13$hg38$CHR[bad_chr] <- "chr20"
  cat("Corrected CHR_HG38 to chr20 for", length(bad_chr), "probes (chain-verified)\n")
}

# Checks: the rule equals the curated Rosenski GNAS probes; builds share probes and annotation.
stopifnot(
  setequal(rule_hg19, panels$hg19$Rosenski$NAME[panels$hg19$Rosenski$ICR_name %in% gnas_icrs]),
  nrow(chr20q13$hg19) == 143L,
  identical(chr20q13$hg19$NAME, chr20q13$hg38$NAME),
  all(chr20q13$hg38$CHR == "chr20"),
  identical(chr20q13$hg38$MAPINFO, anno$MAPINFO_HG38[match(chr20q13$hg38$NAME, anno$NAME)])
)
for (cn in c("ORIGIN", "ICR_name", "DMR_type", "DMR_type_source", "INFINIUM_DESIGN_TYPE", "GROUP", "Arm")) {
  stopifnot(identical(chr20q13$hg19[[cn]], chr20q13$hg38[[cn]]))
}
# Probes in selected keep the same ICR, origin and DMR type.
for (b in names(panels)) {
  s <- panels[[b]]$selected
  m <- match(s$NAME, chr20q13[[b]]$NAME)
  k <- !is.na(m)
  stopifnot(sum(k) == 126L, identical(s$ORIGIN[k], chr20q13[[b]]$ORIGIN[m[k]]), identical(s$DMR_type[k], chr20q13[[b]]$DMR_type[m[k]]))
}
print(table(chr20q13$hg19$ICR_name, paste(chr20q13$hg19$ORIGIN, chr20q13$hg19$DMR_type)))
outside <- !in_interval(sub("^chr", "", chr20q13$hg38$CHR), chr20q13$hg38$MAPINFO, region$hg38)
cat("hg38 probes outside the lifted hg38 intervals:", paste(chr20q13$hg38$NAME[outside], collapse = ", "), "\n")

# Insert chr20q13 after chr11p15 and chr20q13_region after chr11p15_region, in both builds.
panel_order <- c("Jima", "Joshi", "Court", "Rosenski", "selected", "NanoImprint", "chr11p15", "chr20q13",
                 "Rosenski_region", "chr11p15_region", "chr20q13_region")
for (b in names(panels)) {
  p <- panels[[b]]
  p$chr20q13 <- chr20q13[[b]]
  p$chr20q13_region <- region[[b]]
  stopifnot(setequal(names(p), panel_order))
  p <- p[panel_order]
  path <- sprintf("inst/extdata/probesets_%s.rds", b)
  # Write to a temporary file, then copy into place with retries (files in
  # inst/extdata are occasionally locked briefly by other processes on Windows).
  tmp <- tempfile(fileext = ".rds")
  saveRDS(p, tmp, version = 3)
  for (k in 1:10) {
    if (isTRUE(suppressWarnings(file.copy(tmp, path, overwrite = TRUE)))) break
    if (k == 10) stop("Could not write ", path)
    Sys.sleep(1)
  }
  cat(b, ":", paste(names(readRDS(path)), collapse = ", "), "\n")
}

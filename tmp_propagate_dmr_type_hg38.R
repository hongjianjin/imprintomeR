# Copy ICR_name, DMR_type and DMR_type_source from the hg19 Court, Jima, Joshi, Rosenski and
# NanoImprint panels (tmp_annotate_selected_dmr_type.R) to the hg38 panels by stable probe NAME.
# The annotation describes the DMR, not the genome build. Probes present only in hg38 (two Jima
# probes without hg19 coordinates) are assigned with the hg38 Rosenski_region intervals, which list
# the same DMRs in the same order as hg19; they are typed "uncurated" outside those intervals.
p19 <- readRDS("inst/extdata/probesets_hg19.rds")
panels_hg38 <- readRDS("inst/extdata/probesets_hg38.rds")
monk <- read.delim("tmp_ICR_sources/Monk_2018/Table1_germline_status.tsv", quote = "", stringsAsFactors = FALSE)
ann_cols <- c("ICR_name", "DMR_type", "DMR_type_source")
targets <- c("Court", "Jima", "Joshi", "Rosenski", "NanoImprint")

r19 <- p19[["Rosenski_region"]]
r38 <- panels_hg38[["Rosenski_region"]]
stopifnot(nrow(r19) == nrow(r38), identical(r19$ICR_name, r38$ICR_name))

# Monk DMR (hg19 coordinates) overlapping each Rosenski_region row; the smallest wins.
region_monk <- vapply(seq_len(nrow(r19)), function(j) {
  w <- which(monk$CHR == r19$CHR[j] & monk$start_hg19 <= r19$end[j] & monk$end_hg19 >= r19$start[j])
  if (!length(w)) NA_integer_ else w[which.min(monk$end_hg19[w] - monk$start_hg19[w])]
}, integer(1))

annotate_hg38_only <- function(p) {
  hit <- vapply(seq_len(nrow(p)), function(i) {
    w <- which(r38$CHR == p$CHR[i] & p$MAPINFO[i] >= r38$start & p$MAPINFO[i] <= r38$end)
    if (length(w) == 1L) w else NA_integer_
  }, integer(1))
  mi <- region_monk[hit]
  type_map <- c("Oocyte gDMR" = "gametic", "Sperm gDMR" = "gametic", "Secondary DMR" = "secondary",
                "Oocyte gDMR- secondary DMR" = "ambiguous", "none" = "unclassified")
  data.frame(
    ICR_name = ifelse(!is.na(mi), monk$ICR_name[mi], r38$ICR_name[hit]),
    DMR_type = ifelse(!is.na(mi),
                      ifelse(!is.na(p$ORIGIN) & p$ORIGIN != monk$ORIGIN[mi], "origin_conflict", monk$DMR_type[mi]),
                      ifelse(is.na(hit), "uncurated", unname(type_map[r38$ICR_type[hit]]))),
    DMR_type_source = ifelse(!is.na(mi), "Monk2018_Table1",
                             ifelse(is.na(hit), NA_character_, "Rosenski_region ICR_type (imprintomeR curation)")),
    stringsAsFactors = FALSE
  )
}

before <- panels_hg38
for (name in targets) {
  h19 <- p19[[name]]
  h38 <- panels_hg38[[name]]
  stopifnot(all(ann_cols %in% colnames(h19)), !anyDuplicated(h38$NAME))
  idx <- match(h38$NAME, h19$NAME)
  if (name == "NanoImprint") {
    # hg38 NanoImprint already carries its own ICR_name; it must agree with the hg19 copy.
    stopifnot(!anyNA(idx), identical(h38$ICR_name, h19$ICR_name[idx]))
  } else {
    h38$ICR_name <- h19$ICR_name[idx]
  }
  h38$DMR_type <- h19$DMR_type[idx]
  h38$DMR_type_source <- h19$DMR_type_source[idx]
  only38 <- which(is.na(idx))
  if (length(only38)) {
    extra <- annotate_hg38_only(h38[only38, , drop = FALSE])
    h38[only38, ann_cols] <- extra
    cat(name, ": hg38-only probes annotated from hg38 intervals:\n")
    print(cbind(h38[only38, c("NAME", "CHR", "MAPINFO", "ORIGIN")], extra))
  }
  stopifnot(!anyNA(h38$DMR_type))
  panels_hg38[[name]] <- h38
}

tmp <- tempfile(fileext = ".rds")
saveRDS(panels_hg38, tmp, version = 3)
for (k in 1:10) {
  if (isTRUE(suppressWarnings(file.copy(tmp, "inst/extdata/probesets_hg38.rds", overwrite = TRUE)))) break
  if (k == 10) stop("Could not write inst/extdata/probesets_hg38.rds")
  Sys.sleep(1)
}

check <- readRDS("inst/extdata/probesets_hg38.rds")
stopifnot(identical(names(check), names(before)))
for (name in names(check)) {
  if (!(name %in% targets)) {
    stopifnot(identical(check[[name]], before[[name]]))
    next
  }
  old_cols <- setdiff(colnames(before[[name]]), ann_cols)
  stopifnot(identical(check[[name]][old_cols], before[[name]][old_cols]))
  shared <- intersect(check[[name]]$NAME, p19[[name]]$NAME)
  a <- check[[name]][match(shared, check[[name]]$NAME), ann_cols]
  b <- p19[[name]][match(shared, p19[[name]]$NAME), ann_cols]
  rownames(a) <- rownames(b) <- NULL
  stopifnot(identical(a, b))
  cat(sprintf("%-12s hg38 annotated: %d probes (%d shared with hg19)\n", name, nrow(check[[name]]), length(shared)))
}

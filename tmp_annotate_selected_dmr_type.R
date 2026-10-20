# Annotate hg19 probe panels with ICR_name, DMR_type, and DMR_type_source.
# Panels annotated: `selected` and `chr11p15`.
panels <- readRDS("inst/extdata/probesets_hg19.rds")
regions <- panels[["Rosenski_region"]]
monk <- read.delim("tmp_ICR_sources/Monk_2018/Table1_germline_status.tsv", quote = "", stringsAsFactors = FALSE)

stopifnot(
  all(c("CHR", "start", "end", "ICR_name", "ICR_type") %in% colnames(regions)),
  nrow(monk) == 50L,
  !anyDuplicated(monk$ICR_name),
  all(monk$DMR_type %in% c("gametic", "secondary", "ambiguous"))
)

# DMR_type comes from Monk et al. 2018 Table 1 ("Germline derived") when the DMR is
# listed there. Otherwise it falls back to the project-curated Rosenski_region
# ICR_type; Rosenski 2025 Data S2 itself provides only DMR names and boundaries.
#
# Rosenski_region rows are matched to Monk DMRs by coordinate overlap, not by name:
# Data S2 swaps the two DIRAS3 DMR names relative to Monk, and lists Monk's
# MEG8:Int2-DMR interval under the name "RTL1".
rosenski_type_map <- c(
  "Oocyte gDMR" = "gametic",
  "Sperm gDMR" = "gametic",
  "Secondary DMR" = "secondary",
  "Oocyte gDMR- secondary DMR" = "ambiguous",
  "none" = "unclassified"
)
stopifnot(all(regions$ICR_type %in% names(rosenski_type_map)))
source_monk <- "Monk2018_Table1"
source_rosenski <- "Rosenski_region ICR_type (imprintomeR curation)"

# Monk Table 1 prints SNRPN:Int1-DMR1 as 25,093,008-25,193,829 (~100 kb for 44 CpGs,
# likely a typo), which contains SNRPN:Int1-DMR2. Where intervals overlap more
# than one Monk DMR, take the smallest (most specific) one.
pick_monk <- function(w) {
  if (!length(w)) return(NA_integer_)
  w[which.min(monk$end_hg19[w] - monk$start_hg19[w])]
}

# Map each Rosenski_region row to the Monk DMR it overlaps, if any.
region_monk <- vapply(seq_len(nrow(regions)), function(j) {
  pick_monk(which(monk$CHR == regions$CHR[j] & monk$start_hg19 <= regions$end[j] & monk$end_hg19 >= regions$start[j]))
}, integer(1))

# Rosenski boundaries are refined (ubiquitously hyper/hypomethylated sub-regions
# removed), so probes outside them stay uncurated even when they fall within
# Monk's wider methyl-seq extent. The exception is a Monk DMR with no Rosenski
# counterpart (SVOPL:alt-TSS-DMR), whose probes are assigned by Monk's extent.
monk_without_rosenski <- setdiff(seq_len(nrow(monk)), region_monk)

annotate_panel <- function(panel, name) {
  stopifnot(!anyDuplicated(panel$NAME), !anyNA(panel$ORIGIN))

  # Assign each probe to the single hg19 Rosenski_region interval containing it.
  hit <- vapply(seq_len(nrow(panel)), function(i) {
    w <- which(regions$CHR == panel$CHR[i] &
                 panel$MAPINFO[i] >= regions$start &
                 panel$MAPINFO[i] <= regions$end)
    if (length(w) > 1L) stop("Probe ", panel$NAME[i], " overlaps more than one Rosenski_region interval.")
    if (length(w) == 1L) w else NA_integer_
  }, integer(1))

  direct_monk <- vapply(seq_len(nrow(panel)), function(i) {
    w <- which(monk$CHR == panel$CHR[i] & panel$MAPINFO[i] >= monk$start_hg19 & panel$MAPINFO[i] <= monk$end_hg19)
    pick_monk(intersect(w, monk_without_rosenski))
  }, integer(1))

  monk_idx <- ifelse(is.na(hit), direct_monk, region_monk[hit])
  in_monk <- !is.na(monk_idx)
  panel$ICR_name <- ifelse(in_monk, monk$ICR_name[monk_idx], regions$ICR_name[hit])
  panel$DMR_type <- ifelse(
    in_monk, monk$DMR_type[monk_idx],
    ifelse(is.na(hit), "uncurated", unname(rosenski_type_map[regions$ICR_type[hit]]))
  )
  panel$DMR_type_source <- ifelse(in_monk, source_monk, ifelse(is.na(hit), NA_character_, source_rosenski))

  # Probe ORIGIN must agree with the Monk 2018 methylation origin of its DMR.
  mismatch <- in_monk & panel$ORIGIN != monk$ORIGIN[monk_idx]
  if (any(mismatch)) print(panel[mismatch, c("NAME", "CHR", "MAPINFO", "ORIGIN", "ICR_name", "DMR_type")])
  stopifnot(!any(mismatch))
  panel
}

type_levels <- c("gametic", "secondary", "ambiguous", "unclassified", "uncurated")
count_types <- function(panel) {
  unclass(table(factor(panel$DMR_type, levels = type_levels), factor(panel$ORIGIN, levels = c("maternal", "paternal"))))
}

# Expected maternal / paternal counts per DMR_type, in type_levels order.
expected <- list(
  selected = list(n = 782L, maternal = c(505L, 68L, 4L, 0L, 78L), paternal = c(49L, 68L, 8L, 0L, 2L)),
  chr11p15 = list(n = 82L, maternal = c(31L, 0L, 0L, 0L, 0L), paternal = c(51L, 0L, 0L, 0L, 0L))
)

for (name in names(expected)) {
  stopifnot(nrow(panels[[name]]) == expected[[name]]$n)
  annotated <- annotate_panel(panels[[name]], name)
  counts <- count_types(annotated)
  cat("\n==", name, "\n")
  print(counts)
  stopifnot(all(counts[, "maternal"] == expected[[name]]$maternal),
            all(counts[, "paternal"] == expected[[name]]$paternal))
  panels[[name]] <- annotated
}

# Write to a temporary file, then copy into place with retries (files in
# inst/extdata are occasionally locked briefly by other processes on Windows).
tmp <- tempfile(fileext = ".rds")
saveRDS(panels, tmp, version = 3)
for (k in 1:10) {
  if (isTRUE(suppressWarnings(file.copy(tmp, "inst/extdata/probesets_hg19.rds", overwrite = TRUE)))) break
  if (k == 10) stop("Could not write inst/extdata/probesets_hg19.rds")
  Sys.sleep(1)
}

check <- readRDS("inst/extdata/probesets_hg19.rds")
for (name in names(expected)) {
  stopifnot(
    nrow(check[[name]]) == expected[[name]]$n,
    all(c("ICR_name", "DMR_type", "DMR_type_source") %in% colnames(check[[name]])),
    !anyNA(check[[name]]$DMR_type)
  )
  g <- check[[name]]$DMR_type == "gametic"
  cat("\n", name, ": gametic probes by ICR_name and ORIGIN\n", sep = "")
  print(table(check[[name]]$ICR_name[g], check[[name]]$ORIGIN[g]))
}

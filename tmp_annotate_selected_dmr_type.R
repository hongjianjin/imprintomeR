panels <- readRDS("inst/extdata/probesets_hg19.rds")
panel <- panels[["selected"]]
regions <- panels[["Rosenski_region"]]
monk <- read.delim("tmp_ICR_sources/Monk_2018/Table1_germline_status.tsv", quote = "", stringsAsFactors = FALSE)

stopifnot(
  nrow(panel) == 782L,
  !anyDuplicated(panel$NAME),
  !anyNA(panel$ORIGIN),
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

# Assign each probe to the single hg19 Rosenski_region interval containing it.
hit <- vapply(seq_len(nrow(panel)), function(i) {
  w <- which(regions$CHR == panel$CHR[i] &
               panel$MAPINFO[i] >= regions$start &
               panel$MAPINFO[i] <= regions$end)
  if (length(w) > 1L) stop("Probe ", panel$NAME[i], " overlaps more than one Rosenski_region interval.")
  if (length(w) == 1L) w else NA_integer_
}, integer(1))

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

type_levels <- c("gametic", "secondary", "ambiguous", "unclassified", "uncurated")
counts <- table(factor(panel$DMR_type, levels = type_levels), factor(panel$ORIGIN, levels = c("maternal", "paternal")))
print(counts)
expected <- matrix(c(505L, 68L, 4L, 0L, 78L, 49L, 68L, 8L, 0L, 2L), ncol = 2,
                   dimnames = list(type_levels, c("maternal", "paternal")))
stopifnot(all(as.matrix(unclass(counts)) == expected))

# Write to a temporary file, then copy into place with retries (files in
# inst/extdata are occasionally locked briefly by other processes on Windows).
panels[["selected"]] <- panel
tmp <- tempfile(fileext = ".rds")
saveRDS(panels, tmp, version = 3)
for (k in 1:10) {
  if (isTRUE(suppressWarnings(file.copy(tmp, "inst/extdata/probesets_hg19.rds", overwrite = TRUE)))) break
  if (k == 10) stop("Could not write inst/extdata/probesets_hg19.rds")
  Sys.sleep(1)
}

check <- readRDS("inst/extdata/probesets_hg19.rds")[["selected"]]
stopifnot(
  nrow(check) == 782L,
  all(c("ICR_name", "DMR_type", "DMR_type_source") %in% colnames(check)),
  !anyNA(check$DMR_type)
)
cat("Probes by DMR_type_source:\n")
print(table(check$DMR_type_source, useNA = "ifany"))
cat("Gametic probes by ICR_name and ORIGIN:\n")
print(table(check$ICR_name[check$DMR_type == "gametic"], check$ORIGIN[check$DMR_type == "gametic"]))

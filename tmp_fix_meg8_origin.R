# Correct the parental origin of Monk et al. 2018 MEG8:Int2-DMR (maternal methylation,
# secondary DMR; hg19 chr14:101,370,741-101,371,419).
#
# Rosenski 2025 Data S2 lists this exact interval (its "original icr" coordinates)
# under the name "RTL1"; Rosenski_region labelled it paternal. Data S2's own
# "MEG8:Int2-DMR" row (hg19 chr14:101,348,186-101,349,932) does not overlap any
# Monk 2018 DMR and is left unchanged here.
monk <- read.delim("tmp_ICR_sources/Monk_2018/Table1_germline_status.tsv", quote = "", stringsAsFactors = FALSE)
meg8 <- monk[monk$ICR_name == "MEG8:Int2-DMR", ]
stopifnot(nrow(meg8) == 1L, meg8$ORIGIN == "maternal")
origin_rule <- "Monk2018_Table1_coordinate_match:MEG8:Int2-DMR(maternal);DataS2_name:RTL1"

fix_region_row <- function(regions) {
  i <- which(regions$ICR_name == "RTL1" & regions$CHR == "chr14")
  stopifnot(length(i) == 1L, regions$ORIGIN[i] == "paternal")
  regions$ORIGIN[i] <- "maternal"
  regions$ORIGIN_rule[i] <- origin_rule
  regions
}

meg8_probes <- c("cg06804177", "cg03664700", "cg26981637")
fix_probes <- function(panel, names, expected_n) {
  i <- which(panel$NAME %in% names)
  stopifnot(length(i) == expected_n, all(panel$ORIGIN[i] == "paternal"))
  panel$ORIGIN[i] <- "maternal"
  panel
}

p19 <- readRDS("inst/extdata/probesets_hg19.rds")
p38 <- readRDS("inst/extdata/probesets_hg38.rds")
r38 <- readRDS("inst/extdata/probesets_hg38_regions.rds")

# The hg19 Rosenski probes in the corrected interval must be exactly these three.
rr19 <- p19$Rosenski_region[p19$Rosenski_region$ICR_name == "RTL1", ]
in_rtl1 <- p19$Rosenski$CHR == "chr14" & p19$Rosenski$MAPINFO >= rr19$start & p19$Rosenski$MAPINFO <= rr19$end
stopifnot(setequal(p19$Rosenski$NAME[in_rtl1], meg8_probes),
          rr19$start <= meg8$start_hg19, rr19$end >= meg8$end_hg19)

p19$Rosenski_region <- fix_region_row(p19$Rosenski_region)
r38$Rosenski_region <- fix_region_row(r38$Rosenski_region)
p19$Rosenski <- fix_probes(p19$Rosenski, meg8_probes, 3L)
p38$Rosenski <- fix_probes(p38$Rosenski, meg8_probes, 3L)
# NanoImprint ORIGIN is transferred from the Rosenski probe panel by NAME
# (tmp_update_nanoprint_region.R for hg38, then copied to hg19 by NAME).
p38$NanoImprint <- fix_probes(p38$NanoImprint, "cg06804177", 1L)
p19$NanoImprint <- fix_probes(p19$NanoImprint, "cg06804177", 1L)

# Write all outputs to temporary files first, then copy them into place with retries
# (files in inst/extdata are occasionally locked briefly by other processes on Windows).
save_rds <- function(obj, path) {
  tmp <- tempfile(fileext = ".rds")
  saveRDS(obj, tmp, version = 3)
  tmp
}
replace_file <- function(tmp, path, tries = 10L) {
  for (k in seq_len(tries)) {
    if (isTRUE(suppressWarnings(file.copy(tmp, path, overwrite = TRUE)))) return(invisible(TRUE))
    Sys.sleep(1)
  }
  stop("Could not write ", path, " after ", tries, " attempts.")
}
outputs <- list(
  "inst/extdata/probesets_hg19.rds" = save_rds(p19),
  "inst/extdata/probesets_hg38.rds" = save_rds(p38),
  "inst/extdata/probesets_hg38_regions.rds" = save_rds(r38)
)
for (path in names(outputs)) replace_file(outputs[[path]], path)

c19 <- readRDS("inst/extdata/probesets_hg19.rds"); c38 <- readRDS("inst/extdata/probesets_hg38.rds")
stopifnot(
  identical(as.integer(table(c19$Rosenski$ORIGIN)), c(832L, 183L)),
  identical(as.integer(table(c38$Rosenski$ORIGIN)), c(832L, 183L)),
  identical(as.integer(table(c19$NanoImprint$ORIGIN)), c(228L, 97L)),
  identical(as.integer(table(c38$NanoImprint$ORIGIN)), c(228L, 97L))
)
cat("Rosenski (both builds): 832 maternal / 183 paternal / 35 NA; NanoImprint (both builds): 228 / 97\n")

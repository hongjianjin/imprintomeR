panel <- readRDS(file.path("inst", "extdata", "probesets_hg19.rds"))[["NanoImprint"]]
annotation <- readRDS(file.path("inst", "extdata", "anno.uniq_harmonized.liftover.rds"))
annotation_idx <- match(panel[["NAME"]], annotation[["NAME"]])

stopifnot(
  nrow(panel) == 325L,
  !anyDuplicated(panel[["NAME"]]),
  all(!is.na(panel[["CHR"]]) & !is.na(panel[["MAPINFO"]]))
)

expected_mapinfo <- annotation[["MAPINFO_HG19"]][annotation_idx]
position_mismatch <- panel[["MAPINFO"]] != expected_mapinfo
cat("Coordinates differing from bundled annotation:", sum(position_mismatch), "\n")

expected_chr <- as.character(annotation[["CHR_HG19"]][annotation_idx])
expected_chr[!grepl("^chr", expected_chr)] <- paste0(
  "chr",
  expected_chr[!grepl("^chr", expected_chr)]
)
if (any(panel[["CHR"]] != expected_chr)) {
  print(data.frame(
    NAME = panel[["NAME"]][panel[["CHR"]] != expected_chr],
    lifted = panel[["CHR"]][panel[["CHR"]] != expected_chr],
    annotation = expected_chr[panel[["CHR"]] != expected_chr]
  ))
}
stopifnot(all(panel[["CHR"]] == expected_chr))

cat("Validated 325 unique NanoImprint hg19 coordinates\n")
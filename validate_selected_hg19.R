panel <- readRDS(file.path("inst", "extdata", "probesets_hg19.rds"))[["selected"]]
merge_list <- read.delim(
  file.path("tmp_ICR_sources", "probes", "2026-10-19.mergeList_4_hg19_selected.txt"),
  check.names = FALSE,
  stringsAsFactors = FALSE
)
required <- c("NAME", "CHR", "MAPINFO", "Closest_TSS_gene_name", "ORIGIN", "region")

stopifnot(
  nrow(panel) == 782L,
  identical(names(panel), required),
  identical(panel$NAME, merge_list$NAME),
  !anyDuplicated(panel$NAME),
  !anyNA(panel$CHR),
  !anyNA(panel$MAPINFO),
  !anyNA(panel$region)
)

cat(
  "rows=", nrow(panel),
  "; missing_ORIGIN=", sum(is.na(panel$ORIGIN)),
  "; missing_gene=", sum(is.na(panel$Closest_TSS_gene_name) | !nzchar(panel$Closest_TSS_gene_name)),
  "\n",
  sep = ""
)
merge_path <- file.path("tmp_ICR_sources", "probes", "2026-10-19.mergeList_4_hg19.txt")
annotation_path <- file.path("inst", "extdata", "anno.uniq_harmonized.liftover.rds")

merge_list <- read.delim(merge_path, check.names = FALSE, stringsAsFactors = FALSE)
annotation <- readRDS(annotation_path)

stopifnot(
  "Symbol" %in% names(merge_list),
  all(c("NAME", "ASSAY") %in% names(annotation)),
  !anyDuplicated(merge_list$Symbol),
  !anyDuplicated(annotation$NAME)
)

assay <- annotation$ASSAY[match(merge_list$Symbol, annotation$NAME)]
stopifnot(!anyNA(assay), length(assay) == nrow(merge_list))

merge_list$ASSAY <- assay
write.table(
  merge_list,
  merge_path,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE,
  na = ""
)

cat("Updated", nrow(merge_list), "rows; assay categories:\n")
print(table(merge_list$ASSAY, useNA = "ifany"))
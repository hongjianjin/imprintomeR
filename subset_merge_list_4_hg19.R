input_path <- file.path("tmp_ICR_sources", "probes", "2026-10-19.mergeList_4_hg19.txt")
output_path <- file.path("tmp_ICR_sources", "probes", "2026-10-19.mergeList_4_hg19_selected.txt")

merge_list <- read.delim(input_path, check.names = FALSE, stringsAsFactors = FALSE)
stopifnot(all(c("count", "ASSAY") %in% names(merge_list)))

selected <- merge_list[
  merge_list$count >= 2L & grepl("450K,EPIC", merge_list$ASSAY, fixed = TRUE),
  , drop = FALSE
]

write.table(
  selected,
  output_path,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE,
  na = ""
)

stopifnot(
  all(selected$count >= 2L),
  all(grepl("450K,EPIC", selected$ASSAY, fixed = TRUE))
)
cat("Selected", nrow(selected), "rows\n")
print(table(selected$ASSAY, useNA = "ifany"))
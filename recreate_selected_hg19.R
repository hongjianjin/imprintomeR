probeset_path <- file.path("inst", "extdata", "probesets_hg19.rds")
merge_path <- file.path("tmp_ICR_sources", "probes", "2026-10-19.mergeList_4_hg19_selected.txt")

panels <- readRDS(probeset_path)
selected_old <- panels[["selected"]]
court <- panels[["Court"]]
jima <- panels[["Jima"]]
joshi <- panels[["Joshi"]]
rosenski <- panels[["Rosenski"]]
annotation <- readRDS(file.path("inst", "extdata", "anno.uniq_harmonized.liftover.rds"))
merge_list <- read.delim(merge_path, check.names = FALSE, stringsAsFactors = FALSE)

required <- c("NAME", "CHR", "MAPINFO", "Closest_TSS_gene_name", "ORIGIN", "region")
stopifnot(
  all(required %in% names(selected_old)),
  all(required %in% names(rosenski)),
  all(c("NAME", "CHR_HG19", "MAPINFO_HG19", "UCSC_REFGENE_NAME") %in% names(annotation)),
  "NAME" %in% names(merge_list),
  !anyDuplicated(merge_list$NAME)
)

probe_names <- as.character(merge_list$NAME)
old_idx <- match(probe_names, selected_old$NAME)
rosenski_idx <- match(probe_names, rosenski$NAME)
annotation_idx <- match(probe_names, annotation$NAME)

result <- data.frame(
  NAME = probe_names,
  CHR = selected_old$CHR[old_idx],
  MAPINFO = selected_old$MAPINFO[old_idx],
  Closest_TSS_gene_name = selected_old$Closest_TSS_gene_name[old_idx],
  ORIGIN = selected_old$ORIGIN[old_idx],
  region = selected_old$region[old_idx],
  stringsAsFactors = FALSE
)

fill_from <- function(target, source) {
  missing <- is.na(target) | !nzchar(as.character(target))
  target[missing] <- source[missing]
  target
}

result$CHR <- fill_from(result$CHR, rosenski$CHR[rosenski_idx])
result$MAPINFO <- fill_from(result$MAPINFO, rosenski$MAPINFO[rosenski_idx])
result$Closest_TSS_gene_name <- fill_from(
  result$Closest_TSS_gene_name,
  rosenski$Closest_TSS_gene_name[rosenski_idx]
)
result$ORIGIN <- fill_from(result$ORIGIN, rosenski$ORIGIN[rosenski_idx])
result$region <- fill_from(result$region, rosenski$region[rosenski_idx])

annotation_chr <- annotation$CHR_HG19[annotation_idx]
annotation_mapinfo <- annotation$MAPINFO_HG19[annotation_idx]
annotation_gene <- annotation$UCSC_REFGENE_NAME[annotation_idx]
annotation_gene[!nzchar(annotation_gene)] <- NA_character_

result$CHR <- fill_from(result$CHR, ifelse(is.na(annotation_chr), NA, paste0("chr", annotation_chr)))
result$MAPINFO <- fill_from(result$MAPINFO, annotation_mapinfo)
result$Closest_TSS_gene_name <- fill_from(result$Closest_TSS_gene_name, annotation_gene)

coordinate_region <- ifelse(
  !is.na(result$CHR) & !is.na(result$MAPINFO),
  paste0(result$CHR, ":", result$MAPINFO, "-", result$MAPINFO),
  NA_character_
)
result$region <- fill_from(result$region, coordinate_region)

for (source in list(court, jima, joshi, rosenski)) {
  source_idx <- match(result$NAME, source$NAME)
  result$Closest_TSS_gene_name <- fill_from(
    result$Closest_TSS_gene_name,
    source$Closest_TSS_gene_name[source_idx]
  )
  result$ORIGIN <- fill_from(result$ORIGIN, source$ORIGIN[source_idx])
}

stopifnot(
  nrow(result) == nrow(merge_list),
  identical(result$NAME, probe_names),
  !anyDuplicated(result$NAME),
  !anyNA(result$CHR),
  !anyNA(result$MAPINFO),
  !anyNA(result$region),
  !anyNA(result$ORIGIN),
  !is.na(result$Closest_TSS_gene_name) & nzchar(result$Closest_TSS_gene_name),
  all(names(result) == required)
)

panels[["selected"]] <- result
saveRDS(panels, probeset_path, version = 3)

cat("Recreated selected panel:", nrow(result), "probes\n")
cat("Existing selected matches:", sum(!is.na(old_idx)), "\n")
cat("Rosenski matches:", sum(!is.na(rosenski_idx)), "\n")
cat("Annotation matches:", sum(!is.na(annotation_idx)), "\n")
print(table(result$ORIGIN, useNA = "ifany"))
# Build the hg38 `selected` panel from hg19 `selected` by stable Illumina probe NAME.
# hg38 CHR/MAPINFO come from anno.uniq_harmonized.liftover.rds; ORIGIN, ICR_name,
# DMR_type, and DMR_type_source are build-independent and copied by NAME. Each hg38
# `region` is the span of the group's probes in hg38, as for the hg38 Court panel.
selected_hg19 <- readRDS("inst/extdata/probesets_hg19.rds")[["selected"]]
panels_hg38 <- readRDS("inst/extdata/probesets_hg38.rds")
anno <- readRDS("inst/extdata/anno.uniq_harmonized.liftover.rds")
regions_hg38 <- panels_hg38[["Rosenski_region"]]

copied_cols <- c("Closest_TSS_gene_name", "ORIGIN", "ICR_name", "DMR_type", "DMR_type_source")
stopifnot(
  nrow(selected_hg19) == 782L,
  !anyDuplicated(selected_hg19$NAME),
  all(c("NAME", "CHR", "MAPINFO", "region", copied_cols) %in% colnames(selected_hg19)),
  !anyDuplicated(anno$NAME)
)

idx <- match(selected_hg19$NAME, anno$NAME)
stopifnot(!anyNA(idx))
a <- anno[idx, ]

# The harmonized annotation must agree with the hg19 panel before its hg38 fields are
# used. CHR_HG19 is stored without the "chr" prefix for some probes.
with_chr <- function(x) ifelse(grepl("^chr", x), x, paste0("chr", x))
stopifnot(
  all(with_chr(a$CHR_HG19) == selected_hg19$CHR),
  all(a$MAPINFO_HG19 == selected_hg19$MAPINFO),
  !anyNA(a$CHR_HG38), !anyNA(a$MAPINFO_HG38),
  all(grepl("^chr([0-9]+|X|Y)$", a$CHR_HG38)),
  all(a$MAPINFO_HG38 > 0),
  all(a$CHR_HG38 == selected_hg19$CHR)
)

panel <- data.frame(
  NAME = selected_hg19$NAME,
  CHR = a$CHR_HG38,
  MAPINFO = a$MAPINFO_HG38,
  selected_hg19[, copied_cols],
  stringsAsFactors = FALSE
)

# hg38 region = span of each hg19 region group's probes in hg38.
group <- selected_hg19$region
span <- tapply(seq_len(nrow(panel)), group, function(i) {
  stopifnot(length(unique(panel$CHR[i])) == 1L)
  paste0(panel$CHR[i[1]], ":", min(panel$MAPINFO[i]), "-", max(panel$MAPINFO[i]))
})
panel$region <- unname(span[group])
stopifnot(
  !anyNA(panel$region),
  length(unique(panel$region)) == length(unique(group))
)
panel <- panel[, c("NAME", "CHR", "MAPINFO", "Closest_TSS_gene_name", "ORIGIN", "region", "ICR_name", "DMR_type", "DMR_type_source")]
rownames(panel) <- panel$NAME

# Consistency with hg38 Rosenski_region: probes curated in hg19 (ICR_name not NA,
# other than the Monk-only SVOPL:alt-TSS-DMR) must also lie in an hg38 interval.
in_region <- vapply(seq_len(nrow(panel)), function(i) {
  any(regions_hg38$CHR == panel$CHR[i] & panel$MAPINFO[i] >= regions_hg38$start & panel$MAPINFO[i] <= regions_hg38$end)
}, logical(1))
curated <- !is.na(panel$ICR_name) & panel$ICR_name != "SVOPL:alt-TSS-DMR"
if (any(curated & !in_region)) print(panel[curated & !in_region, c("NAME", "CHR", "MAPINFO", "ICR_name")])
stopifnot(all(in_region[curated]), !any(in_region[is.na(panel$ICR_name)]))

# Insert after Rosenski, mirroring the hg19 panel order.
panels_hg38[["selected"]] <- NULL
pos <- match("Rosenski", names(panels_hg38))
panels_hg38 <- c(panels_hg38[seq_len(pos)], list(selected = panel), panels_hg38[-seq_len(pos)])

# Write to a temporary file, then copy into place with retries (files in
# inst/extdata are occasionally locked briefly by other processes on Windows).
tmp <- tempfile(fileext = ".rds")
saveRDS(panels_hg38, tmp, version = 3)
for (k in 1:10) {
  if (isTRUE(suppressWarnings(file.copy(tmp, "inst/extdata/probesets_hg38.rds", overwrite = TRUE)))) break
  if (k == 10) stop("Could not write inst/extdata/probesets_hg38.rds")
  Sys.sleep(1)
}

check <- readRDS("inst/extdata/probesets_hg38.rds")[["selected"]]
type_levels <- c("gametic", "secondary", "ambiguous", "unclassified", "uncurated")
counts <- table(factor(check$DMR_type, levels = type_levels), factor(check$ORIGIN, levels = c("maternal", "paternal")))
expected <- matrix(c(505L, 68L, 4L, 0L, 78L, 49L, 68L, 8L, 0L, 2L), ncol = 2,
                   dimnames = list(type_levels, c("maternal", "paternal")))
stopifnot(
  nrow(check) == 782L,
  identical(check$NAME, selected_hg19$NAME),
  all(vapply(copied_cols, function(cn) identical(check[[cn]], selected_hg19[[cn]]), logical(1))),
  all(as.matrix(unclass(counts)) == expected)
)
print(counts)
cat("hg38 selected:", nrow(check), "probes across", length(unique(check$region)), "regions\n")

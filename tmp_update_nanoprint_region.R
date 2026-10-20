panels <- readRDS("inst/extdata/probesets_hg38.rds")
panel <- panels[["NanoImprint"]]
rosenski <- panels[["Rosenski"]]

rosenski_idx <- match(panel$NAME, rosenski$NAME)
panel$ORIGIN <- rosenski$ORIGIN[rosenski_idx]
stopifnot(sum(!is.na(panel$ORIGIN)) == 315L)

# ORIGIN records the methylated parental allele. MAGEL2 is paternally expressed
# but its TSS-DMR is maternally methylated (Rosenski MAGEL2:TSS-DMR).
gene_origin <- c(
  MAGEL2 = "maternal",
  GNAS = "maternal"
)
missing_origin <- is.na(panel$ORIGIN)
panel$ORIGIN[missing_origin] <- unname(gene_origin[panel$Closest_TSS_gene_name[missing_origin]])
stopifnot(!anyNA(panel$ORIGIN))

# NanoImprint ROI files from github.com/carolinehey/NanoImprint (main, commit
# e7309833715ebc905ac015dc92193762d390811a). The hg38 and T2T-CHM13v2.0 files
# list the same 15 DMRs in the same row order and carry no names; names follow
# the paper's Figure 1. The MEG3/DLK1:IG-DMR row is not in Figure 1 and is named
# from its location.
bed_cols <- c("CHR", "start", "end")
regions_hg38 <- read.table("tmp_ICR_sources/NanoImprint_2024/regions_hg38.bed", sep = "\t", col.names = bed_cols)
regions_t2t <- read.table("tmp_ICR_sources/NanoImprint_2024/regions_T2T.bed", sep = "\t", col.names = bed_cols)
dmr_names <- c(
  "PLAGL1:alt-TSS-DMR", "GRB10:alt-TSS-DMR", "MEST:alt-TSS-DMR", "H19/IGF2:IG-DMR",
  "KCNQ1OT1:TSS-DMR", "MEG3/DLK1:IG-DMR", "MEG3:TSS-DMR", "MEG8:Int2-DMR",
  "MAGEL2:TSS-DMR", "SNURF:TSS-DMR", "PEG3:TSS-DMR", "GNAS-NESP:TSS-DMR",
  "GNAS-AS1:TSS-DMR", "GNASXL:Ex1-DMR", "GNAS A/B:TSS-DMR"
)
stopifnot(
  nrow(regions_hg38) == 15L,
  nrow(regions_t2t) == 15L,
  identical(regions_hg38$CHR, regions_t2t$CHR)
)
regions <- data.frame(
  ICR_name = dmr_names,
  region = paste0(regions_hg38$CHR, ":", regions_hg38$start, "-", regions_hg38$end),
  region_T2T = paste0(regions_t2t$CHR, ":", regions_t2t$start, "-", regions_t2t$end)
)

# Assign each probe to the single hg38 ROI containing its hg38 position.
hit <- vapply(seq_len(nrow(panel)), function(i) {
  w <- which(regions_hg38$CHR == panel$CHR[i] &
               panel$MAPINFO[i] >= regions_hg38$start &
               panel$MAPINFO[i] <= regions_hg38$end)
  if (length(w) == 1L) w else NA_integer_
}, integer(1))
stopifnot(!anyNA(hit))

panel$region <- regions$region[hit]
panel$region_T2T <- regions$region_T2T[hit]
panel$ICR_name <- regions$ICR_name[hit]
panels[["NanoImprint"]] <- panel
saveRDS(panels, "inst/extdata/probesets_hg38.rds", version = 3)

cat("Updated", nrow(panel), "NanoImprint probes across", length(unique(panel$region)), "of", nrow(regions), "ROIs\n")
print(table(factor(panel$ICR_name, levels = dmr_names)))
check <- readRDS("inst/extdata/probesets_hg38.rds")[["NanoImprint"]]
stopifnot(
  nrow(check) == 325L,
  all(grepl("^chr[0-9XY]+:[0-9]+-[0-9]+$", check$region)),
  all(grepl("^chr[0-9XY]+:[0-9]+-[0-9]+$", check$region_T2T)),
  !anyNA(check$ICR_name)
)
stopifnot(identical(as.integer(table(check$ORIGIN)), c(228L, 97L)))
cat("Origin counts:\n")
print(table(check$ORIGIN, useNA = "ifany"))
cat("Gene-inferred probes:", sum(missing_origin), "\n")

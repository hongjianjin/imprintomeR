suppressPackageStartupMessages({
  library(GenomicRanges)
  library(rtracklayer)
})

hg19_path <- file.path("inst", "extdata", "probesets_hg19.rds")
hg38_path <- file.path("inst", "extdata", "probesets_hg38.rds")
chain_gz <- file.path("tmp_ICR_sources", "hg38ToHg19.over.chain.gz")
chain_path <- file.path(tempdir(), "hg38ToHg19.over.chain")

panels19 <- readRDS(hg19_path)
panels38 <- readRDS(hg38_path)
panel19 <- panels19[["NanoImprint"]]
panel38 <- panels38[["NanoImprint"]]

stopifnot(
  all(c("NAME", "CHR", "MAPINFO") %in% names(panel19)),
  all(c("NAME", "CHR", "MAPINFO") %in% names(panel38)),
  !anyDuplicated(panel19$NAME),
  !anyDuplicated(panel38$NAME),
  setequal(panel19$NAME, panel38$NAME)
)

writeLines(readLines(gzfile(chain_gz)), chain_path)
chain <- import.chain(chain_path)
query <- GRanges(
  seqnames = panel38$CHR,
  ranges = IRanges(start = panel38$MAPINFO, end = panel38$MAPINFO),
  probe_name = panel38$NAME
)
lifted <- liftOver(query, chain)
mapping_counts <- elementNROWS(lifted)
stopifnot(all(mapping_counts == 1L))

lifted_flat <- unlist(lifted, use.names = FALSE)
lifted_names <- rep(panel38$NAME, mapping_counts)
stopifnot(identical(lifted_names, panel38$NAME))

lifted_idx <- match(panel19$NAME, lifted_names)
panel19$CHR <- as.character(seqnames(lifted_flat)[lifted_idx])
panel19$MAPINFO <- as.integer(start(lifted_flat)[lifted_idx])
panels19[["NanoImprint"]] <- panel19
saveRDS(panels19, hg19_path, version = 3)

cat("Lifted", nrow(panel19), "NanoImprint probes from hg38 to hg19\n")
cat("Unique mappings:", sum(mapping_counts == 1L), "\n")
cat("hg19 chromosomes:", paste(sort(unique(panel19$CHR)), collapse = ", "), "\n")
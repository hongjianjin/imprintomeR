# Builds the example data in inst/extdata/ from GEO series GSE52576 (Court et al., Genome Res
# 2014; Illumina 450K, 28 samples):
#   GSE52576_selected_beta.tsv  beta values (as deposited in GEO) of the probes of the bundled
#                               "selected" ICR panel, probes x samples, first column TargetID
#   GSE52576_meta.tsv           sample metadata from the GEO series matrix
#
#   Rscript data-raw/GSE52576_example.R [GSE52576_series_matrix.txt.gz]
# Run from the package root. Without an argument the series matrix is downloaded from GEO
# (about 59 MB) with GEOquery; with one, that previously downloaded file is read.

args <- commandArgs(trailingOnly = TRUE)
suppressMessages(library(GEOquery))
eset <- if (length(args)) {
  getGEO(filename = args[1], getGPL = FALSE)
} else {
  getGEO("GSE52576", GSEMatrix = TRUE, getGPL = FALSE)[[1]]
}
stopifnot(ncol(eset) == 28)

panel <- readRDS("inst/extdata/probesets_hg38.rds")[["selected"]]
probes <- sort(intersect(unique(panel$NAME), rownames(eset)))
beta <- Biobase::exprs(eset)[probes, , drop = FALSE]

p <- Biobase::pData(eset)
meta <- data.frame(
  Sample_Name  = p$geo_accession,
  Sample_Group = p$source_name_ch1,
  title        = p$title,
  health_state = p$`health state:ch1`,
  gender       = p$`gender:ch1`,
  stringsAsFactors = FALSE
)
stopifnot(identical(meta$Sample_Name, colnames(beta)))

write.table(data.frame(TargetID = rownames(beta), beta, check.names = FALSE),
            "inst/extdata/GSE52576_selected_beta.tsv", sep = "\t", quote = FALSE, row.names = FALSE)
write.table(meta, "inst/extdata/GSE52576_meta.tsv", sep = "\t", quote = FALSE, row.names = FALSE)
cat("selected panel:", length(unique(panel$NAME)), "probes; on the 450K data:", length(probes),
    "; samples:", ncol(beta), "; missing values:", sum(is.na(beta)), "\n")

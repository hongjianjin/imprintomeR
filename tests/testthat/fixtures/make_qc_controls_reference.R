# Builds tests/testthat/fixtures/qc_controls_reference.rds: inputs of imprintomeR's native
# control-probe / SNP QC functions (read from IDATs through minfi) together with the outputs of
# ewastools 1.8.2 on the same IDATs, so the tests can check that both agree without ewastools.
#
# Needs ewastools 1.8.2 (remotes::install_github("hhhh5/ewastools@v1.8.2")), minfi with the 450K
# and EPIC manifests, and the GSE167059 IDATs from GEO (EPICv1, 158 samples):
#   Rscript tests/testthat/fixtures/make_qc_controls_reference.R <GSE167059 IDAT folder>
# Run from the package root. The 450K sample is the example IDAT shipped with ewastools.

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1, dir.exists(args[1]))
suppressMessages({
  library(minfi)
  devtools::load_all(".", quiet = TRUE)
})
stopifnot(packageVersion("ewastools") == "1.8.2")

reference <- function(base, n_keep = NULL, shuffle_seed = 1) {
  ew <- ewastools::read_idats(base, quiet = TRUE)
  rg <- suppressWarnings(read.metharray(base, force = TRUE))
  pinfo <- imprintomeR:::.qc_minfi_pinfo(rg)
  ad <- c(pinfo("Control")$Address, pinfo("SnpI")$AddressA, pinfo("SnpI")$AddressB, pinfo("SnpII")$AddressA)
  nb <- imprintomeR:::.qc_nbeads(base, ad)
  raw <- imprintomeR:::.qc_control_intensities(rg, nb, pinfo)
  snp <- imprintomeR:::.qc_snp_beta(rg, nb, pinfo)

  # ewastools SNP beta values, in the native row order (matched by probe name)
  bew <- pmax(ew$M, 1) / (pmax(ew$U, 1) + pmax(ew$M, 1))
  rs <- ew$manifest[ew$manifest$probe_type == "rs", ]
  snp_ew <- bew[rs$index[match(rownames(snp), rs$probe_id)], , drop = FALSE]
  dimnames(snp_ew) <- dimnames(snp)
  gt <- ewastools::call_genotypes(snp_ew, learn = FALSE)

  sid <- basename(base)
  set.seed(shuffle_seed)
  labels <- list(own = sid, shuffled = sample(rep(paste0("D", 1:5), length.out = length(sid))))
  conflicts <- lapply(labels, function(dn) {
    x <- ewastools::check_snp_agreement(gt, dn, sid)
    if (is.null(x)) NULL else as.data.frame(data.table::rbindlist(x, idcol = "group"))
  })
  list(platform = ew$platform, samples = sid, raw = raw, snp = snp,
       ewastools = list(control_metrics = ewastools::control_metrics(ew), snp = snp_ew,
                        outliers = gt$outliers, gamma = gt$gamma,
                        donors = ewastools::enumerate_sample_donors(gt),
                        labels = labels, conflicts = conflicts))
}

# EPICv1: the samples in sample-swap conflicts (series' own labels), then those with a SNP probe
# read from zero beads, then the first samples of the series, 30 in all. (Most samples have a
# negative-control probe read from zero beads.)
all_base <- sort(unique(sub("_Grn\\.idat(\\.gz)?$", "", list.files(args[1], "_Grn\\.idat", full.names = TRUE))))
full <- reference(all_base)
conf <- unique(unlist(full$ewastools$conflicts$own[, c("sample1", "sample2")]))
zero_snp <- colnames(full$snp)[colSums(is.na(full$snp)) > 0]
keep <- unique(c(conf, zero_snp, basename(all_base)))[1:30]
epic <- reference(all_base[basename(all_base) %in% keep])

f450 <- file.path(system.file("data", package = "ewastools"), "5640269011_R01C01")
ref <- list(created = "ewastools 1.8.2; minfi manifests; GEO GSE167059 (EPICv1) and the ewastools 450K example IDAT",
            epic = epic, k450 = reference(f450))
saveRDS(ref, "tests/testthat/fixtures/qc_controls_reference.rds", compress = "xz")
cat("EPICv1 samples:", length(epic$samples), " in conflicts (full series):", sum(epic$samples %in% conf),
    " with a zero-bead SNP probe:", sum(epic$samples %in% zero_snp),
    " conflict pairs (own labels):", NROW(epic$ewastools$conflicts$own), "\n")

#!/usr/bin/env Rscript
# Supplementary_Code.R: companion script to the Supplementary Workflow Examples of
# "imprintomeR: an R package for measuring genomic imprinting disturbance from
# Illumina methylation arrays" (Bioinformatics, Application Note).
#
# It runs each workflow example of the Supplementary on public data, so every step can
# be reproduced without local files:
#   Part 1  IDAT QC to MethQcSet, and MethQcSet to ImprintomeSet: 6 Illumina 450K
#           samples (3 donors, normal and cancer) from the Bioconductor package minfiData.
#   Part 2  Imprinting analysis, visualizations and export: the bundled GEO GSE52576
#           example (Court et al., Genome Res 2014; 450K, 28 samples), beta values of
#           the 782 probes of the 'selected' panel.
#
# Usage:   Rscript Supplementary_Code.R [output_folder]    (default: supplementary_output)
# Needs:   imprintomeR (>= 1.6.0), minfiData (example IDATs) and gridBase (circular heatmap):
#            if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")
#            BiocManager::install(c("remotes", "hongjianjin/imprintomeR", "minfiData", "gridBase"))
# Runtime: about 3 minutes on a laptop. All outputs are written to output_folder.
# CI:      run on Linux, macOS and Windows by the install-check workflow of the repository
#          (https://github.com/hongjianjin/imprintomeR).

suppressPackageStartupMessages(library(imprintomeR))
missing <- c("minfiData", "gridBase")[!vapply(c("minfiData", "gridBase"), requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Please install ", paste(missing, collapse = " and "), ": BiocManager::install(c(\"",
       paste(missing, collapse = "\", \""), "\"))")
}

args <- commandArgs(trailingOnly = TRUE)
outdir <- if (length(args)) args[1] else "supplementary_output"
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
message("imprintomeR ", packageVersion("imprintomeR"), "; output folder: ", normalizePath(outdir))

probesets <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))

# =====================================================================================
# Part 1. IDAT QC to MethQcSet (Supplementary: "IDAT QC to MethQcSet")
# =====================================================================================
# For your own data, the sample sheet needs Sample_Name and Basename (the IDAT path
# without _Grn.idat/_Red.idat); Sample_Group and Donor_ID are optional:
#   meta <- LoadMeta("metadata.tsv")
#   meta <- check_platform(meta)                     # adds Platform (450K, EPIC, EPICv2)
#   meta_epic <- meta[meta$Platform == "EPIC", ]     # QC one platform at a time
#   qcset <- runMethQC(meta_epic, platform = "EPIC", outdir = "qc_results/epic", prefix = "epic")
# Here: the minfiData IDATs (an Illumina sample sheet, read with minfi).
meta <- minfi::read.metharray.sheet(system.file("extdata", package = "minfiData"))  # adds Basename
meta$Donor_ID <- meta$person              # known donors, checked against the SNP-probe donors
meta <- check_platform(meta)              # reads one IDAT per sample
stopifnot(all(meta$Platform == "450K"))

qc_dir <- file.path(outdir, "qc_results")
qcset <- runMethQC(
  meta,
  platform = "450K",
  outdir = qc_dir,
  normalization = "noob",   # default; or "noob_swan", "raw"
  prefix = "minfiData"
)
export(qcset, outdir = qc_dir, format = c("xlsx", "rds", "txt"), prefix = "minfiData")
print(qc_tables(qcset)$QC_matrix[, c("Sample_Name", "predictedSex", "predictedDonorID", "Final.QC")])

# =====================================================================================
# MethQcSet to ImprintomeSet (Supplementary: "MethQcSet to ImprintomeSet")
# =====================================================================================
qcset <- subsetMethQC(qcset, final_qc = "PASS")           # keep samples that passed QC
if (qcset@platform == "EPICv2") {                          # not run for these 450K data
  qcset <- aggregate_probes(qcset)
  qc_tables(qcset)$Aggregation_report   # replicate groups collapsed, malformed IDs
}
x_idat <- as.ImprintomeSet(
  qcset,
  probeset = probesets[["selected"]],
  genome = "hg38"
)
x_idat <- runImprintome(x_idat, probeset = "selected")
print(results(x_idat)[["AnalyzeImprintStatus.selected"]][, c("Sample_Name", "Sample_Group", "IDS", "Angle", "Mechanism", "Status")])

# =====================================================================================
# Part 2. Run imprinting analysis (Supplementary: "Run imprinting analysis")
# =====================================================================================
# The bundled GSE52576 example: hydatidiform moles (androgenetic), parthenogenetic
# cells, leukocytes with paternal or maternal uniparental disomy, sperm, embryonic stem
# cells and somatic tissues and placentas. For your own beta matrix (QC done elsewhere):
#   x <- ImprintomeSet(beta = beta, meta = meta, probeset = probesets[["selected"]],
#                      genome = "hg38", assay = "EPICv1")
beta <- imprintome_example("beta")   # 782 probes x 28 samples
meta <- imprintome_example("meta")
x <- ImprintomeSet(
  beta = beta,
  meta = meta,
  probeset = probesets[["selected"]],
  genome = "hg38",
  assay = "450K"
)
x <- runImprintome(
  x,
  probeset = "selected",
  ids_cutoff = 0.2
)
status <- results(x)[["AnalyzeImprintStatus.selected"]]
head(status)
print(table(Sample_Group = status$Sample_Group, Mechanism = status$Mechanism))

# The core selected panel is scored on gametic ICRs by default (status above).
# All probes, as in the submitted version, or secondary DMRs separately:
x <- runImprintome(x, probeset = "selected", dmr_type = "all")
x <- runImprintome(x, probeset = "selected", dmr_type = "secondary")
secondary <- results(x)[["AnalyzeImprintStatus.selected.secondary"]]
head(secondary)

# Controls. This cohort has no dedicated control group; for illustration, the somatic
# tissues and term placentas (9 samples) serve as the in-cohort reference.
controls <- c("Adult Brain", "Fetal Brain", "Liver", "Muscle", "Pancreas", "Term placenta- fetal side")

# Optional: centre on tissue-matched controls and balance Infinium I/II probes
x <- runImprintome(x, probeset = "selected", reference_group = controls,
                   infinium_type = "balanced")

# Cohort without controls: use an external reference profile, built here from the
# same 9 samples and saved for reuse
ref <- BuildReferenceProfile(beta[, meta$Sample_Name[meta$Sample_Group %in% controls]])
saveRDS(ref, file.path(outdir, "reference.rds"))
x <- runImprintome(x, probeset = "chr11p15", reference_beta = ref,
                   result_name = "AnalyzeImprintStatus.chr11p15.ref-external")

# Per-ICR deviations and multi-locus summary (default thresholds assume controls; with
# 9 controls, fewer than 10, imprintomeR warns that the per-ICR z-scores are unstable)
x <- runImprintome(x, probeset = "selected", reference_group = controls, icr = TRUE)
icr <- results(x)[["ICRStatus.selected"]]
head(results(x)[["ICRSummary.selected"]])   # altered ICRs and MLID flag per sample
p_icr <- PlotICRHeatmap(icr)
ggplot2::ggsave(file.path(outdir, "icr_heatmap.pdf"), p_icr, width = 10, height = 8)

# Bootstrap intervals and origin permutation; calibrate the cutoff on controls.
# Whole ICRs are permuted by default (permute = "icr"), which needs at least two ICRs per
# parental class: use the selected panel (48 ICRs), or permute = "probe" for chr11p15
# (one ICR per class, IC1 and IC2).
x <- runImprintome(x, probeset = "selected", reference_group = controls,
                   n_boot = 2000, n_perm = 2000, seed = 1,
                   result_name = "AnalyzeImprintStatus.selected.ref-controls.boot")
res <- results(x)[["AnalyzeImprintStatus.selected.ref-controls.boot"]]
print(res[, c("Sample_Name", "Sample_Group", "IDS", "IDS_lower", "IDS_upper",
              "Mechanism", "Mechanism_support", "Status_interval", "origin_perm_p")])
res <- CalibrateIDS(res, controls = controls, method = "quantile", probs = 0.99)
attr(res, "calibration")   # cutoff from the controls' IDS distribution
names(results(x))          # result names record non-default settings

# =====================================================================================
# Run visualizations (Supplementary: "Run visualizations")
# =====================================================================================
plot_dir <- file.path(outdir, "plots")
dir.create(plot_dir, showWarnings = FALSE)
x <- runImprintomeVisualizations(
  x,
  plot_types = "default",
  probeset = "selected",
  sample_id = colnames(beta(x))[1],
  prefix = "example",
  outdir = plot_dir,
  store_plots = TRUE,
  save_plots = TRUE
)
names(plots(x))

# =====================================================================================
# Request individual plots explicitly (Supplementary: "Request individual plots explicitly")
# =====================================================================================
x <- runImprintomeVisualizations(x, plot_types = "polar", probeset = "selected")
x <- runImprintomeVisualizations(x, plot_types = "beeswarm_origin", probeset = "selected")

# The circular heatmap has room for a few sample groups only, so it is drawn here for
# three of the 11 groups; large cohorts: save it as a raster PNG
keep <- meta$Sample_Group %in% c("Hydatidiform mole", "parthenogenetic activated oocytes",
                                 "Term placenta- fetal side")
x_sub <- ImprintomeSet(beta = beta[, keep], meta = meta[keep, ],
                       probeset = probesets[["selected"]], genome = "hg38", assay = "450K")
x_sub <- runImprintomeVisualizations(x_sub, plot_types = "circular_heatmap", probeset = "selected")
plot(x_sub, plot_type = "circular_heatmap", probeset = "selected",
     outFile = file.path(plot_dir, "circular.png"))

# =====================================================================================
# Export analysis results and plots (Supplementary: "Export analysis results and plots")
# =====================================================================================
manifest <- export(
  x,
  outdir = file.path(outdir, "imprintome_output"),
  prefix = "example",
  save_plots = TRUE,
  plot_device = "pdf",
  overwrite = TRUE
)
manifest

# Session information (library paths removed)
local({ si <- sessionInfo(); si$BLAS <- basename(si$BLAS); si$LAPACK <- basename(si$LAPACK); print(si) })
message("Done. Outputs are in ", normalizePath(outdir))

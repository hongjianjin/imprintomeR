# Bundled GSE52576 example and the minfiData IDAT example used in the README Quick start.

test_that("imprintome_example() returns the GSE52576 beta matrix and metadata", {
  beta <- imprintome_example("beta")
  meta <- imprintome_example("meta")
  expect_true(is.matrix(beta) && is.numeric(beta))
  expect_identical(dim(beta), c(782L, 28L))
  expect_identical(colnames(beta), meta$Sample_Name)
  panel <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))[["selected"]]
  expect_setequal(rownames(beta), unique(panel$NAME))
  expect_true(all(c("Sample_Name", "Sample_Group", "title", "health_state", "gender") %in% colnames(meta)))
  expect_true(file.exists(imprintome_example("beta", path = TRUE)))
  expect_error(imprintome_example("idat"))
})

test_that("the GSE52576 example gives the expected parent-of-origin calls", {
  beta <- imprintome_example("beta")
  meta <- imprintome_example("meta")
  panels <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))
  x <- ImprintomeSet(beta = beta, meta = meta, probeset = panels[["selected"]], genome = "hg38", assay = "450K")
  x <- suppressMessages(runImprintome(x, probeset = "selected"))
  res <- results(x)[["AnalyzeImprintStatus.selected"]]
  grp <- meta$Sample_Group[match(res$Sample_Name, meta$Sample_Name)]
  expect_true(all(res$Mechanism[grp == "Hydatidiform mole"] == "Pat-Gain+Mat-Loss"))
  expect_true(all(res$Mechanism[grp == "parthenogenetic activated oocytes"] == "Mat-Gain+Pat-Loss"))
  expect_true(all(res$Status[grp %in% c("Term placenta- fetal side", "Liver", "Muscle", "Pancreas")] == "Normal"))
})

test_that("runMethQC() on minfiData: predicted sex, donors and no swaps when Sample_Name is not the IDAT name", {
  skip_if_not_installed("minfiData")
  skip_on_cran()
  meta <- suppressMessages(minfi::read.metharray.sheet(system.file("extdata", package = "minfiData")))
  meta$Donor_ID <- meta$person
  expect_identical(unique(suppressMessages(check_platform(meta))$Platform), "450K")   # minfi says "450k"
  expect_false(any(meta$Sample_Name == basename(meta$Basename)))
  search_before <- search()
  qcset <- suppressMessages(runMethQC(meta, platform = "450K", save_qc_report = FALSE))
  # minfi attaches packages (SummarizedExperiment, GenomeInfoDb) that would mask assay() and genome()
  expect_identical(search(), search_before)
  qm <- qc_tables(qcset)$QC_matrix
  qm <- qm[match(meta$Sample_Name, qm$Sample_Name), ]
  expect_identical(as.character(qm$predictedSex), meta$sex)
  # each person's normal and cancer samples share a predicted donor, and only those
  part <- function(v) as.integer(factor(v, unique(v)))
  expect_identical(part(qm$predictedDonorID), part(meta$person))
  expect_identical(nrow(qc_tables(qcset)$contamination), 0L)
  expect_true(all(qc_tables(qcset)$ctrl_metrics$CtrlMetrics.QC == "PASS"))
})

test_that("ImprintomeSet() rejects percentages and M-values", {
  beta <- imprintome_example("beta")
  meta <- imprintome_example("meta")
  panel <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))[["selected"]]
  mk <- function(b) ImprintomeSet(beta = b, meta = meta, probeset = panel, genome = "hg38", assay = "450K")
  expect_error(mk(beta * 100), "between 0 and 1")
  expect_error(mk(log2(beta / (1 - beta))), "between 0 and 1")
  expect_s4_class(mk(beta), "ImprintomeSet")
})

test_that("probe-level plots work on an ImprintomeSet whose meta has default row names", {
  beta <- imprintome_example("beta")
  meta <- imprintome_example("meta")
  expect_identical(rownames(meta), as.character(seq_len(nrow(meta))))
  panel <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))[["selected"]]
  x <- ImprintomeSet(beta = beta, meta = meta, probeset = panel, genome = "hg38", assay = "450K")
  grDevices::pdf(NULL); on.exit(grDevices::dev.off(), add = TRUE)
  for (pt in c("violin", "beeswarm", "beeswarm_origin")) {
    p <- suppressWarnings(suppressMessages(utils::capture.output(
      res <- plot(x, plot_type = pt, probeset = "selected"))))
    expect_s3_class(res, "ggplot")
  }
  utils::capture.output(p <- suppressWarnings(
    BetaBeePlot_single_chr(beta = beta, meta = meta, chr = "chr11", probeset = "selected")))
  expect_false(is.null(p))
})

test_that("Excel export keeps columns whose names differ only by case", {
  d <- data.frame(status = "a", Status = "b", x = 1, check.names = FALSE)
  expect_message(imprintomeR:::.unique_names_ignore_case(d), "Status -> Status_2")
  out <- suppressMessages(imprintomeR:::.unique_names_ignore_case(d))
  expect_identical(colnames(out), c("status", "Status_2", "x"))
  f <- tempfile(fileext = ".xlsx")
  utils::capture.output(SaveTableStyle(d, file = f, sheetName = "s"))
  expect_true(file.exists(f))
})

test_that("export() writes the per-ICR heatmap, whose stored size is a named vector", {
  beta <- imprintome_example("beta")
  meta <- imprintome_example("meta")
  panel <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))[["selected"]]
  x <- ImprintomeSet(beta = beta, meta = meta, probeset = panel, genome = "hg38", assay = "450K")
  x <- suppressMessages(runImprintome(x, probeset = "selected", icr = TRUE))
  utils::capture.output(x <- suppressWarnings(suppressMessages(runImprintomeVisualizations(
    x, plot_types = "icr_heatmap", probeset = "selected", store_plots = TRUE, save_plots = FALSE))))
  expect_named(attr(plots(x)[["icr_heatmap.selected"]], "imprintomeR_figure_size"), c("width", "height"))
  out <- tempfile()
  utils::capture.output(suppressMessages(export(x, outdir = out, prefix = "t", save_plots = TRUE, overwrite = TRUE)))
  expect_true(file.exists(file.path(out, "t_plot_icr_heatmap.selected.pdf")))
})

test_that(".open_png() writes a PNG (ragg when installed)", {
  f <- tempfile(fileext = ".png")
  imprintomeR:::.open_png(f, width = 2, height = 2, res = 72)
  graphics::plot(1)
  grDevices::dev.off()
  expect_true(file.exists(f) && file.size(f) > 0)
})

test_that("runImprintome() falls back to probe permutation on chr11p15 unless permute is chosen", {
  beta <- imprintome_example("beta")
  meta <- imprintome_example("meta")
  panel <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))[["selected"]]
  x <- ImprintomeSet(beta = beta, meta = meta, probeset = panel, genome = "hg38", assay = "450K")
  expect_warning(
    suppressMessages(runImprintome(x, probeset = "chr11p15", n_perm = 20, seed = 1)),
    "falls back"
  )
  expect_error(
    suppressMessages(runImprintome(x, probeset = "chr11p15", n_perm = 20, permute = "icr", seed = 1)),
    "at least two annotated ICRs"
  )
})

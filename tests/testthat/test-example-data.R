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
  expect_false(any(meta$Sample_Name == basename(meta$Basename)))
  qcset <- suppressMessages(runMethQC(meta, platform = "450K", save_qc_report = FALSE))
  qm <- qc_tables(qcset)$QC_matrix
  qm <- qm[match(meta$Sample_Name, qm$Sample_Name), ]
  expect_identical(as.character(qm$predictedSex), meta$sex)
  # each person's normal and cancer samples share a predicted donor, and only those
  part <- function(v) as.integer(factor(v, unique(v)))
  expect_identical(part(qm$predictedDonorID), part(meta$person))
  expect_identical(nrow(qc_tables(qcset)$contamination), 0L)
  expect_true(all(qc_tables(qcset)$ctrl_metrics$CtrlMetrics.QC == "PASS"))
})

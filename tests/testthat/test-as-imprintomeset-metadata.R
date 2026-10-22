testthat::local_edition(1)

# Metadata failures in as.ImprintomeSet() (Reviewer 1, Question 9). MethQcSet() already
# rejects missing or duplicated Sample_Name, so these tests corrupt the meta slot of a
# valid object directly, as a hand-edited or legacy object would be.

.make_qcset <- function(n = 3) {
  probes <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))[["selected"]]$NAME[1:10]
  ids <- paste0("S", seq_len(n))
  meta <- data.frame(Sample_Name = ids, Sample_Group = rep(c("case", "control"), length.out = n),
                     stringsAsFactors = FALSE)
  beta <- matrix(seq(0.1, 0.9, length.out = 10 * n), nrow = 10, dimnames = list(probes, ids))
  MethQcSet(meta = meta, platform = "EPIC", beta = beta)
}

test_that("as.ImprintomeSet() rejects metadata without Sample_Name", {
  qcset <- .make_qcset()
  qcset@meta <- data.frame(ID = qcset@meta$Sample_Name, Sample_Group = qcset@meta$Sample_Group)
  expect_error(suppressMessages(as.ImprintomeSet(qcset)), "Sample_Name")
})

test_that("as.ImprintomeSet() rejects duplicated Sample_Name", {
  qcset <- .make_qcset()
  qcset@meta$Sample_Name[2] <- qcset@meta$Sample_Name[1]
  expect_error(suppressMessages(as.ImprintomeSet(qcset)), "must be unique")
})

test_that("as.ImprintomeSet() rejects missing Sample_Name values and metadata that matches no beta column", {
  qcset <- .make_qcset()
  qcset@meta$Sample_Name <- paste0("X", seq_len(nrow(qcset@meta)))
  expect_error(suppressMessages(as.ImprintomeSet(qcset)), "no overlapping samples")
})

test_that("as.ImprintomeSet() renames legacy SAMPLE_NAME and creates a missing Sample_Group", {
  qcset <- .make_qcset()
  qcset@meta <- data.frame(SAMPLE_NAME = qcset@meta$Sample_Name, stringsAsFactors = FALSE)
  expect_message(x <- as.ImprintomeSet(qcset), "Sample_Group column not found")
  expect_equal(x@meta$Sample_Name, colnames(qcset@beta))
  expect_equal(x@meta$Sample_Group, x@meta$Sample_Name)
})

test_that("as.ImprintomeSet() warns about failed QC samples and is silent otherwise", {
  qcset <- .make_qcset()
  qcset@qc_tables[["QC_matrix"]] <- data.frame(Sample_Name = qcset@meta$Sample_Name,
                                               Final.QC = c("PASS", "FAIL", "FAIL"), stringsAsFactors = FALSE)
  expect_warning(x <- as.ImprintomeSet(qcset), "2 samples with Final.QC='FAIL'")
  expect_equal(ncol(x@beta), 3L)   # failed samples are kept; filtering is left to the user

  qcset@qc_tables[["QC_matrix"]]$Final.QC <- c("PASS", "PASS", NA)
  expect_warning(as.ImprintomeSet(qcset), NA)
})

test_that("as.ImprintomeSet() requires an aggregated EPICv2 object and a platform", {
  qcset <- .make_qcset()
  qcset@platform <- "EPICv2"
  expect_error(as.ImprintomeSet(qcset), "must be aggregated")
  qcset@platform <- ""
  expect_error(as.ImprintomeSet(qcset), "platform is empty")
})

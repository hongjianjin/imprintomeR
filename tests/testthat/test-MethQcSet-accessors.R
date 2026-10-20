library(testthat)

# Test MethQcSet accessors
test_that("MethQcSet accessors work correctly", {
  meta <- data.frame(Sample_Name = c("S1", "S2"), stringsAsFactors = FALSE)
  platform <- "EPIC"
  beta <- matrix(runif(100), nrow = 10, ncol = 2)
  rownames(beta) <- paste0("cg", sprintf("%08d", 1:10))
  colnames(beta) <- meta$Sample_Name

  obj <- MethQcSet(meta = meta, platform = platform, beta = beta)

  # Test getters
  expect_equal(nrow(meta(obj)), 2)
  expect_equal(platform(obj), "EPIC")
  expect_equal(ncol(beta(obj)), 2)

  # Test setters
  new_platform <- "EPICv2"
  platform(obj) <- new_platform
  expect_equal(platform(obj), new_platform)

  new_meta <- data.frame(Sample_Name = c("S1", "S2"), Group = c("A", "B"), stringsAsFactors = FALSE)
  meta(obj) <- new_meta
  expect_equal(ncol(meta(obj)), 2)
  expect_true("Group" %in% colnames(meta(obj)))
})

test_that("MethQcSet qc_tables accessor works", {
  meta <- data.frame(Sample_Name = c("S1", "S2"), stringsAsFactors = FALSE)
  platform <- "EPIC"
  beta <- matrix(runif(100), nrow = 10, ncol = 2)
  rownames(beta) <- paste0("cg", sprintf("%08d", 1:10))
  colnames(beta) <- meta$Sample_Name

  obj <- MethQcSet(meta = meta, platform = platform, beta = beta)

  # Add QC tables
  qc_matrix <- data.frame(Sample_Name = c("S1", "S2"), Final.QC = c("PASS", "FAIL"))
  qc_tables(obj) <- list(QC_matrix = qc_matrix)

  expect_length(qc_tables(obj), 1)
  expect_true("QC_matrix" %in% names(qc_tables(obj)))
})

test_that("MethQcSet aggregation_status accessor works", {
  meta <- data.frame(Sample_Name = c("S1", "S2"), stringsAsFactors = FALSE)
  platform <- "EPICv2"
  beta <- matrix(runif(100), nrow = 10, ncol = 2)
  rownames(beta) <- paste0("cg", sprintf("%08d", 1:10))
  colnames(beta) <- meta$Sample_Name

  obj <- MethQcSet(meta = meta, platform = platform, beta = beta, aggregation_status = "none")

  expect_equal(aggregation_status(obj), "none")

  aggregation_status(obj) <- "epicv2_aggregated"
  expect_equal(aggregation_status(obj), "epicv2_aggregated")
})

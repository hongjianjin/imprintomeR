library(testthat)

# Test MethQcSet class definition and validation
test_that("MethQcSet class can be instantiated", {
  # Create minimal test data
  meta <- data.frame(Sample_Name = c("S1", "S2"), stringsAsFactors = FALSE)
  platform <- "EPIC"
  beta <- matrix(runif(100), nrow = 10, ncol = 2)
  rownames(beta) <- paste0("cg", sprintf("%08d", 1:10))
  colnames(beta) <- meta$Sample_Name

  # Create object
  obj <- MethQcSet(meta = meta, platform = platform, beta = beta)

  expect_s4_class(obj, "MethQcSet")
  expect_equal(ncol(obj@beta), 2)
  expect_equal(nrow(obj@beta), 10)
})

test_that("MethQcSet validation catches missing Sample_Name", {
  meta <- data.frame(X = c("S1", "S2"), stringsAsFactors = FALSE)
  platform <- "EPIC"
  beta <- matrix(runif(100), nrow = 10, ncol = 2)
  rownames(beta) <- paste0("cg", sprintf("%08d", 1:10))
  colnames(beta) <- c("S1", "S2")

  expect_error(
    MethQcSet(meta = meta, platform = platform, beta = beta),
    "Sample_Name"
  )
})


test_that("MethQcSet accepts legacy SAMPLE_NAME metadata", {
  meta <- data.frame(SAMPLE_NAME = c("S1", "S2"), stringsAsFactors = FALSE)
  beta <- matrix(runif(20), nrow = 10, ncol = 2)
  rownames(beta) <- paste0("cg", sprintf("%08d", 1:10))
  colnames(beta) <- c("S1", "S2")

  obj <- MethQcSet(meta = meta, platform = "EPIC", beta = beta)

  expect_true("Sample_Name" %in% colnames(meta(obj)))
  expect_false("SAMPLE_NAME" %in% colnames(meta(obj)))
})

test_that("MethQcSet validation catches beta/meta mismatch", {
  meta <- data.frame(Sample_Name = c("S1", "S2"), stringsAsFactors = FALSE)
  platform <- "EPIC"
  beta <- matrix(runif(100), nrow = 10, ncol = 2)
  rownames(beta) <- paste0("cg", sprintf("%08d", 1:10))
  colnames(beta) <- c("S1", "S3")  # Mismatch

  expect_error(
    MethQcSet(meta = meta, platform = platform, beta = beta),
    "beta samples found in meta\\$Sample_Name"
  )
})

test_that("MethQcSet detection_pval alignment is validated", {
  meta <- data.frame(Sample_Name = c("S1", "S2"), stringsAsFactors = FALSE)
  platform <- "EPIC"
  beta <- matrix(runif(100), nrow = 10, ncol = 2)
  rownames(beta) <- paste0("cg", sprintf("%08d", 1:10))
  colnames(beta) <- meta$Sample_Name

  # Wrong dimension detection_pval
  dpval <- matrix(runif(50), nrow = 5, ncol = 2)
  rownames(dpval) <- paste0("cg", sprintf("%08d", 1:5))
  colnames(dpval) <- meta$Sample_Name

  expect_error(
    MethQcSet(meta = meta, platform = platform, beta = beta, detection_pval = dpval),
    "dim|dimension"
  )
})

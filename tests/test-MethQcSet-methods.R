library(testthat)

# Helper function to create test data
.create_test_methqcset <- function(n_samples = 3, n_probes = 50) {
  meta <- data.frame(
    Sample_Name = paste0("S", 1:n_samples),
    Group = rep(c("A", "B"), length.out = n_samples),
    stringsAsFactors = FALSE
  )

  beta <- matrix(runif(n_probes * n_samples, 0, 1), nrow = n_probes, ncol = n_samples)
  rownames(beta) <- paste0("cg", sprintf("%08d", 1:n_probes))
  colnames(beta) <- meta$Sample_Name

  detection_pval <- matrix(runif(n_probes * n_samples, 0, 0.1), nrow = n_probes, ncol = n_samples)
  rownames(detection_pval) <- rownames(beta)
  colnames(detection_pval) <- colnames(beta)

  MethQcSet(meta = meta, platform = "EPIC", beta = beta, detection_pval = detection_pval)
}

# Test computeQC (internal S4 method on MethQcSet)
test_that("computeQC computes QC metrics", {
  obj <- .create_test_methqcset(n_samples = 3, n_probes = 100)

  obj_qc <- computeQC(obj, pcutoff = 0.05)

  expect_true("QC_matrix" %in% names(qc_tables(obj_qc)))

  qc_matrix <- qc_tables(obj_qc)[["QC_matrix"]]
  expect_equal(nrow(qc_matrix), 3)
  expect_true("Sample_Name" %in% colnames(qc_matrix))
  expect_false("SAMPLE_NAME" %in% colnames(qc_matrix))
  expect_true("Final.QC" %in% colnames(qc_matrix))

  cutoffs <- qc_tables(obj_qc)[["cutoffs"]]
  intensity_row <- cutoffs[cutoffs$criteria == "log2MedianIntensity", ]
  expect_equal(intensity_row$cutoff, "reported")
  expect_true(is.na(intensity_row$Final.QC))
  expect_false("icutoff" %in% names(qc_params(obj_qc)))
})

# Test aggregate_probes
test_that("aggregate_probes works for EPICv2", {
  meta <- data.frame(Sample_Name = c("S1", "S2"), stringsAsFactors = FALSE)
  # Create EPICv2-style probes with _TB suffix
  probe_names <- c("cg00000001_TB1", "cg00000001_TB2", "cg00000002_TB1", "cg00000003_TB1")
  beta <- matrix(runif(4 * 2, 0, 1), nrow = 4, ncol = 2)
  rownames(beta) <- probe_names
  colnames(beta) <- meta$Sample_Name

  obj <- MethQcSet(meta = meta, platform = "EPICv2", beta = beta, aggregation_status = "none")

  obj_agg <- aggregate_probes(obj, method = "median")

  # Should have reduced number of probes
  expect_lt(nrow(beta(obj_agg)), nrow(beta(obj)))
  expect_equal(aggregation_status(obj_agg), "epicv2_aggregated")
})

# Test merge
test_that("merge combines two MethQcSet objects", {
  obj1 <- .create_test_methqcset(n_samples = 2, n_probes = 50)
  obj2 <- .create_test_methqcset(n_samples = 2, n_probes = 50)

  # Rename samples in obj2 by creating a new object with different sample names
  new_meta <- meta(obj2)
  new_meta$Sample_Name <- c("S3", "S4")
  new_beta <- beta(obj2)
  colnames(new_beta) <- c("S3", "S4")
  new_dpval <- detection_pval(obj2)
  colnames(new_dpval) <- c("S3", "S4")
  
  obj2_renamed <- MethQcSet(
    meta = new_meta,
    platform = platform(obj2),
    beta = new_beta,
    detection_pval = new_dpval
  )

  merged <- merge(obj1, obj2_renamed, how = "inner")

  expect_equal(ncol(beta(merged)), 4)  # 2 + 2 samples
  expect_equal(nrow(meta(merged)), 4)
})

# Test find_intersection for samples
test_that("find_intersection finds common samples", {
  obj1 <- .create_test_methqcset(n_samples = 3, n_probes = 50)
  obj2 <- .create_test_methqcset(n_samples = 3, n_probes = 50)

  common_samples <- find_intersection(obj1, obj2, by = "samples")

  expect_length(common_samples, 3)
  expect_true(all(common_samples %in% c("S1", "S2", "S3")))
})

# Test find_intersection for probes
test_that("find_intersection finds common probes", {
  meta <- data.frame(Sample_Name = c("S1", "S2"), stringsAsFactors = FALSE)

  # Create two objects with different probes
  probes1 <- paste0("cg", sprintf("%08d", 1:100))
  probes2 <- paste0("cg", sprintf("%08d", 50:150))

  beta1 <- matrix(runif(100 * 2), nrow = 100, ncol = 2)
  rownames(beta1) <- probes1
  colnames(beta1) <- meta$Sample_Name

  beta2 <- matrix(runif(101 * 2), nrow = 101, ncol = 2)
  rownames(beta2) <- probes2
  colnames(beta2) <- meta$Sample_Name

  obj1 <- MethQcSet(meta = meta, platform = "EPIC", beta = beta1)
  obj2 <- MethQcSet(meta = meta, platform = "EPIC", beta = beta2)

  common_probes <- find_intersection(obj1, obj2, by = "probes")

  expect_length(common_probes, 51)  # probes 50-100
  expect_true(all(grepl("cg0000005[0-9]|cg000000[0-9]{2}|cg00000100", common_probes)))
})

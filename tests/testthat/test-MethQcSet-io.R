library(testthat)

# ============================================================================
# Tests for check_platform() and runMethQC() factory in MethQcSet-io.R
# ============================================================================

# Tests for .resolve_platform() -----------------------------------------------

test_that(".resolve_platform() uses explicit platform value", {
  meta <- data.frame(Sample_Name = "S1", Basename = "/tmp/S1", stringsAsFactors = FALSE)
  result <- imprintomeR:::.resolve_platform(meta, "EPIC")
  expect_equal(result, "EPIC")
})

test_that(".resolve_platform() ignores meta$Platform when platform is explicit", {
  meta <- data.frame(
    Sample_Name = "S1",
    Basename    = "/tmp/S1",
    Platform    = "450K",
    stringsAsFactors = FALSE
  )
  result <- imprintomeR:::.resolve_platform(meta, "EPIC")
  expect_equal(result, "EPIC")
})

test_that(".resolve_platform() auto-resolves when Platform col has one unique value", {
  meta <- data.frame(
    Sample_Name = c("S1", "S2"),
    Basename    = c("/tmp/S1", "/tmp/S2"),
    Platform    = c("EPIC", "EPIC"),
    stringsAsFactors = FALSE
  )
  result <- imprintomeR:::.resolve_platform(meta, NA)
  expect_equal(result, "EPIC")
})

test_that(".resolve_platform() errors when Platform col has multiple values", {
  meta <- data.frame(
    Sample_Name = c("S1", "S2"),
    Basename    = c("/tmp/S1", "/tmp/S2"),
    Platform    = c("EPIC", "450K"),
    stringsAsFactors = FALSE
  )
  expect_error(
    imprintomeR:::.resolve_platform(meta, NA),
    regexp = "Multiple platforms detected"
  )
})

test_that(".resolve_platform() errors with check_platform() hint when no Platform col", {
  meta <- data.frame(
    Sample_Name = "S1",
    Basename    = "/tmp/S1",
    stringsAsFactors = FALSE
  )
  expect_error(
    imprintomeR:::.resolve_platform(meta, NA),
    regexp = "check_platform"
  )
})

test_that(".resolve_platform() errors when all Platform values are NA", {
  meta <- data.frame(
    Sample_Name = "S1",
    Basename    = "/tmp/S1",
    Platform    = NA_character_,
    stringsAsFactors = FALSE
  )
  expect_error(
    imprintomeR:::.resolve_platform(meta, NA),
    regexp = "all values in meta\\$Platform are NA"
  )
})

# Tests for check_platform() --------------------------------------------------

test_that("check_platform() errors when meta has no Basename column", {
  meta <- data.frame(Sample_Name = "S1", stringsAsFactors = FALSE)
  expect_error(check_platform(meta), regexp = "Basename")
})

test_that("check_platform() errors when meta is not a data.frame", {
  expect_error(check_platform("not_a_df"), regexp = "data.frame")
})

test_that("check_platform() returns meta with expected new columns", {
  # Mock .detect_platform_one to avoid hitting real IDAT files
  local_mocked_bindings(
    .detect_platform_one = function(basename, sample_name, max_retries = 5) {
      data.frame(
        Sample_Name  = sample_name,
        Platform     = "EPIC",
        Array_Size   = 865918L,
        Manifest     = "ilm10b4.hg19",
        Status       = "Success",
        stringsAsFactors = FALSE
      )
    },
    .env = getNamespace("imprintomeR")
  )

  meta <- data.frame(
    Sample_Name = c("S1", "S2"),
    Basename    = c("/tmp/S1", "/tmp/S2"),
    stringsAsFactors = FALSE
  )
  result <- check_platform(meta)

  expect_true(all(c("Platform", "Array_Size", "Manifest", "Status") %in% colnames(result)))
  expect_equal(nrow(result), 2)
  expect_equal(result$Platform, c("EPIC", "EPIC"))
})

# Tests for runMethQC() -------------------------------------------------------

test_that("runMethQC() errors when meta has no Basename column", {
  meta <- data.frame(Sample_Name = "S1", Platform = "EPIC", stringsAsFactors = FALSE)
  expect_error(runMethQC(meta, platform = "EPIC"), regexp = "Basename")
})

test_that("runMethQC() errors when IDAT files don't exist", {
  meta <- data.frame(
    Sample_Name = "S1",
    Basename    = "/nonexistent/path/S1",
    Platform    = "EPIC",
    stringsAsFactors = FALSE
  )
  expect_error(runMethQC(meta, platform = "EPIC"), regexp = "IDAT files not found")
})

test_that("runMethQC() errors when meta is not a data.frame", {
  expect_error(runMethQC("not_a_df"), regexp = "data.frame")
})

test_that("CtrlMetrics.QC fails only on bisulfite conversion I", {
  metric <- function(v, threshold) structure(v, threshold = threshold)
  ctrls <- list(
    `Bisulfite Conversion I Green` = metric(c(5, 0.5, 5, 5, NA), 1),
    `Bisulfite Conversion I Red`   = metric(c(5, 5, 0.8, 5, 5), 1),
    `Bisulfite Conversion II`      = metric(c(5, 5, 5, 0.2, 5), 1),
    `Staining Green`               = metric(c(9, 9, 9, 1, 9), 5)
  )
  # Sample 4 fails bisulfite conversion II and staining, which are reported but not used.
  expect_equal(.ctrl_metrics_qc(ctrls), c("PASS", "FAIL", "FAIL", "PASS", "PASS"))
  expect_true(all(ewastools::sample_failure(ctrls)[2:4]))   # ewastools would fail sample 4 too
  expect_error(.ctrl_metrics_qc(ctrls[-1]), "Bisulfite Conversion I Green")
})

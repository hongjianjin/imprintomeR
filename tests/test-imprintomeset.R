testthat::local_edition(1)

# HPC compatibility: some testthat/waldo stacks fail while loading waldo due to
# compare_proxy registration mismatches. Patch testthat's internal comparator to
# a minimal base fallback for this file.
.needs_testthat_waldo_patch <- function() {
  force_patch <- identical(Sys.getenv("IMPRINTOMER_FORCE_WALDO_PATCH", unset = "0"), "1")
  if (force_patch) {
    return(TRUE)
  }

  cmp <- NULL
  ok <- FALSE
  try({
    cmp <- getFromNamespace("waldo_compare", "testthat")
    ok <- TRUE
  }, silent = TRUE)
  if (!ok || is.null(cmp)) {
    return(TRUE)
  }

  needs_patch <- FALSE
  tryCatch(
    {
      cmp(TRUE, TRUE, x_arg = "x", y_arg = "y")
      needs_patch <- FALSE
    },
    error = function(e) {
      msg <- conditionMessage(e)
      needs_patch <<- grepl("compare_proxy", msg, fixed = TRUE)
    }
  )
  needs_patch
}

.patch_testthat_waldo <- function() {
  if (!requireNamespace("testthat", quietly = TRUE)) {
    return(invisible(FALSE))
  }

  if (!.needs_testthat_waldo_patch()) {
    return(invisible(FALSE))
  }

  fallback <- function(x, y, x_arg = "x", y_arg = "y", ...) {
    if (isTRUE(all.equal(x, y, check.attributes = FALSE))) {
      character(0)
    } else {
      c("Objects differ (base all.equal fallback).")
    }
  }

  ok <- FALSE
  try({
    assignInNamespace("waldo_compare", fallback, ns = "testthat")
    ok <- TRUE
  }, silent = TRUE)
  invisible(ok)
}

.patch_testthat_waldo()

# Allow running this file via testthat::test_file() on systems where the
# package is not preloaded (for example, HPC batch jobs).
.find_imprintomer_root <- function() {
  required_rel <- c(
    file.path("R", "module_io.R"),
    file.path("R", "module_probeset.R"),
    file.path("R", "module_scoring.R"),
    file.path("R", "module_utilities.R"),
    file.path("R", "ImprintomeSet-class.R"),
    file.path("R", "ImprintomeSet-accessors.R"),
    file.path("R", "ImprintomeSet-run.R"),
    file.path("R", "ImprintomeSet-summary-export.R")
  )

  has_required <- function(root) {
    if (is.null(root) || !nzchar(root)) return(FALSE)
    all(vapply(required_rel, function(p) file.exists(file.path(root, p)), logical(1)))
  }

  env_root <- Sys.getenv("TESTTHAT_PKG", unset = "")
  if (has_required(env_root)) {
    return(normalizePath(env_root, winslash = "/", mustWork = TRUE))
  }

  cur <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    if (has_required(cur)) {
      return(cur)
    }
    parent <- dirname(cur)
    if (identical(parent, cur)) break
    cur <- parent
  }

  ""
}

.load_local_imprintomer_code <- function() {
  if (exists("ImprintomeSet", mode = "function", inherits = TRUE) &&
      exists("AnalyzeImprintStatus", mode = "function", inherits = TRUE) &&
      exists("runImprintome", mode = "function", inherits = TRUE)) {
    return(invisible(TRUE))
  }

  pkg_root <- .find_imprintomer_root()
  if (!nzchar(pkg_root)) {
    stop("Could not locate package root containing required R/ source files.")
  }

  r_files <- c(
    file.path(pkg_root, "R", "module_io.R"),
    file.path(pkg_root, "R", "module_probeset.R"),
    file.path(pkg_root, "R", "module_scoring.R"),
    file.path(pkg_root, "R", "module_utilities.R"),
    file.path(pkg_root, "R", "ImprintomeSet-class.R"),
    file.path(pkg_root, "R", "ImprintomeSet-accessors.R"),
    file.path(pkg_root, "R", "ImprintomeSet-run.R"),
    file.path(pkg_root, "R", "ImprintomeSet-summary-export.R")
  )

  missing_files <- r_files[!file.exists(r_files)]
  if (length(missing_files) > 0L) {
    stop("Required source files not found: ", paste(missing_files, collapse = ", "))
  }

  source_without_bom <- function(path) {
    lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    if (length(lines) > 0L) {
      lines[1] <- sub("^\ufeff", "", lines[1], useBytes = TRUE)
    }
    src <- textConnection(lines)
    on.exit(close(src), add = TRUE)
    source(src, local = FALSE, encoding = "UTF-8")
  }

  for (f in r_files) {
    source_without_bom(f)
  }
  invisible(TRUE)
}

.load_local_imprintomer_code()

make_synthetic_imprintome_inputs <- function() {
  probes <- c("cg00000001", "cg00000002", "cg00000003", "cg00000004")

  beta <- data.frame(
    NAME = probes,
    S1 = c(0.30, 0.35, 0.70, 0.68),
    S2 = c(0.40, 0.45, 0.62, 0.60),
    S3 = c(0.52, 0.49, 0.51, 0.48),
    stringsAsFactors = FALSE
  )
  rownames(beta) <- beta$NAME

  meta <- data.frame(
    Sample_Name = c("S1", "S2", "S3"),
    Sample_Group = c("case", "case", "control"),
    stringsAsFactors = FALSE
  )

  probeset <- data.frame(
    NAME = probes,
    CHR = c("chr11", "chr11", "chr11", "chr11"),
    MAPINFO = c(10001, 10002, 10003, 10004),
    ORIGIN = c("maternal", "maternal", "paternal", "paternal"),
    stringsAsFactors = FALSE
  )
  rownames(probeset) <- probeset$NAME

  list(beta = beta, meta = meta, probeset = probeset)
}


with_synthetic_probeset_fixture <- function(code) {
  old_wd <- getwd()
  tmp_wd <- file.path(tempdir(), paste0("imprintome_test_", as.integer(Sys.time()), "_", sample.int(100000, 1)))
  dir.create(file.path(tmp_wd, "inst", "extdata"), recursive = TRUE, showWarnings = FALSE)

  d <- make_synthetic_imprintome_inputs()
  saveRDS(list(selected = d$probeset), file.path(tmp_wd, "inst", "extdata", "probesets_hg19.rds"))

  setwd(tmp_wd)
  on.exit(setwd(old_wd), add = TRUE)
  force(code)
}


test_that("ImprintomeSet constructor works and stores slots", {
  with_synthetic_probeset_fixture({
    d <- make_synthetic_imprintome_inputs()

    x <- ImprintomeSet(
      beta = d$beta,
      meta = d$meta,
      probeset = d$probeset,
      genome = "hg19",
      assay = "EPICv1"
    )

    expect_s4_class(x, "ImprintomeSet")
    expect_identical(assay(x), "EPICv1")
    expect_identical(genome(x), "hg19")
    expect_equal(nrow(beta(x)), nrow(d$beta))
    expect_equal(nrow(meta(x)), nrow(d$meta))
    expect_true(is.list(results(x)))
    expect_true(is.list(plots(x)))
  })
})


test_that("ImprintomeSet results accessor works", {
  with_synthetic_probeset_fixture({
    d <- make_synthetic_imprintome_inputs()

    x <- ImprintomeSet(
      beta = d$beta,
      meta = d$meta,
      probeset = d$probeset,
      genome = "hg19",
      assay = "EPICv1"
    )

    results_table <- data.frame(
      Sample_Name = d$meta$Sample_Name,
      analysis_result = rep("pass", nrow(d$meta)),
      stringsAsFactors = FALSE
    )

    results(x) <- list(sample_results = results_table)

    expect_true("sample_results" %in% names(results(x)))
    expect_equal(nrow(results(x)$sample_results), nrow(d$meta))
  })
})


test_that("summarize reports results inventory", {
  with_synthetic_probeset_fixture({
    d <- make_synthetic_imprintome_inputs()

    x <- ImprintomeSet(
      beta = d$beta,
      meta = d$meta,
      probeset = d$probeset,
      genome = "hg19",
      assay = "EPICv1"
    )

    s <- summarize(x)

    expect_true("object" %in% names(s))
    expect_true("results" %in% names(s))
    expect_true("plots" %in% names(s))
    expect_false("qc" %in% names(s))
  })
})


test_that("Meth_QC returns deterministic tabular QC outputs", {
  with_synthetic_probeset_fixture({
    d <- make_synthetic_imprintome_inputs()
    x <- ImprintomeSet(
      beta = d$beta,
      meta = d$meta,
      probeset = d$probeset,
      genome = "hg19",
      assay = "epic"
    )

    detection_p <- data.frame(
      S1 = c(0.001, 0.002, 0.004, 0.030),
      S2 = c(0.001, 0.060, 0.020, 0.020),
      S3 = c(0.200, 0.100, 0.070, 0.060),
      row.names = rownames(d$beta),
      stringsAsFactors = FALSE
    )

    qc_bundle <- Meth_QC(x, detection_p = detection_p)

    expect_true(is.list(qc_bundle))
    expect_true(all(c(
      "metadata_qc",
      "beta_qc",
      "detection_qc",
      "detection_recall_rate",
      "sample_qc"
    ) %in% names(qc_bundle)))
    expect_equal(qc_bundle$metadata_qc$assay, rep("EPICv1", 3))
    expect_equal(qc_bundle$detection_qc$pctDetectedCpG_dP0.05, c(100, 75, 0))
    expect_equal(qc_bundle$sample_qc$final_qc_status, c("PASS", "FAIL", "FAIL"))
  })
})


test_that("ImprintomeSet constructor fails on beta/meta sample mismatch", {
  with_synthetic_probeset_fixture({
    d <- make_synthetic_imprintome_inputs()
    bad_meta <- d$meta
    bad_meta$Sample_Name <- c("X1", "X2", "X3")

    expect_error(
      ImprintomeSet(
        beta = d$beta,
        meta = bad_meta,
        probeset = d$probeset,
        genome = "hg19",
        assay = "EPICv1"
      ),
      "no overlapping samples"
    )
  })
})


test_that("runImprintome updates results slot", {
  with_synthetic_probeset_fixture({
    d <- make_synthetic_imprintome_inputs()
    x <- ImprintomeSet(
      beta = d$beta,
      meta = d$meta,
      probeset = d$probeset,
      genome = "hg19",
      assay = "EPICv1"
    )

    x2 <- runImprintome(x, probeset = "selected", ids_cutoff = 0.2)

    expect_true("AnalyzeImprintStatus.selected" %in% names(results(x2)))
    res <- results(x2)[["AnalyzeImprintStatus.selected"]]
    expect_true(is.data.frame(res))
    expect_true(all(c("IDS", "Angle", "Mechanism", "Status") %in% colnames(res)))
  })
})


test_that("AnalyzeImprintStatus still works with legacy non-object inputs", {
  with_synthetic_probeset_fixture({
    d <- make_synthetic_imprintome_inputs()

    res <- AnalyzeImprintStatus(
      betaFile = d$beta,
      metaFile = d$meta,
      probeset = "selected",
      ids_cutoff = 0.2
    )

    expect_true(is.data.frame(res))
    expect_equal(nrow(res), nrow(d$meta))
    expect_true(all(c("paternal_median", "maternal_median", "IDS", "Angle") %in% colnames(res)))
  })
})


test_that("AnalyzeImprintStatus accepts ImprintomeSet input", {
  with_synthetic_probeset_fixture({
    d <- make_synthetic_imprintome_inputs()
    x <- ImprintomeSet(
      beta = d$beta,
      meta = d$meta,
      probeset = d$probeset,
      genome = "hg19",
      assay = "EPICv1"
    )

    res <- AnalyzeImprintStatus(
      betaFile = x,
      probeset = "selected",
      ids_cutoff = 0.2
    )

    expect_true(is.data.frame(res))
    expect_equal(nrow(res), nrow(d$meta))
    expect_true(all(c("IDS", "Angle", "Mechanism") %in% colnames(res)))
  })
})

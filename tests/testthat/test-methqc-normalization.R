
# Beta normalization in runMethQC() (noob default, noob_swan, raw), its record in
# qc_params and in reference profiles, and EPICv2 handling with minfi.
#
# The integration tests at the end read real IDATs and run only when the folders are
# given by environment variables:
#   IMPRINTOMER_TEST_EPIC_IDATS    folder of EPIC (v1) IDAT pairs
#   IMPRINTOMER_TEST_EPICV2_IDATS  folder of EPICv2 IDAT pairs (needs the EPICv2 manifest
#                                  and annotation packages)

.fixture_beta <- function(probes = paste0("cg", sprintf("%08d", 1:40)), samples = c("S1", "S2", "S3")) {
  set.seed(7)
  m <- matrix(runif(length(probes) * length(samples)), nrow = length(probes), dimnames = list(probes, samples))
  p <- matrix(runif(length(probes) * length(samples), 0, 0.01), nrow = length(probes), dimnames = list(probes, samples))
  list(beta = m, det_pval = p)
}

# Replace internal functions in the package namespace while `code` runs and always put
# the originals back. (testthat's mocked-bindings helpers did not restore namespace
# bindings under pkgload::load_all() with testthat 3.2.1.1, which leaked the mocks into
# the integration tests below.)
.with_namespace_mocks <- function(mocks, code) {
  ns <- getNamespace("imprintomeR")
  originals <- mget(names(mocks), envir = ns)
  set <- function(values) for (n in names(values)) {
    locked <- bindingIsLocked(n, ns)
    if (locked) unlockBinding(n, ns)
    assign(n, values[[n]], envir = ns)
    if (locked) lockBinding(n, ns)
  }
  set(mocks)
  on.exit(set(originals), add = TRUE)
  force(code)
}

.run_mocked_methqc <- function(normalization = NULL) {
  dir <- tempfile("idats_")
  dir.create(dir)
  meta <- data.frame(Sample_Name = c("S1", "S2", "S3"), Basename = file.path(dir, c("S1", "S2", "S3")),
                     stringsAsFactors = FALSE)
  for (b in meta$Basename) file.create(paste0(b, "_Red.idat.gz"))
  seen <- new.env()
  args <- list(meta, platform = "EPIC", save_qc_report = FALSE)
  if (!is.null(normalization)) args$normalization <- normalization
  qcset <- .with_namespace_mocks(
    list(
      .methqc_read_idats = function(meta, ...) "rgSet",
      .methqc_set_array_annotation = function(rgSet, platform) { seen$platform <- platform; rgSet },
      .methqc_preprocess = function(rgSet, normalization) {
        seen$normalization <- normalization
        f <- .fixture_beta()
        list(raw = NULL, beta = f$beta, det_pval = f$det_pval, array_annotation = "IlluminaHumanMethylationEPIC:ilm10b4.hg19")
      }
    ),
    suppressWarnings(suppressMessages(do.call(runMethQC, args)))
  )
  list(qcset = qcset, seen = seen)
}

test_that("runMethQC() normalizes with noob by default and records the method", {
  expect_equal(eval(formals(runMethQC)$normalization)[1], "noob")
  res <- .run_mocked_methqc()
  expect_equal(res$seen$normalization, "noob")
  expect_equal(qc_params(res$qcset)$normalization, "noob")
  expect_equal(qc_params(res$qcset)$array_annotation, "IlluminaHumanMethylationEPIC:ilm10b4.hg19")
  # computeQC() keeps the preprocessing record next to its own parameters.
  expect_equal(qc_params(res$qcset)$pcutoff, 0.05)
  expect_equal(qc_params(res$qcset)$method, "detection_pval_statistics")
})

test_that("runMethQC() passes the requested normalization through", {
  for (m in c("noob_swan", "raw")) {
    res <- .run_mocked_methqc(m)
    expect_equal(res$seen$normalization, m)
    expect_equal(qc_params(res$qcset)$normalization, m)
  }
  expect_equal(.run_mocked_methqc()$seen$platform, "EPIC")
})

test_that("runMethQC() rejects unknown normalization methods", {
  meta <- data.frame(Sample_Name = "S1", Basename = tempfile(), stringsAsFactors = FALSE)
  expect_error(runMethQC(meta, platform = "EPIC", normalization = "bmiq"), "should be one of")
})

test_that("runMethQC() accepts gzipped IDATs", {
  # The mocked run uses only *_Red.idat.gz files.
  expect_true(methods::is(.run_mocked_methqc()$qcset, "MethQcSet"))
})

test_that("SWAN's fixed seed leaves the caller's random number stream unchanged", {
  set.seed(42)
  expected <- runif(3)
  set.seed(42)
  invisible(imprintomeR:::.with_fixed_seed(1L, runif(10)))
  expect_equal(runif(3), expected)
})

test_that("computeQC() keeps qc_params entries and merge() warns on mixed normalization", {
  f <- .fixture_beta()
  meta <- data.frame(Sample_Name = colnames(f$beta), stringsAsFactors = FALSE)
  x <- MethQcSet(meta = meta, platform = "EPIC", beta = f$beta, detection_pval = f$det_pval,
                 qc_params = list(normalization = "noob"))
  x <- imprintomeR:::computeQC(x, pcutoff = 0.05)
  expect_equal(qc_params(x)$normalization, "noob")

  g <- .fixture_beta(samples = c("S4", "S5", "S6"))
  y <- MethQcSet(meta = data.frame(Sample_Name = colnames(g$beta), stringsAsFactors = FALSE), platform = "EPIC",
                 beta = g$beta, detection_pval = g$det_pval, qc_params = list(normalization = "raw"))
  expect_warning(merge(x, y), "different beta normalization")
  qc_params(y) <- list(normalization = "noob")
  expect_warning(merge(x, y), NA)
})

test_that("BuildReferenceProfile() records normalization and scoring reports it", {
  probes <- c(sprintf("cgM%02d", 1:6), sprintf("cgP%02d", 1:6))
  f <- .fixture_beta(probes = probes, samples = paste0("C", 1:5))
  panel <- data.frame(NAME = probes, CHR = "chr11", MAPINFO = seq_along(probes),
                      ORIGIN = rep(c("maternal", "paternal"), each = 6), stringsAsFactors = FALSE)
  tmp <- tempfile("profile_")
  dir.create(file.path(tmp, "inst", "extdata"), recursive = TRUE)
  old <- setwd(tmp); on.exit(setwd(old), add = TRUE)
  for (g in c("hg19", "hg38")) saveRDS(list(selected = panel), file.path("inst", "extdata", paste0("probesets_", g, ".rds")))

  qcset <- MethQcSet(meta = data.frame(Sample_Name = colnames(f$beta), stringsAsFactors = FALSE), platform = "EPIC",
                     beta = f$beta, detection_pval = f$det_pval, qc_params = list(normalization = "noob_swan"))
  profile <- NULL
  invisible(capture.output(profile <- BuildReferenceProfile(qcset)))
  expect_equal(attr(profile, "normalization"), "noob_swan")
  expect_equal(attr(profile, "n_samples"), 5)
  invisible(capture.output(plain <- BuildReferenceProfile(f$beta)))
  expect_equal(attr(plain, "normalization"), "unspecified")
  invisible(capture.output(given <- BuildReferenceProfile(f$beta, normalization = "noob")))
  expect_equal(attr(given, "normalization"), "noob")

  cases <- data.frame(TargetID = probes, X1 = runif(12), X2 = runif(12), check.names = FALSE)
  meta <- data.frame(Sample_Name = c("X1", "X2"), Sample_Group = "case", stringsAsFactors = FALSE)
  res <- NULL
  invisible(capture.output(res <- suppressWarnings(AnalyzeImprintStatus(cases, meta, probeset = "selected", reference_beta = profile))))
  expect_equal(unique(res$reference), "external controls, n=5, noob_swan")
  invisible(capture.output(res2 <- suppressWarnings(AnalyzeImprintStatus(cases, meta, probeset = "selected", reference_beta = plain))))
  expect_equal(unique(res2$reference), "external controls, n=5")

  v2 <- MethQcSet(meta = data.frame(Sample_Name = colnames(f$beta), stringsAsFactors = FALSE), platform = "EPICv2",
                  beta = f$beta, aggregation_status = "none")
  expect_error(BuildReferenceProfile(v2), "must be aggregated")
})

# --- Integration tests on real IDATs (optional) ------------------------------

.idat_meta <- function(dir, n = 2) {
  base <- sub("_Grn[.]idat([.]gz)?$", "", list.files(dir, "_Grn[.]idat([.]gz)?$", full.names = TRUE))[seq_len(n)]
  data.frame(Sample_Name = basename(base), Basename = base, stringsAsFactors = FALSE)
}

test_that("noob, noob_swan and raw run on EPIC IDATs", {
  dir <- Sys.getenv("IMPRINTOMER_TEST_EPIC_IDATS", unset = "")
  skip_if(!nzchar(dir) || !dir.exists(dir), "IMPRINTOMER_TEST_EPIC_IDATS not set")
  meta <- .idat_meta(dir)
  run <- function(m) suppressWarnings(suppressMessages(runMethQC(meta, platform = "EPIC", normalization = m, save_qc_report = FALSE)))
  out <- lapply(c(raw = "raw", noob = "noob", noob_swan = "noob_swan"), run)
  for (m in names(out)) {
    x <- out[[m]]
    expect_equal(qc_params(x)$normalization, m)
    expect_identical(rownames(beta(x)), rownames(detection_pval(x)))
    expect_true(all(beta(x) >= 0 & beta(x) <= 1, na.rm = TRUE))
  }
  expect_identical(rownames(beta(out$raw)), rownames(beta(out$noob)))
  expect_false(isTRUE(all.equal(beta(out$raw), beta(out$noob))))
  expect_identical(detection_pval(out$raw), detection_pval(out$noob))
  expect_identical(beta(out$noob_swan), beta(run("noob_swan")))  # reproducible despite SWAN's random subsets
})

test_that("runMethQC() sets the EPICv2 minfi annotation and its output aggregates", {
  dir <- Sys.getenv("IMPRINTOMER_TEST_EPICV2_IDATS", unset = "")
  skip_if(!nzchar(dir) || !dir.exists(dir), "IMPRINTOMER_TEST_EPICV2_IDATS not set")
  skip_if_not(all(vapply(imprintomeR:::.epicv2_minfi_packages, requireNamespace, logical(1), quietly = TRUE)),
              "EPICv2 manifest/annotation packages not installed")
  meta <- .idat_meta(dir)
  x <- suppressWarnings(suppressMessages(runMethQC(meta, platform = "EPICv2", normalization = "noob", save_qc_report = FALSE)))
  expect_equal(qc_params(x)$array_annotation, "IlluminaHumanMethylationEPICv2:20a1.hg38")
  expect_gt(nrow(beta(x)), 900000)
  expect_true(all(grepl("_", rownames(beta(x)))))
  agg <- suppressMessages(aggregate_probes(x))
  expect_equal(aggregation_status(agg), "epicv2_aggregated")
  expect_equal(qc_params(agg)$normalization, "noob")
  expect_false(any(grepl("_", rownames(beta(agg)))))
})

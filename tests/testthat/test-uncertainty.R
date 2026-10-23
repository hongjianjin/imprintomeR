testthat::local_edition(1)

# Bootstrap confidence intervals and permutation null for IDS/Angle in AnalyzeImprintStatus(),
# and CalibrateIDS().

.with_uncertainty_panel <- function(probeset_df, code) {
  old_wd <- getwd()
  tmp_wd <- tempfile("imprintome_unc_")
  dir.create(file.path(tmp_wd, "inst", "extdata"), recursive = TRUE)
  for (g in c("hg19", "hg38")) {
    saveRDS(list(selected = probeset_df), file.path(tmp_wd, "inst", "extdata", paste0("probesets_", g, ".rds")))
  }
  setwd(tmp_wd)
  on.exit(setwd(old_wd), add = TRUE)
  force(code)
}

# Four maternal and three paternal ICRs of four probes each, plus two paternal probes outside
# ICRs. Six controls scatter around 0.5; PAT gains paternal methylation (+0.3), GLOBAL gains
# methylation on every probe (+0.25), NORM is balanced.
.make_uncertainty_fixture <- function() {
  icr <- c(rep(paste0("MAT", 1:4), each = 4), rep(paste0("PAT", 1:3), each = 4), NA, NA)
  origin <- c(rep("maternal", 16), rep("paternal", 14))
  probes <- sprintf("cg%04d", seq_along(icr))
  n <- length(probes)
  set.seed(11)
  noise <- function() stats::rnorm(n, 0, 0.02)
  beta <- sapply(1:6, function(i) 0.5 + noise())
  colnames(beta) <- paste0("C", 1:6)
  beta <- cbind(beta,
                PAT = 0.5 + noise() + ifelse(origin == "paternal", 0.3, 0),
                GLOBAL = 0.5 + noise() + 0.25,
                NORM = 0.5 + noise())
  rownames(beta) <- probes
  meta <- data.frame(Sample_Name = colnames(beta),
                     Sample_Group = c(rep("control", 6), "case", "case", "case"),
                     stringsAsFactors = FALSE)
  probeset <- data.frame(NAME = probes, CHR = "chr11", MAPINFO = seq_len(n), ORIGIN = origin,
                         ICR_name = icr, INFINIUM_DESIGN_TYPE = rep(c("I", "II"), length.out = n),
                         stringsAsFactors = FALSE)
  list(beta = data.frame(TargetID = probes, beta, check.names = FALSE), meta = meta, probeset = probeset)
}

.score_unc <- function(d, ...) {
  out <- NULL
  invisible(utils::capture.output(out <- AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", ...)))
  rownames(out) <- out$Sample_Name
  out
}

test_that("uncertainty is off by default and leaves the result unchanged", {
  d <- .make_uncertainty_fixture()
  .with_uncertainty_panel(d$probeset, {
    base <- .score_unc(d)
    expect_false(any(c("IDS_lower", "origin_perm_p") %in% colnames(base)))
    both <- .score_unc(d, n_boot = 50, n_perm = 50, seed = 1)
    expect_identical(both[, colnames(base)], base)
  })
})

test_that("a seed makes intervals reproducible and restores the random stream", {
  d <- .make_uncertainty_fixture()
  .with_uncertainty_panel(d$probeset, {
    set.seed(99)
    before <- .Random.seed
    a <- .score_unc(d, n_boot = 100, n_perm = 100, seed = 7)
    expect_identical(.Random.seed, before)
    b <- .score_unc(d, n_boot = 100, n_perm = 100, seed = 7)
    expect_identical(a, b)
  })
})

test_that("bootstrap intervals bracket IDS and support a clear mechanism", {
  d <- .make_uncertainty_fixture()
  .with_uncertainty_panel(d$probeset, {
    res <- .score_unc(d, n_boot = 300, seed = 3)
    expect_true(all(res$IDS_lower <= res$IDS + 1e-3 & res$IDS <= res$IDS_upper + 1e-3))
    expect_equal(unique(res$resample), "icr")
    expect_equal(unique(res$n_boot), 300L)
    expect_equal(res["PAT", "Mechanism"], "Pat-Gain")
    expect_gt(res["PAT", "Mechanism_support"], 0.95)
    expect_gt(res["PAT", "IDS_lower"], 0.2)
    expect_lt(res["NORM", "IDS_upper"], 0.2)
    # The Angle interval runs clockwise from lower to upper through the observed angle.
    width <- (res["PAT", "Angle_upper"] - res["PAT", "Angle_lower"]) %% 360
    expect_lt(width, 30)
    expect_lte((res["PAT", "Angle"] - res["PAT", "Angle_lower"]) %% 360, width + 0.1)
  })
})

test_that("ICR resampling gives wider intervals than probe resampling and handles single-ICR classes", {
  d <- .make_uncertainty_fixture()
  .with_uncertainty_panel(d$probeset, {
    icr <- .score_unc(d, n_boot = 400, seed = 5)
    probe <- .score_unc(d, n_boot = 400, seed = 5, resample = "probe")
    expect_equal(unique(probe$resample), "probe")
    expect_gt(median(icr$IDS_upper - icr$IDS_lower), median(probe$IDS_upper - probe$IDS_lower))
  })
  # One ICR per class (as chr11p15): the two-stage bootstrap still varies the probes.
  d$probeset$ICR_name <- ifelse(d$probeset$ORIGIN == "paternal", "IC1", "IC2")
  .with_uncertainty_panel(d$probeset, {
    res <- .score_unc(d, n_boot = 200, seed = 5)
    expect_true(all(res$IDS_upper > res$IDS_lower))
  })
})

test_that("without ICR annotation the bootstrap resamples probes", {
  d <- .make_uncertainty_fixture()
  d$probeset$ICR_name <- NULL
  .with_uncertainty_panel(d$probeset, {
    res <- NULL
    expect_message(invisible(utils::capture.output(
      res <- AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", n_boot = 50, seed = 1))),
      "no ICR_name column")
    expect_equal(unique(res$resample), "probe")
    expect_error(.score_unc(d, n_perm = 20, permute = "icr"), "at least two annotated ICRs")
  })
})

test_that("the permutation null separates origin-specific from global shifts", {
  d <- .make_uncertainty_fixture()
  .with_uncertainty_panel(d$probeset, {
    res <- .score_unc(d, n_perm = 199, seed = 2)
    expect_equal(unique(res$permute), "probe")
    expect_equal(res["PAT", "origin_perm_p"], 1 / 200)
    expect_equal(res["GLOBAL", "Mechanism"], "Global-Hyper")
    expect_gt(res["GLOBAL", "origin_perm_p"], 0.2)
    icr <- .score_unc(d, n_perm = 199, seed = 2, permute = "icr")
    expect_equal(unique(icr$permute), "icr")
    expect_lt(icr["PAT", "origin_perm_p"], 0.1)
    expect_gt(icr["GLOBAL", "origin_perm_p"], 0.2)
  })
})

test_that("uncertainty works with control centring, Infinium balancing and ICR balancing", {
  d <- .make_uncertainty_fixture()
  .with_uncertainty_panel(d$probeset, {
    ctrl <- suppressWarnings(.score_unc(d, reference_group = "control", n_boot = 100, n_perm = 50, seed = 4))
    expect_true(all(c("IDS_lower", "origin_perm_p") %in% colnames(ctrl)))
    bal <- .score_unc(d, infinium_type = "balanced", n_boot = 100, n_perm = 50, seed = 4)
    expect_true(all(bal$IDS_lower <= bal$IDS + 1e-3))
    icr <- .score_unc(d, balance = "icr", n_boot = 100, n_perm = 50, seed = 4)
    expect_equal(unique(icr$permute), "icr")
    expect_true(all(icr$IDS_lower <= icr$IDS + 1e-3 & icr$IDS <= icr$IDS_upper + 1e-3))
  })
})

test_that("invalid uncertainty arguments are rejected", {
  d <- .make_uncertainty_fixture()
  .with_uncertainty_panel(d$probeset, {
    expect_error(.score_unc(d, n_boot = -1), "n_boot")
    expect_error(.score_unc(d, n_perm = 2.5), "n_perm")
    expect_error(.score_unc(d, n_boot = 10, conf_level = 1), "conf_level")
  })
})

test_that("runImprintome passes uncertainty options through", {
  d <- .make_uncertainty_fixture()
  .with_uncertainty_panel(d$probeset, {
    beta <- as.matrix(d$beta[, -1])
    rownames(beta) <- d$beta$TargetID
    x <- ImprintomeSet(beta = beta, meta = d$meta, probeset = d$probeset, genome = "hg38", assay = "EPICv1")
    x <- runImprintome(x, probeset = "selected", n_boot = 50, n_perm = 50, seed = 1)
    res <- results(x)[["AnalyzeImprintStatus.selected"]]
    expect_true(all(c("IDS_lower", "IDS_upper", "origin_perm_p") %in% colnames(res)))
  })
})

test_that("CalibrateIDS derives cutoffs and control-relative scores", {
  res <- data.frame(Sample_Name = paste0("S", 1:10),
                    Sample_Group = rep(c("control", "case"), each = 5),
                    IDS = c(0.02, 0.04, 0.05, 0.07, 0.10, 0.08, 0.15, 0.30, 0.45, 0.26),
                    stringsAsFactors = FALSE)
  q <- CalibrateIDS(res, controls = "control")
  expect_equal(attr(q, "calibration")$cutoff, round(stats::quantile(res$IDS[1:5], 0.99, names = FALSE), 3))
  m <- CalibrateIDS(res, controls = "control", method = "max", cases = "case")
  cal <- attr(m, "calibration")
  expect_equal(cal$cutoff, 0.10)
  expect_equal(m$Status_calibrated, ifelse(res$IDS > 0.10, "Imprinting Alteration", "Normal"))
  expect_equal(cal$AUC, 0.96)
  expect_equal(m$IDS_z, round((res$IDS - 0.05) / max(stats::mad(res$IDS[1:5]), 0.01), 2))
  expect_equal(m$IDS_control_percentile[c(1, 5, 10)], c(20, 100, 100))
  # Midpoint cutoffs 0.075 and 0.125 tie (Youden index 0.8); the middle of the tied run is chosen.
  y <- CalibrateIDS(res, controls = res$Sample_Group == "control", method = "youden", cases = "case")
  expect_equal(attr(y, "calibration")$cutoff, 0.125)
  expect_equal(attr(y, "calibration")$sensitivity, 0.8)
  expect_equal(attr(y, "calibration")$specificity, 1)
  expect_error(CalibrateIDS(res, controls = "control", method = "youden"), "requires cases")
  expect_error(CalibrateIDS(res, controls = "none"), "No controls")
  expect_warning(CalibrateIDS(res[c(1:3, 6:10), ], controls = "control"), "at least 5")
})
